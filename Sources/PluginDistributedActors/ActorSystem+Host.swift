import Foundation

extension PluginActorSystem {
    public static let HostNodeID: NodeID = "<RootNodeId>"

    public static func makeHost() async throws -> Self {
        try await Self(
            transport: HostTransport(nodeID: Self.HostNodeID)
        )
    }
    
    public func spawnGuest(_ builder: @Sendable () throws -> any Transport) async throws -> NodeID {
        guard let host = self.transport as? HostTransport
            else { fatalError() }
        
        return try await host.spawnGuest(builder)
    }
}

public actor HostTransport: Transport {
    private var incomingCallStream: AsyncStream<Enveloppe>.Continuation?

    private var guests: [NodeID: any Transport] = [:]
    private let nodeID: NodeID

    init(nodeID: NodeID) {
        self.nodeID = nodeID
    }
    
    public func start(continuation: AsyncStream<Enveloppe>.Continuation) throws -> NodeID {
        self.incomingCallStream = continuation
        return self.nodeID
    }
    
    func spawnGuest(_ builder: @Sendable () throws -> any Transport) async throws -> NodeID {
        guard let incomingCallStream = self.incomingCallStream else { fatalError() }
        let guest = try builder()
        let nodeID = try await guest.start(continuation: incomingCallStream)
        self.guests[nodeID] = guest
        return nodeID
    }
    
    public func send(enveloppe: Enveloppe) async throws {
        guard let guestProcess = self.guests[enveloppe.to]
            else { fatalError() }
        
        try await guestProcess.send(enveloppe: enveloppe)
    }
    
    private func removeNode(id: NodeID) {
        self.guests[id] = nil
    }
    
    nonisolated func terminate(nodeID: NodeID) {
        Task.detached {
            await self.removeNode(id: nodeID)
        }
    }
}
