import Foundation
import AsyncChannelKit

enum AsyncRunnerState: String {
    case ready = "isReady"
    case executing = "isExecuting"
    case finished  = "isFinished"
    case cancelled = "isCancelled"
}

protocol Cancellable {
    func cancel()
}

public typealias AsyncDoneClosure = () -> Void

public protocol AsyncRunner {
    func run(done: @escaping AsyncDoneClosure)
}

open class ParentOperation<Status, Success, Failure: Error>: Operation, AsyncRunner, Cancellable {
    actor Child {
        var parent: Cancellable? = nil
        var statusChannel: AsyncChannel<Status>? = nil
        var valueContinuation: CheckedContinuation<Success, Error>? = nil
        var result: Result<Success, Failure>? = nil
        var isCancelled = false

        var status: AsyncChannel<Status> {
            let channel: AsyncChannel<Status>
            if let statusChannel = statusChannel {
                channel = statusChannel
            } else {
                channel = AsyncChannel<Status>()
                statusChannel = channel
            }

            // finish channel if there is already a result
            if result != nil || isCancelled {
                Task {
                    // finish will cause the call to next() to end the sequence
                    await channel.finish()
                }
            }
            return channel
        }

        var value: Success {
            get async throws {
                try await withCheckedThrowingContinuation { continuation in
                    if isCancelled {
                        // immediately cancel is already cancelled
                        continuation.resume(throwing: CancellationError())
                    } else if let result = result {
                        // immediately send result if it is available
                        send(result: result, continuation: continuation)
                    } else {
                        // capture contination to use later
                        valueContinuation = continuation
                    }
                }
            }
        }

        // set the parent to coordinate cancellation
        func setParent(parent: Cancellable) {
            self.parent = parent
        }

        func report(_ status: Status?) async throws {
            if let channel = statusChannel {
                if let status = status {
                    try await channel.send(status)
                } else {
                    // nil indicates the sequence is done
                    await channel.finish()
                }
            }
        }

        func finish(_ result: Result<Success, Failure>) {
            if let continuation = valueContinuation {
                send(result: result, continuation: continuation)
            } else {
                // store result for when the value property is used
                self.result = result
            }
        }

        func cancel() async {
            guard !isCancelled else {
                return
            }
            isCancelled = true
            if let channel = statusChannel {
                await channel.finish()
            }
            if let continuation = valueContinuation {
                continuation.resume(throwing: CancellationError())
            }
            // cancels the parent operation
            assert(parent != nil, "Parent cannot be nil")
            parent?.cancel()
        }

        private func send(result: Result<Success, Failure>, continuation: CheckedContinuation<Success, Error>) {
            switch result {
            case .success(let success):
                continuation.resume(returning: success)
            case .failure(let failure):
                continuation.resume(throwing: failure)
            }
            valueContinuation = nil
        }

    }

    let child: Child

    var state: AsyncRunnerState = .ready

    // handle KVO events before changing state
    func transition(to newState: AsyncRunnerState) {
        guard state != newState else { return }

        willChangeValue(forKey: newState.rawValue)
        willChangeValue(forKey: state.rawValue)

        state = newState

        didChangeValue(forKey: state.rawValue)
        didChangeValue(forKey: newState.rawValue)
    }

    public override var isReady: Bool {
        state == .ready
    }

    public override var isExecuting: Bool {
        state == .executing
    }

    public override var isFinished: Bool {
        state == .finished
    }

    public override var isCancelled: Bool {
        state == .cancelled || Task.isCancelled
    }

    public override init() {
        self.child = Child()
        defer {
            Task {
                await child.setParent(parent: self)
            }
        }
        super.init()
    }

    public override var isAsynchronous: Bool { true }

    public override func start() {
        guard !isCancelled else { return }

        transition(to: .executing)

        let done: AsyncDoneClosure = { [weak self] in
            guard let self = self else { fatalError() }
            self.transition(to: .finished)
        }

        run(done: done)
    }

    public var status: AsyncChannel<Status> {
        get async {
            await child.status
        }
    }

    public var value: Success {
        get async throws {
            try await child.value
        }
    }

    public func run(done: @escaping AsyncDoneClosure) {
        fatalError("Must override")
    }

    /// Cancel operation and task
    public override func cancel() {
        guard state != .cancelled else {
            return
        }
        transition(to: .cancelled)
        Task {
            await child.cancel()
        }
    }

    public func cancelTask() async {
        await child.cancel()
    }

    public func report(_ status: Status) async throws {
        try await child.report(status)
    }

    public func finish(_ result: Result<Success, Failure>) async {
        await child.finish(result)
    }

}
