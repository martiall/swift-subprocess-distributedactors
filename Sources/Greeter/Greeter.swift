import Distributed
import SubprocessDistributedActors

/*
@Resolvable
public protocol Greeter: DistributedActor where ActorSystem: DistributedActorSystem<any Codable> {
    distributed func greet(name: String) async throws -> String
}
*/

public protocol Greeter: Sendable {
    func greet(name: String) async throws -> String
}

public distributed actor _Greeter: Greeter {
    public typealias ActorSystem = SubprocessActorSystem
    
    let inner: any Greeter
    
    public init(greeter: any Greeter, system: SubprocessActorSystem) {
        self.inner = greeter
        self.actorSystem = system
    }
    
    distributed public func greet(name: String) async throws -> String {
        try await self.inner.greet(name: name)
    }
    
    distributed public func polyglot(ids: [SubprocessActorID], name: String) async throws -> [String] {
        var result: [String] = []
        for id in ids {
            let greeter = try _Greeter.resolve(id: id, using: self.actorSystem)
            result.append(try await greeter.greet(name: name))
        }
        return result
    }
}
