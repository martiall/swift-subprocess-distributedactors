import Foundation

extension Process {
    var nodeID: NodeID {
        "Subprocess(\(self.processIdentifier))"
    }
}

extension ProcessInfo {
    var nodeID: NodeID {
        "Subprocess(\(self.processIdentifier))"
    }
}