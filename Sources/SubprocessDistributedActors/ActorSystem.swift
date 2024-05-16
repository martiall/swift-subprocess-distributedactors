import Distributed
import Atomics
import Logging
import Foundation

public enum SubprocessActorSystemError: Error {
    case unknownActor(SubprocessActorID)
    case invalidActorType(SubprocessActorID, expected: Any.Type, found: Any.Type)
    case urlNotFound
    case fileIsNotExecutable
}

internal typealias CallID = Int

fileprivate actor AwaitingCalls {
    private enum AwaitingCallsError: Error {
       case unknownCall(CallID)
    }
    
    private typealias CallContinuation = CheckedContinuation<[UInt8], any Error>
    private var callContinuations: [CallID: CallContinuation] = [:]
    
    private var nextCallId = 0
    
    private func awaitForReply(continuation: CallContinuation) -> CallID {
        let callId = nextCallId
        nextCallId += 1
        callContinuations[callId] = continuation
        return callId
    }
    
    func onReceivedReply(callId: CallID, data: [UInt8]) throws {
        guard let continuation = callContinuations.removeValue(forKey: callId) else {
            throw AwaitingCallsError.unknownCall(callId)
        }
        continuation.resume(returning: data)
    }
    
    func onReceivedError(callId: CallID, error: any Error) throws {
        guard let continuation = callContinuations.removeValue(forKey: callId) else {
            throw AwaitingCallsError.unknownCall(callId)
        }
        continuation.resume(throwing: error)
    }
    
    func call(_ body: @escaping @Sendable (CallID) async throws -> Void) async throws -> [UInt8] {
        try await withCheckedThrowingContinuation { continuation in
            Task {
                let callId = self.awaitForReply(continuation: continuation)
                do {
                    try await body(callId)
                } catch {
                    try self.onReceivedError(callId: callId, error: error)
                }
            }
        }
    }
}

public final class SubprocessActorSystem {
    internal let localNodeId: NodeID
    
    internal let nextLocalId: ManagedAtomic<Int> = .init(0)

    struct WeakDistributedActor: Sendable {
        private(set) weak var inner: (any DistributedActor)?
        
        init(inner: any DistributedActor) {
            self.inner = inner
        }
    }

    //TODO: To replace with Mutex when available
    internal let lock: Lock = .init()
    internal var localActors: [ActorID: WeakDistributedActor] = .init()
    
    internal let logger: Logger
    
    internal let transport: any Transport
    private let awaitingCalls = AwaitingCalls()
    
    internal init(nodeId: NodeID, transport: any Transport) async throws {
        self.localNodeId = nodeId
        self.logger = Logger(label: "SubprocessActorSystem[nodeId:\(self.localNodeId)]")
        
        self.transport = transport
        try await self.transport.start(actorSystem: self)
    }
}

extension SubprocessActorSystem: DistributedActorSystem {
    public typealias SerializationRequirement = any Codable
    public typealias ActorID = SubprocessActorID
    public typealias InvocationEncoder = SubprocessActorInvocationEncoder
    public typealias InvocationDecoder = SubprocessActorInvocationDecoder
    public typealias ResultHandler = SubprocessResultHandler
    
    public func resolve<Act: DistributedActor>(id: ActorID, as actorType: Act.Type) throws -> Act? where ActorID == Act.ID {
        if id.isOn(nodeId: self.localNodeId) {
            try self.lock.withLock {
                guard let act = self.localActors[id]?.inner else {
                    throw SubprocessActorSystemError.unknownActor(id)
                }
                guard let castedActor = act as? Act else {
                    throw SubprocessActorSystemError.invalidActorType(id, expected: Act.self, found: type(of: act))
                }
                return castedActor
            }
        } else {
            nil
        }
    }
    
    public func assignID<Act: DistributedActor>(_ actorType: Act.Type) -> ActorID where ActorID == Act.ID {
        let next = ActorID(
            nodeId: self.localNodeId,
            localId: self.nextLocalId.loadThenWrappingIncrement(by: 1, ordering: .acquiringAndReleasing)
        )
        self.logger.trace("Assigning \(next) actorId")
        return next
    }
    
    public func actorReady<Act: DistributedActor>(_ actor: Act) where ActorID == Act.ID {
        precondition(actor.id.isOn(nodeId: self.localNodeId))
        self.lock.withLockVoid {
            self.localActors[actor.id] = WeakDistributedActor(inner: actor)
        }
        self.logger.trace("Actor \(actor.id) is ready.")
    }
    
    public func resignID(_ id: ActorID) {
        self.lock.withLockVoid {
            self.localActors[id] = nil
        }
        self.logger.trace("ActorId \(id) has resigned.")
    }

    public func makeInvocationEncoder() -> InvocationEncoder {
        InvocationEncoder()
    }
    
    public func remoteCall<Act: DistributedActor, Err: Error, Res: Codable>(
        on actor: Act,
        target: RemoteCallTarget,
        invocation: inout InvocationEncoder,
        throwing _: Err.Type,
        returning _: Res.Type
    ) async throws -> Res where Act.ID == ActorID {
        let data = try await makeCall(id: actor.id, target: target, invocation: &invocation)
        return try JSONDecoder().decode(Res.self, from: Data(data))
    }
    
    public func remoteCallVoid<Act: DistributedActor, Err: Error>(
        on actor: Act,
        target: RemoteCallTarget,
        invocation: inout InvocationEncoder,
        throwing error: Err.Type
    ) async throws where Act.ID == ActorID {
        _ = try await makeCall(id: actor.id, target: target, invocation: &invocation)
    }
}

internal protocol Transport {
    func start(actorSystem: SubprocessActorSystem) async throws
    func send(to: NodeID, enveloppe: Enveloppe) async throws -> Void
}

extension SubprocessActorSystem {
    internal func handle(enveloppe: Enveloppe) throws {
        if enveloppe.to == self.localNodeId {
            switch enveloppe.message {
            case .call(let call):
                try handleIncomingCall(enveloppe: enveloppe, call: call)
            case .reply(let reply):
                Task {
                    switch reply {
                    case .success(let data):
                        try await self.awaitingCalls.onReceivedReply(callId: enveloppe.callId, data: data)
                    case .failure(let error):
                        try await self.awaitingCalls.onReceivedError(callId: enveloppe.callId, error: error)
                    }
                }
            }
        } else {
            Task {
                try await self.transport.send(to: enveloppe.to, enveloppe: enveloppe)
            }
        }
    }
    
    internal func handleIncomingCall(enveloppe: Enveloppe, call: Message.Call) throws {
        Task {
            do {
                guard let localActor = localActors[call.callee]?.inner else {
                    throw SubprocessActorSystemError.unknownActor(call.callee)
                }
                var invocationDecoder = SubprocessActorInvocationDecoder(
                    argumentsIterator: call.arguments.makeIterator(),
                    generics: call.generics
                )
                try await self.executeDistributedTarget(
                    on: localActor,
                    target: RemoteCallTarget(call.target),
                    invocationDecoder: &invocationDecoder,
                    handler: SubprocessResultHandler(
                        system: self,
                        caller: enveloppe.from,
                        as: enveloppe.callId
                    )
                )
            } catch {
                try await self.sendReplyError(error, to: enveloppe.from, for: enveloppe.callId)
            }
        }
    }
    
    internal func sendReplyVoid(to nodeId: NodeID, for callId: CallID) async throws {
        try await self.sendReply(.reply(.success([])), to: nodeId, for: callId)
    }
    
    func sendReplyResult<Result: Codable>(_ result: Result, to nodeId: NodeID, for callId: CallID) async throws {
        try await self.sendReply(
            .reply(
                .success(
                    Array(try JSONEncoder().encode(result))
                )
            ),
            to: nodeId,
            for: callId
        )
    }
    
    func sendReplyError<E: Error>(_ error: E, to nodeId: NodeID, for id: CallID) async throws {
        try await self.sendReply(.reply(.failure(.unknown)), to: nodeId, for: id)
    }
    
    private func sendReply(_ message: Message, to nodeId: NodeID, for id: CallID) async throws {
        let enveloppe = Enveloppe(
            from: self.localNodeId,
            to: nodeId,
            callId: id,
            message: message
        )
        try await transport.send(to: nodeId, enveloppe: enveloppe)
    }
    
    private func makeCall(
        id: ActorID,
        target: RemoteCallTarget,
        invocation: inout InvocationEncoder
    ) async throws -> [UInt8] {
        precondition(id.isOn(nodeId: self.localNodeId) == false)
        
        let message = Message.call(.init(
            callee: id,
            target: target.identifier,
            arguments: invocation.arguments,
            generics: invocation.generics
        ))
        
        return try await awaitingCalls.call { callId in
            let enveloppe = Enveloppe(
                from: self.localNodeId,
                to: id.nodeId,
                callId: callId,
                message: message
            )
            try await self.transport.send(to: id.nodeId, enveloppe: enveloppe)
        }
    }
}
