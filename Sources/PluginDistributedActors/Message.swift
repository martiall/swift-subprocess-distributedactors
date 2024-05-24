public struct Enveloppe: Codable, Sendable {
    let from: NodeID
    let to: NodeID
    let callId: CallID
    let message: Message
}

public enum Message: Codable, Sendable {
    case call(Call)
    case reply(Reply)
    
    public struct Call: Codable, Sendable {
        let callee: PluginActorID
        let target: String
        let arguments: [[UInt8]]
        let generics: [String]
        let returnType: String?
        let errorType: String?
    }
    
    public enum Reply: Codable, Sendable {
        case success([UInt8])
        case failure(Error) //TODO: Find a way to deserialize an 'arbitrary' Error
        
        public enum Error: Codable, Swift.Error {
            case unknown
        }
    }
}
