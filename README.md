# swift-subprocess-distributedactors

Library to spawn/call DistributedActors implementations in child processes from an host process.

Only implement the most basic features on the Distributed Actor System.

Disclamer: this is mainly educational work to play with distributed actor system.

## Pre-requirement

Swift Toolchain `swift-6.0-DEVELOPMENT-SNAPSHOT-2024-04-14-a`
Swift WASM Toolchain `swift-wasm-6.0-SNAPSHOT-2024-05-01-a`

## Running the sample app

1. In the root folder launch `./build_and_test.sh`. It will build the plugins and launch the host.

Should output the following:

```
[Subprocess] Hello Swift!
[Subprocess] Bonjour Swift!
[Wasm] Hello Swift!
[Wasm] Bonjour Swift!
```

Two first lines are the host calling distributed actors in the two children processes.
Two last lines are the host calling distributed actors in the two WasmKit virtual machine.

## Acknowledgement
Lock implementation comes from https://github.com/apple/swift-distributed-actors which comes from https://github.com/apple/swift-nio

Inspirations were taken from:
- https://github.com/apple/swift-distributed-actors
- https://github.com/heckj/WebsocketActorSystem
