import Foundation
import SubprocessDistributedActors
import Greeter

let host = try await SubprocessActorSystem.makeHost()

var greeters: [_Greeter] = []

let greetersUrls = ["EnglishGreeter", "FrenchGreeter"].map {
    URL(filePath: FileManager.default.currentDirectoryPath + "/.build/debug/" + $0)
}

for url in greetersUrls {
    let nodeId = try await host.spawnGuest(url: url)
    let greeter = try _Greeter.resolve(
        id: SubprocessActorSystem.ActorID(nodeId: nodeId, localId: 0),
        using: host
    )
    greeters.append(greeter)
}

for greeter in greeters {
    print(try await greeter.greet(name: "Swift"))
}

// Test communication between guests
print(try await greeters[0].polyglot(ids: greeters.map({ $0.id }), name: "Swifty"))
