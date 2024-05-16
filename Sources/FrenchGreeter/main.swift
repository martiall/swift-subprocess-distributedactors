import Foundation
import SubprocessDistributedActors
import Greeter

actor FrenchGreeter: Greeter {
    func greet(name: String) async throws -> String {
        "Bonjour \(name)!"
    }
}

let system = try await SubprocessActorSystem.makeGuest()

let actor = _Greeter(greeter: FrenchGreeter(), system: system)

while(!Task.isCancelled) {
    withExtendedLifetime(system, {})
    withExtendedLifetime(actor, {})
    try await Task.sleep(for: .seconds(1))
}
