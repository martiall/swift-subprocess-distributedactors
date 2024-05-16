# swift-subprocess-distributedactors

Library to spawn/call DistributedActors implementations in child processes from an host process.

Only implement the most basic features on the Distributed Actor System.

Disclamer: this is mainly educational work to play with distributed actor system.

## Running the sample app

1. In the root folder call `swift build`
2. Run the host application `swift run Host`

The Host will look for two executable in `.build/debug/` and load them.

Should output the following:

```
Hello Swift!
Bonjour Swift!
["Hello Swifty!", "Bonjour Swifty!"]
```

First two lines are the host calling distributed actors in the two children processes.
Last line in the first child calling itself and the other child.

## Acknowledgement
Lock implementation comes from https://github.com/apple/swift-distributed-actors which comes from https://github.com/apple/swift-nio

Inspirations were taken from:
- https://github.com/apple/swift-distributed-actors
- https://github.com/heckj/WebsocketActorSystem
