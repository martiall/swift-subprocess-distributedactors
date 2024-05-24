import Distributed
#if !os(WASI)
import Synchronization
#endif
import Logging
import Foundation

public enum PluginActorSystemError: Error {
    case unknownActor(PluginActorID)
    case invalidActorType(PluginActorID, expected: Any.Type, found: Any.Type)
    case urlNotFound
    case fileIsNotExecutable
}

public final class PluginActorSystem: DistributedActorSystem {
    internal let localNodeId: NodeID
    
    #if !os(WASI)
    internal let nextLocalId: Atomic<Int> = .init(0)
    #else
    internal var nextLocalId: Int = 0
    #endif
    //TODO: To replace with Mutex when available
    struct WeakDistributedActor: Sendable {
        private(set) weak var inner: (any DistributedActor)?
        init(inner: any DistributedActor) { self.inner = inner }
    }
    class WeakDistributedActors: @unchecked Sendable {
        internal let lock: Lock = .init()
        internal var localActors: [ActorID: WeakDistributedActor] = .init()
        
        public borrowing func withLock<Result>(_ body: (inout [ActorID: WeakDistributedActor]) throws -> Result) rethrows -> Result {
            try lock.withLock {
                try body(&localActors)
            }
        }
    }
    private let localActors: WeakDistributedActors = .init()
    //internal let localActors: Mutex<[ActorID: WeakDistributedActor]> = .init([:])
    
    internal let logger: Logger

    internal let transport: any Transport
    private let awaitingCalls = InflightCalls()

    private let incomingCallsContinuation: AsyncStream<Enveloppe>.Continuation

    public init<T: Transport>(
        transport: T
    ) async throws {
        let stream = AsyncStream<Enveloppe>.makeStream()
        let incomingCallStream = stream.stream
        self.incomingCallsContinuation = stream.continuation
        
        self.transport = transport
        self.localNodeId = try await self.transport.start(continuation: stream.continuation)
        self.logger = Logger(label: "PluginActorSystem[nodeId:\(self.localNodeId)]")
        
        Task.detached { [incomingCallStream, weak self] in
            for await enveloppe in incomingCallStream {
                guard let self else { break }
                self.handle(enveloppe: enveloppe)
            }
        }
    }
}

extension PluginActorSystem {
    public typealias SerializationRequirement = any Codable
    public typealias ActorID = PluginActorID
    public typealias InvocationEncoder = PluginActorInvocationEncoder
    public typealias InvocationDecoder = PluginActorInvocationDecoder
    public typealias ResultHandler = PluginResultHandler
    
    public func resolve<Act: DistributedActor>(id: ActorID, as actorType: Act.Type) throws -> Act? where ActorID == Act.ID {
        if id.isOn(nodeId: self.localNodeId) {
            try self.localActors.withLock {
                guard let act = $0[id]?.inner else {
                    throw PluginActorSystemError.unknownActor(id)
                }
                guard let castedActor = act as? Act else {
                    throw PluginActorSystemError.invalidActorType(id, expected: Act.self, found: type(of: act))
                }
                return castedActor
            }
        } else {
            nil
        }
    }
    
    public func assignID<Act: DistributedActor>(_ actorType: Act.Type) -> ActorID where ActorID == Act.ID {
        #if !os(WASI)
        let nextID = self.nextLocalId.add(1, ordering: .acquiringAndReleasing).oldValue
        #else
        let nextID = self.nextLocalId
        self.nextLocalId += 1
        #endif
        let next = ActorID(
            nodeId: self.localNodeId,
            localId: nextID
        )
        self.logger.trace("Assigning \(next) actorId")
        return next
    }
    
    public func actorReady<Act: DistributedActor>(_ actor: Act) where ActorID == Act.ID {
        precondition(actor.id.isOn(nodeId: self.localNodeId))
        self.localActors.withLock {
            $0[actor.id] = WeakDistributedActor(inner: actor)
        }
        self.logger.trace("Actor \(actor.id) is ready.")
    }
    
    public func resignID(_ id: ActorID) {
        self.localActors.withLock {
            $0[id] = nil
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

public protocol Transport: Sendable {
    func start(continuation: AsyncStream<Enveloppe>.Continuation) async throws -> NodeID
    func send(enveloppe: Enveloppe) async throws -> Void
}

extension PluginActorSystem {
    internal func handle(enveloppe: Enveloppe) {
        do {
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
                    try await self.transport.send(enveloppe: enveloppe)
                }
            }
        } catch {
            // Do something with error
            fatalError()
        }
    }
    
    internal func handleIncomingCall(enveloppe: Enveloppe, call: Message.Call) throws {
        Task {
            do {
                guard let localActor = self.localActors.withLock({ $0[call.callee]?.inner }) else {
                    throw PluginActorSystemError.unknownActor(call.callee)
                }
                var invocationDecoder = PluginActorInvocationDecoder(
                    actorSystem: self,
                    call: call
                )
                try await self.executeDistributedTarget(
                    on: localActor,
                    target: RemoteCallTarget(call.target),
                    invocationDecoder: &invocationDecoder,
                    handler: PluginResultHandler(
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
        try await transport.send(enveloppe: enveloppe)
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
            generics: invocation.generics,
            returnType: invocation.returnType,
            errorType: invocation.errorType
        ))
        
        return try await awaitingCalls.call { callId in
            let enveloppe = Enveloppe(
                from: self.localNodeId,
                to: id.nodeId,
                callId: callId,
                message: message
            )
            try await self.transport.send(enveloppe: enveloppe)
        }
    }
}
