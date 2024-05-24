import Distributed

@Resolvable
public protocol Greeter: DistributedActor where ActorSystem: DistributedActorSystem<any Codable> {
    distributed func greet(name: String) -> String
}