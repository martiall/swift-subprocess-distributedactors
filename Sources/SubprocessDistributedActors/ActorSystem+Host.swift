import Foundation
import PluginDistributedActors

extension  PluginActorSystem {
    public func spawnSubprocessGuest(url: URL) async throws -> NodeID {
        try await self.spawnGuest {
            try GuestProcess(url: url)
        }
    }
}

private actor GuestProcess: Transport {
    private let process: Process
    let writeHandle: FileHandle

    init(url: URL) throws {
        guard url.isFileURL 
            else { throw PluginActorSystemError.urlNotFound }
        
        let path = url.path()
        guard FileManager.default.isExecutableFile(atPath: path)
            else { throw PluginActorSystemError.fileIsNotExecutable }
        
        self.process = Process()
        let pipeStdin = Pipe()
        
        self.writeHandle = pipeStdin.fileHandleForWriting
        
        process.standardInput = pipeStdin
        process.executableURL = url

        process.terminationHandler = { process in
            //TODO: Handle process termination
            //transport?.terminate(nodeID: process.nodeID)
        }
    }

    func start(continuation: AsyncStream<Enveloppe>.Continuation) throws -> NodeID {
        let pipeStdout = Pipe()
        process.standardOutput = pipeStdout

        try process.run()

        Task.detached {
            for try await line in pipeStdout.fileHandleForReading.bytes.lines {
                if line.isEmpty { continue }
                
                guard let data = line.data(using: .utf8) else { continue }
                do {
                    let enveloppe = try JSONDecoder().decode(Enveloppe.self, from: data)
                    continuation.yield(enveloppe)
                }
                catch {
                    // Do something with the error
                }
            }
        }

        return process.nodeID
    }
    
    func send(enveloppe: Enveloppe) throws {
        var data = try JSONEncoder().encode(enveloppe)
        data.append(UInt8(ascii: "\n"))
        try self.writeHandle.write(contentsOf: data)
    }
}