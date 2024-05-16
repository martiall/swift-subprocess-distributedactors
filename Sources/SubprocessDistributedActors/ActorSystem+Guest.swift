import Foundation
import Distributed

extension SubprocessActorSystem {
    public static func makeGuest() async throws -> Self {
        return try await Self(
            nodeId: ProcessInfo.processInfo.processIdentifier,
            transport: GuestTransport()
        )
    }
}

fileprivate actor GuestTransport: Transport {
    func start(actorSystem: SubprocessActorSystem) async throws {
        Task.detached { [weak actorSystem] in
            for try await line in FileHandle.standardInput.bytes.lines {
                if line.isEmpty { continue }
                
                guard let data = line.data(using: .utf8) else { continue }
                do {
                    guard let handler = actorSystem else { break }
                    let enveloppe = try JSONDecoder().decode(Enveloppe.self, from: data)
                    try handler.handle(enveloppe: enveloppe)
                }
                catch {
                    // Do something with the error
                }
            }
            exit(0)
        }
    }
    
    func send(to: NodeID, enveloppe: Enveloppe) async throws {
        var data = try JSONEncoder().encode(enveloppe)
        data.append(UInt8(ascii: "\n"))
        try FileHandle.standardOutput.write(contentsOf: data)
    }
}
