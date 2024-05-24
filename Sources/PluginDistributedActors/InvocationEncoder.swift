import Distributed
import Foundation

public struct PluginActorInvocationEncoder: DistributedTargetInvocationEncoder {
    public typealias SerializationRequirement = any Codable
    let encoder = JSONEncoder()
    
    var generics: [String] = .init()
    var arguments: [[UInt8]] = .init()
    var returnType: String? = nil
    var errorType: String? = nil
    
    /// Record an argument of `Argument` type.
    /// This will be invoked for every argument of the target, in declaration order.
    public mutating func recordArgument<Value: Codable>(
        _ argument: RemoteCallArgument<Value>
    ) throws {
        arguments.append(Array(try encoder.encode(argument.value)))
    }
    
    /// The arguments must be encoded order-preserving, and once `decodeGenericSubstitutions`
    /// is called, the substitutions must be returned in the same order in which they were recorded.
    ///
    /// - Parameter type: a generic substitution type to be recorded for this invocation.
    public mutating func recordGenericSubstitution<T>(_ type: T.Type) throws {
        if let mangledName = _mangledTypeName(type) {
            generics.append(mangledName)
        }
    }

    public mutating func recordReturnType<R: Codable>(_ type: R.Type) throws {
        self.returnType = _mangledTypeName(type)
    }

    public mutating func recordErrorType<E: Error>(_ type: E.Type) throws {
        self.errorType = _mangledTypeName(type)
    }

    public mutating func doneRecording() throws {
        
    }
    
}
