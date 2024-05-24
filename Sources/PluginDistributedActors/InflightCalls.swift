internal typealias CallID = Int

internal actor InflightCalls {
    private enum InflightCallError: Error {
       case unknownCall(CallID)
    }
    
    private typealias CallContinuation = CheckedContinuation<[UInt8], any Error>
    private var callContinuations: [CallID: CallContinuation] = [:]
    
    private var nextCallId = 0
    
    private func awaitForReply(continuation: CallContinuation) -> CallID {
        let callId = nextCallId
        nextCallId += 1
        callContinuations[callId] = continuation
        return callId
    }
    
    func onReceivedReply(callId: CallID, data: [UInt8]) throws {
        guard let continuation = callContinuations.removeValue(forKey: callId) else {
            throw InflightCallError.unknownCall(callId)
        }
        continuation.resume(returning: data)
    }
    
    func onReceivedError(callId: CallID, error: any Error) throws {
        guard let continuation = callContinuations.removeValue(forKey: callId) else {
            throw InflightCallError.unknownCall(callId)
        }
        continuation.resume(throwing: error)
    }
    
    nonisolated func call(_ body: @Sendable @escaping (CallID) async throws -> Void) async throws -> [UInt8] {
        try await withCheckedThrowingContinuation { continuation in
            Task {
                let callId = await self.awaitForReply(continuation: continuation)
                do {
                    try await body(callId)
                } catch {
                    try await self.onReceivedError(callId: callId, error: error)
                }
            }
        }
    }
}
