struct Enveloppe: Codable, Sendable {
    let from: NodeID
    let to: NodeID
    let callId: CallID
    let message: Message
}

enum Message: Codable, Sendable {
    case call(Call)
    case reply(Reply)
    
    struct Call: Codable, Sendable {
        let callee: SubprocessActorID
        let target: String
        let arguments: [[UInt8]]
        let generics: [String]
    }
    
    enum Reply: Codable, Sendable {
        case success([UInt8])
        case failure(Error) //TODO: Find a way to deserialize an 'arbitrary' Error
        
        enum Error: Codable, Swift.Error {
            case unknown
        }
    }
}
