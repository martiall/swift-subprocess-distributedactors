import Foundation
import SubprocessDistributedActors
import WasmKitDistributedActors
import Greeter
import ArgumentParser
import Logging

@main
struct Host: AsyncParsableCommand {
    @Option(name: .shortAndLong, parsing: .upToNextOption, help: "Load guest with WasmKit.")
    var wasm: [String] = []
    
    @Option(name: .shortAndLong, parsing: .upToNextOption, help: "Load guest by spawning subprocess.")
    var process: [String] = []

    mutating func run() async throws {
        LoggingSystem.bootstrap { label in
            StreamLogHandler.standardError(label: label)
        }
        
        let host = try await PluginActorSystem.makeHost()

        var greeters: [any Greeter] = []

        let wasmUrls = self.wasm.map { URL(filePath: $0) }
        let processUrls = self.process.map { URL(filePath: $0) }

        for url in processUrls {
            let nodeId = try await host.spawnSubprocessGuest(url: url)
            let greeter = try _Greeter.resolve(
                id: PluginActorSystem.ActorID(nodeId: nodeId, localId: 0),
                using: host
            )
            greeters.append(greeter)
        }
        for url in wasmUrls {
            let nodeId = try await host.spawnWasmGuest(url: url)
            let greeter = try _Greeter.resolve(
                id: PluginActorSystem.ActorID(nodeId: nodeId, localId: 0),
                using: host
            )
            greeters.append(greeter)
        }

        for greeter in greeters {
            print(try await greeter.greet(name: "Swift"))
        }
    }
}

