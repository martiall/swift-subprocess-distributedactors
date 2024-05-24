import Foundation
import Greeter
import Distributed
import SubprocessDistributedActors
import Logging

typealias DefaultDistributedActorSystem = PluginActorSystem

LoggingSystem.bootstrap { label in
    StreamLogHandler.standardError(label: label)
}

/*distributed*/ actor FrenchGreeter: Greeter {
    /*distributed*/ func greet(name: String) -> String {
        "Bonjour \(name)!"
    }
}

/*distributed*/ actor ProuvencualGreeter: Greeter {
    /*distributed*/ func greet(name: String) -> String {
        "Bouan jou \(name)!"
    }
}
let builder: @Sendable (PluginActorSystem) -> [_Greeter] = {
    return [
        //FrenchGreeter(actorSystem: $0),
        //ProuvencualGreeter(actorSystem: $0)
        _Greeter(greeter: FrenchGreeter(), actorSystem: $0),
        _Greeter(greeter: ProuvencualGreeter(), actorSystem: $0)
    ]
}

try await PluginActorSystem.makeSubprocessGuest(builder)
