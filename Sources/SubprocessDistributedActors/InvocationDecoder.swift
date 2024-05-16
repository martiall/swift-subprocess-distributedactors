import Distributed
import Foundation

public struct SubprocessActorInvocationDecoder: DistributedTargetInvocationDecoder {
    public typealias SerializationRequirement = any Codable
    
    private let decoder: JSONDecoder = .init()
    
    var argumentsIterator: [[UInt8]].Iterator
    let generics: [String]
    
    init(argumentsIterator: [[UInt8]].Iterator, generics: [String]) {
        self.argumentsIterator = argumentsIterator
        self.generics = generics
    }
    
    /// Ad-hoc protocol requirement
    ///
    /// Attempt to decode the next argument from the underlying buffers into pre-allocated storage
    /// pointed at by 'pointer'.
    ///
    /// This method should throw if it has no more arguments available, if decoding the argument failed,
    /// or, optionally, if the argument type we're trying to decode does not match the stored type.
    ///
    /// The result of the decoding operation must be stored into the provided 'pointer' rather than
    /// returning a value. This pattern allows the runtime to use a heavily optimized, pre-allocated
    /// buffer for all the arguments and their expected types. The 'pointer' passed here is a pointer
    /// to a "slot" in that pre-allocated buffer. That buffer will then be passed to a thunk that
    /// performs the actual distributed (local) instance method invocation.
    public mutating func decodeNextArgument<Argument: Codable>() throws -> Argument {
        guard let next = argumentsIterator.next() else {
            fatalError("Not enought argument")
        }
        
        return try decoder.decode(Argument.self, from: Data(next))
    }
    
    

    public mutating func decodeGenericSubstitutions() throws -> [Any.Type] {
        generics.compactMap({ _typeByName($0) })
    }

    /// Decode the specific error type that the distributed invocation target has recorded.
    /// Currently this effectively can only ever be `Error.self`.
    ///
    /// If the target known to not be throwing, or no error type was recorded, the method should return `nil`.
    public mutating func decodeErrorType() throws -> (Any.Type)? {
        return nil
    }

    /// Attempt to decode the known return type of the distributed invocation.
    ///
    /// It is legal to implement this by returning `nil`, and then the system
    /// will take the concrete return type from the located function signature.
    public mutating func decodeReturnType() throws -> (Any.Type)? {
        return nil
    }
}
