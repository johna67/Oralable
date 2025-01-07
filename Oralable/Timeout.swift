import Foundation

public struct TimeoutError: LocalizedError {
    public var errorDescription: String?

    init(_ description: String) {
        self.errorDescription = description
    }
}

public func withThrowingTimeout<T>(
    isolation: isolated (any Actor)? = #isolation,
    seconds: TimeInterval? = nil,
    body: () async throws -> sending T
) async throws -> sending T {
    guard let seconds else {
        defer { _ = isolation }
        return try await body()
    }
    return try await _withThrowingTimeout(isolation: isolation, body: body) {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        throw TimeoutError("Task timed out before completion. Timeout: \(seconds) seconds.")
    }.value
}

private func _withThrowingTimeout<T>(
    isolation: isolated (any Actor)? = #isolation,
    body: () async throws -> sending T,
    timeout: @Sendable @escaping () async throws -> Never
) async throws -> Transferring<T> {
    try await withoutActuallyEscaping(body) { escapingBody in
        let bodyTask = Task {
            defer { _ = isolation }
            return try await Transferring(escapingBody())
        }
        let timeoutTask = Task {
            defer { bodyTask.cancel() }
            try await timeout()
        }

        let bodyResult = await withTaskCancellationHandler {
            await bodyTask.result
        } onCancel: {
            bodyTask.cancel()
        }
        timeoutTask.cancel()

        if case .failure(let timeoutError) = await timeoutTask.result,
           timeoutError is TimeoutError {
            throw timeoutError
        } else {
            return try bodyResult.get()
        }
    }
}

private struct Transferring<Value>: Sendable {
    nonisolated(unsafe) public var value: Value
    init(_ value: Value) {
        self.value = value
    }
}
