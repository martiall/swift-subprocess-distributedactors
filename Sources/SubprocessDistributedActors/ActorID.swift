import Distributed
import Foundation

public typealias NodeID = Int32

public struct SubprocessActorID: Hashable, Codable, Sendable {
    internal let nodeId: NodeID
    private let localId: Int
    
    public init(nodeId: NodeID, localId: Int) {
        self.nodeId = nodeId
        self.localId = localId
    }
    
    internal func isOn(nodeId: NodeID) -> Bool {
        self.nodeId == nodeId
    }
}
