import Foundation

extension SubprocessActorSystem {
    public static func makeHost() async throws -> Self {
        try await Self(
            nodeId: ProcessInfo.processInfo.processIdentifier,
            transport: HostTransport()
        )
    }
    
    public func spawnGuest(url: URL) async throws -> NodeID {
        guard let host = self.transport as? HostTransport
            else { fatalError() }
        
        return try await host.spawnGuest(url: url)
    }
}

fileprivate actor HostTransport: Transport {
    weak var actorSystem: SubprocessActorSystem?

    private var guests: [NodeID: GuestProcess] = [:]
    
    private actor GuestProcess {
        weak var transport: HostTransport?
        
        private let process: Process
        let writeHandle: FileHandle
        
        init(transport: HostTransport, url: URL) throws {
            self.transport = transport
            
            guard url.isFileURL 
                else { throw SubprocessActorSystemError.urlNotFound }
            
            let path = url.path()
            guard FileManager.default.isExecutableFile(atPath: path)
                else { throw SubprocessActorSystemError.fileIsNotExecutable }
            
            self.process = Process()
            let pipeStdin = Pipe()
            let pipeStdout = Pipe()
            self.writeHandle = pipeStdin.fileHandleForWriting
            
            process.standardInput = pipeStdin
            process.standardOutput = pipeStdout
            
            process.executableURL = url
            process.terminationHandler = { [weak transport] process in
                transport?.terminate(nodeId: process.processIdentifier)
            }
            
            let pid = process.processIdentifier
            
            Task.detached { [weak transport, pid] in
                for try await line in pipeStdout.fileHandleForReading.bytes.lines {
                    if line.isEmpty { continue }
                    
                    guard let data = line.data(using: .utf8) else { continue }
                    do {
                        guard let handler = transport else { break }
                        let enveloppe = try JSONDecoder().decode(Enveloppe.self, from: data)
                        try await handler.handle(enveloppe: enveloppe, from: pid)
                    }
                    catch {
                        // Do something with the error
                    }
                }
            }
            
            try process.run()
        }
        
        func send(enveloppe: Enveloppe) throws {
            var data = try JSONEncoder().encode(enveloppe)
            data.append(UInt8(ascii: "\n"))
            try self.writeHandle.write(contentsOf: data)
        }
        
        public var nodeId: NodeID { process.processIdentifier }
    }
    
    func start(actorSystem: SubprocessActorSystem) {
        self.actorSystem = actorSystem
    }
    
    func spawnGuest(url: URL) async throws -> NodeID {
        let guest = try GuestProcess(transport: self, url: url)
        let nodeId = await guest.nodeId
        self.guests[nodeId] = guest
        return nodeId
    }
    
    func send(to: NodeID, enveloppe: Enveloppe) async throws {
        guard let guestProcess = self.guests[to]
            else { fatalError() }
        
        try await guestProcess.send(enveloppe: enveloppe)
    }
    
    func handle(enveloppe: Enveloppe, from nodeId: NodeID) throws {
        try self.actorSystem?.handle(enveloppe: enveloppe)
    }
    
    private func removeNode(id: NodeID) {
        self.guests[id] = nil
    }
    
    nonisolated func terminate(nodeId: NodeID) {
        Task.detached {
            await self.removeNode(id: nodeId)
        }
    }
}
