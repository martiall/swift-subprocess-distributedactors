import SubprocessDistributedActors
import Greeter
import Distributed

actor EnglishGreeter: Greeter {
    func greet(name: String) async throws -> String {
        "Hello \(name)!"
    }
}

let system = try await SubprocessActorSystem.makeGuest()

let actor = _Greeter(greeter: EnglishGreeter(), system: system)

while(!Task.isCancelled) {
    withExtendedLifetime(system, {})
    withExtendedLifetime(actor, {})
    try await Task.sleep(for: .seconds(1))
}
