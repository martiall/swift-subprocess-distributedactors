#if !os(WASI)
import Foundation
import PluginDistributedActors
import WasmKit
import WasmKitWASI
import Foundation
import SystemPackage

extension PluginActorSystem {
    public func spawnWasmGuest(url: URL) async throws -> NodeID {
        try await self.spawnGuest {
            try WasmKitGuestProcess(url: url)
        }
    }
}

private actor WasmKitGuestProcess: Transport {
    private let nodeID: NodeID = "WasmKit(\(UUID().uuidString))"
    
    private let wasmThread: Thread
    
    private let inboundStream: AsyncStream<Data>
    private let enveloppeBuffer: EnveloppeBuffer
    
    class EnveloppeBuffer: @unchecked Sendable {
        private let outboundLock: Lock = .init()
        private var outboundBuffer: [Data] = []
        
        func withLock<R>(_ block: (inout [Data]) throws -> R) rethrows -> R {
            try outboundLock.withLock {
                try block(&outboundBuffer)
            }
        }
        
        func ifEnveloppeAvailable<R>(_ block: (Data) throws -> R) rethrows -> R? {
            try outboundLock.withLock {
                guard outboundBuffer.isEmpty == false else { return nil }
                return try block(outboundBuffer.removeFirst())
            }
        }
    }
    
    init(url: URL) throws {
        let inbound = AsyncStream.makeStream(of: Data.self, bufferingPolicy: .unbounded)
        self.inboundStream = inbound.stream
        
        let enveloppeBuffer = EnveloppeBuffer()
        self.enveloppeBuffer = enveloppeBuffer
        
        self.wasmThread = Thread { [enveloppeBuffer, nodeID] in
            do {
                let bytes = try Data(contentsOf: url)
                let module = try parseWasm(bytes: Array(bytes))
                let wasi = try WASIBridgeToHost(
                    args: [nodeID]
                )
                var hostModules = wasi.hostModules
                
                hostModules["WasmKitDistributedActorsHost"] = HostModule(functions: [
                    "wasmkit_distributedactors_inbound_enveloppe": HostFunction(
                        type: FunctionType(
                            parameters: [.i32],
                            results: [.i32]
                        ),
                        implementation: { [enveloppeBuffer] caller, args in
                            let ptr = args[0].i32
                            
                            guard let data = enveloppeBuffer.ifEnveloppeAvailable({ $0 })
                            else {
                                return [.i32(0)]
                            }
                            
                            guard case let .memory(memoryAddr) = caller.instance.exports["memory"]
                                else { fatalError("Missing \"memory\" export") }
                            
                            guard case .i32(let address) = try? caller.runtime.invoke(
                                caller.instance,
                                function: "wasmkit_distributedactors_allocate",
                                with: [.i32(UInt32(data.count))]
                            )[0] else { fatalError() }

                            WasmKitGuestMemory(store: caller.store, address: memoryAddr)
                                .withUnsafeMutableBufferPointer(offset: UInt(address), count: data.count) { mutableBuffer in
                                    mutableBuffer.copyBytes(from: data)
                                }
                            
                            return WasmKitGuestMemory(store: caller.store, address: memoryAddr)
                                .withUnsafeMutableBufferPointer(
                                    offset: UInt(ptr),
                                    count: MemoryLayout<UnsafeMutableRawPointer?>.size
                                ) { buffer in
                                    buffer.withMemoryRebound(to: UInt32.self) { buffer in
                                        buffer[0] = address
                                        return [.i32(UInt32(data.count))]
                                    }
                                }
                        }),
                    "wasmkit_distributedactors_outbound_enveloppe": HostFunction(
                        type: FunctionType(
                            parameters: [.i32, .i32],
                            results: []
                        ),
                        implementation: { [continuation = inbound.continuation] caller, args in
                            let ptr = args[0].i32
                            let count = args[1].i32
                            
                            guard case let .memory(memoryAddr) = caller.instance.exports["memory"]
                                else { fatalError("Missing \"memory\" export") }
                            
                            _ = WasmKitGuestMemory(store: caller.store, address: memoryAddr)
                                .withUnsafeMutableBufferPointer(offset: UInt(ptr), count: Int(count)) { buffer in
                                    continuation.yield(Data(buffer))
                                }
                            
                            return []
                        })
                ])
                let runtime = Runtime(hostModules: hostModules)
                let moduleInstance = try runtime.instantiate(module: module)
                
                let result = try wasi.start(moduleInstance, runtime: runtime)
                switch result {
                case 0:
                    break
                default:
                    fatalError("Wasm start failed with \(result) code.")
                }
            } catch {
                //TODO: Do something with the error
                print("Wasm Error: \(error)")
            }
        }
        self.wasmThread.name = self.nodeID
    }
    
    func start(continuation: AsyncStream<Enveloppe>.Continuation) throws -> NodeID {
        self.wasmThread.start()
        
        Task.detached { [inbound = self.inboundStream] in
            for try await data in inbound {
                do {
                    let enveloppe = try JSONDecoder().decode(Enveloppe.self, from: data)
                    continuation.yield(enveloppe)
                } catch {
                    print(error)
                }
            }
        }
        
        return nodeID
    }
    
    func send(enveloppe: Enveloppe) throws {
        let data = try JSONEncoder().encode(enveloppe)
        self.enveloppeBuffer.withLock { enveloppes in
            enveloppes.append(data)
        }
    }
}

#endif