import Foundation
import Greeter
import Distributed
#if os(WASI)
import WasmKitDistributedActors
let from = "Wasm"
#else
let from = "Subprocess"
import SubprocessDistributedActors
#endif
import Logging

typealias DefaultDistributedActorSystem = PluginActorSystem

LoggingSystem.bootstrap { label in
    StreamLogHandler.standardError(label: label)
}

/*distributed*/ actor FrenchGreeter: Greeter {
    /*distributed*/ func greet(name: String) -> String {
        "[\(from)] Bonjour \(name)!"
    }
}

/*distributed*/ actor ProuvencualGreeter: Greeter {
    /*distributed*/ func greet(name: String) -> String {
        "[\(from)] Bouan jou \(name)!"
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

#if os(WASI)
try await PluginActorSystem.makeWasmKitGuest(builder)
#else
try await PluginActorSystem.makeSubprocessGuest(builder)
#endif
