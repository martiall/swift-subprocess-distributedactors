import Greeter
import Distributed
import SubprocessDistributedActors
import Logging

typealias DefaultDistributedActorSystem = PluginActorSystem

LoggingSystem.bootstrap { label in
    StreamLogHandler.standardError(label: label)
}

/*distributed*/ actor EnglishGreeter: Greeter {
    /*distributed*/ func greet(name: String) -> String {
        "Hello \(name)!"
    }
}

let builder: @Sendable (PluginActorSystem) -> [_Greeter] = {
    [
        //EnglishGreeter(actorSystem: $0)
        _Greeter(greeter: EnglishGreeter(), actorSystem: $0)
    ]
}

try await PluginActorSystem.makeSubprocessGuest(builder)