#if os(WASI)
import Distributed
import Foundation
import PluginDistributedActors
import WasmKitDistributedActorsHostFunctions

func WasmKitDistributedActorsInboundEnveloppe() -> Enveloppe? {
    let ptr = UnsafeMutablePointer<UnsafeMutableRawPointer?>.allocate(capacity: 1)
    defer { ptr.deallocate() }

    let length = Int(wasmkit_distributedactors_inbound_enveloppe(ptr))
    
    guard length != 0 else { return nil }
    guard let pointer = ptr.pointee else { return nil }
    
    let data = Data(bytesNoCopy: pointer, count: length, deallocator: .free)
    guard let enveloppe = try? JSONDecoder().decode(Enveloppe.self, from: data)
        else { return nil }
    return enveloppe
}

func WasmKitDistributedActorsOutboundEnveloppe(data: Data) {
    data.withUnsafeBytes { pointer in
        wasmkit_distributedactors_outbound_enveloppe(pointer.baseAddress, Int32(pointer.count))
    }
}

extension PluginActorSystem {
    public static func makeWasmKitGuest(_ builder: @Sendable @escaping (PluginActorSystem) async throws -> [any DistributedActor]) async throws {
        let system =  try await Self(
            transport: WasmKitGuestTransport()
        )
        
        let actors = try await builder(system)
        while(!Task.isCancelled) {
            withExtendedLifetime(system, {})
            withExtendedLifetime(actors, {})
            try await Task.sleep(for: .seconds(1))
        }
    }
}

fileprivate actor WasmKitGuestTransport: Transport {
    func start(continuation: AsyncStream<Enveloppe>.Continuation) throws -> NodeID {
        Task.detached {
            while Task.isCancelled == false {
                while let enveloppe = WasmKitDistributedActorsInboundEnveloppe() {
                    continuation.yield(enveloppe)
                }
                
                try await Task.sleep(for: .microseconds(1))
            }
            exit(0)
        }
        return CommandLine.arguments[0]
    }
    
    func send(enveloppe: Enveloppe) async throws {
        let data = try JSONEncoder().encode(enveloppe)
        WasmKitDistributedActorsOutboundEnveloppe(data: data)
    }
}
#endif