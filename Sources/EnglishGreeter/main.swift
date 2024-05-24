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

/*distributed*/ actor EnglishGreeter: Greeter {
    /*distributed*/ func greet(name: String) -> String {
        "[\(from)] Hello \(name)!"
    }
}

let builder: @Sendable (PluginActorSystem) -> [_Greeter] = {
    [
        //EnglishGreeter(actorSystem: $0)
        _Greeter(greeter: EnglishGreeter(), actorSystem: $0)
    ]
}
#if os(WASI)
try await PluginActorSystem.makeWasmKitGuest(builder)
#else
try await PluginActorSystem.makeSubprocessGuest(builder)
#endif

