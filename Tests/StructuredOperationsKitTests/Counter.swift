import Foundation
@testable import StructuredOperationsKit

extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: Double) async throws {
        let nanoseconds = UInt64(seconds * Double(NSEC_PER_SEC))
        try await Task.sleep(nanoseconds: nanoseconds)
    }
}

extension Array where Element == Int {
    func sum() -> Int {
        reduce(0, +)
    }
}

class Counter: ParentOperation<Progress, Int, Error> {
    let numbers: [Int]
    let delay: Double
    let condition: ((Int) -> Bool)?

    public init(numbers: [Int], delay: Double = 0.25, condition: ((Int) -> Bool)? = nil) {
        self.numbers = numbers
        self.delay = delay
        self.condition = condition

        super.init()
    }

    public override func run(done: @escaping AsyncDoneClosure) {
        Task {
            try await withTaskCancellationHandler {
                defer {
                    done()
                }

                var index = 0
                var total = 0
                let progress = Progress(totalUnitCount: Int64(numbers.count))

                while index < numbers.count && !isCancelled {
                    try await Task.sleep(seconds: delay)
                    total += numbers[index]
                    if let condition = condition, condition(index) {
                        abort()
//                        throw CancellationError()
                    }
                    progress.completedUnitCount = Int64(index + 1)
                    try await report(progress)
                    await Task.yield()
                    index += 1
                }

                await finish(.success(total))
            } onCancel: {
                cancel()
            }
        }
    }

}
