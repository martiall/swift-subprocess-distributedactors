import Distributed
/*
@Resolvable
public protocol Greeter: DistributedActor where ActorSystem: DistributedActorSystem<any Codable> {
    distributed func greet(name: String) -> String
}
*/

import PluginDistributedActors

public protocol Greeter: Sendable {
    func greet(name: String) async throws -> String
}

public distributed actor _Greeter: Greeter {
    public typealias ActorSystem = PluginActorSystem
    
    let inner: any Greeter
    
    public init(greeter: any Greeter, actorSystem: PluginActorSystem) {
        self.inner = greeter
        self.actorSystem = actorSystem
    }
    
    distributed public func greet(name: String) async throws -> String {
        try await self.inner.greet(name: name)
    }
}