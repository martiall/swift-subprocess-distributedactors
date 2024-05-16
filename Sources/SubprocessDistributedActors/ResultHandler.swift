import Distributed

public struct SubprocessResultHandler: DistributedTargetInvocationResultHandler {
    public typealias SerializationRequirement = any Codable
    
    let system: SubprocessActorSystem
    let caller: NodeID
    let id: CallID
    
    init(system: SubprocessActorSystem, caller: NodeID, as id: CallID) {
        self.system = system
        self.caller = caller
        self.id = id
    }
    
    public func onReturn<Success: Codable>(value: Success) async throws {
        try await system.sendReplyResult(value, to: caller, for: id)
    }
    
    public func onReturnVoid() async throws {
        try await system.sendReplyVoid(to: caller, for: id)
    }
    
    public func onThrow<Err>(error: Err) async throws where Err : Error {
        if Err.self is any Codable {
            try await system.sendReplyError(error, to: caller, for: id)
        }
    }
}
