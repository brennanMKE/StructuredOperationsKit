import Foundation

struct NumberProvider {
    let number: Int
    let delay: Double
    let shouldCancelTask: Bool

    var value: Int {
        get async throws {
            let task = Task<Int, Error> {
                try await Task.sleep(seconds: delay)
                return number
            }

            if shouldCancelTask {
                Task {
                    task.cancel()
                }
            }

            return try await task.value
        }
    }
}
