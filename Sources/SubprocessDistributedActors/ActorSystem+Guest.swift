import Distributed
import Foundation
import PluginDistributedActors

extension PluginActorSystem {
    public static func makeSubprocessGuest(_ builder: @Sendable @escaping (PluginActorSystem) async throws -> [any DistributedActor]) async throws {
        let system =  try await Self(
            transport: SubprocessGuestTransport()
        )
        
        let actors = try await builder(system)
        
        while(!Task.isCancelled) {
            withExtendedLifetime(system, {})
            withExtendedLifetime(actors, {})
            try await Task.sleep(for: .seconds(1))
        }
    }
}

fileprivate actor SubprocessGuestTransport: Transport {
    func start(continuation: AsyncStream<Enveloppe>.Continuation) throws -> NodeID {
        Task.detached {
            for try await line in FileHandle.standardInput.bytes.lines {
                if line.isEmpty { continue }
                
                guard let data = line.data(using: .utf8) else { continue }
                do {
                    let enveloppe = try JSONDecoder().decode(Enveloppe.self, from: data)
                    continuation.yield(enveloppe)
                }
                catch {
                    // Do something with the error
                }
            }
            exit(0)
        }

        return ProcessInfo.processInfo.nodeID
    }
    
    func send(enveloppe: Enveloppe) async throws {
        var data = try JSONEncoder().encode(enveloppe)
        data.append(UInt8(ascii: "\n"))
        try FileHandle.standardOutput.write(contentsOf: data)
    }
}