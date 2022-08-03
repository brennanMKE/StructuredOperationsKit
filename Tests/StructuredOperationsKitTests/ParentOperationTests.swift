import XCTest
@testable import StructuredOperationsKit

final class ParentOperationTests: XCTestCase {
    let delay: Double = 0.1

    func testCountingToCompletion() async throws {
        let input = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

        let counter = Counter(numbers: input, delay: delay)
        counter.start()

        Task {
            for await progress in await counter.status {
                print("Progress: \(String(format: "%.2f", progress.fractionCompleted))")
            }
        }

        var thrown: Error? = nil

        do {
            let output = try await counter.value
            print("Output: \(output)")
            XCTAssertEqual(input.sum(), output)
        } catch {
            thrown = error
        }

        XCTAssertNil(thrown)
    }

    func testCountingCancelingOperation() async throws {
        let exp = expectation(description: #function)
        let input = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

        let counter = Counter(numbers: input, delay: delay)
        counter.start()

        // wrap in task so for loop does not block the next section
        Task {
            for await progress in await counter.status {
                print("Progress: \(String(format: "%.2f", progress.fractionCompleted))")
                if progress.fractionCompleted > 0.25 {
                    counter.cancel()
                }
            }
        }

        var thrown: Error? = nil

        do {
            let output = try await counter.value
            print("Output: \(output)")
            XCTFail("Output should not be sent")
            exp.fulfill()
        } catch {
            thrown = error
            exp.fulfill()
        }

        wait(for: [exp], timeout: delay * Double(input.count) + 1.0)

        XCTAssertNotNil(thrown)
        guard let error = thrown else {
            XCTFail("Error should be thrown")
            return
        }
        XCTAssertTrue(error is CancellationError)
    }

    func testCountingCancelingTask() async throws {
        let exp = expectation(description: #function)

        let input = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

        let counter = Counter(numbers: input, delay: delay) { index in
            index > 2
        }
        counter.start()

        // wrap in task so for loop does not block the next section
        Task {
            for await progress in await counter.status {
                print("Progress: \(String(format: "%.2f", progress.fractionCompleted))")
            }
        }

        Task {
            var thrown: Error? = nil
            do {
                let output = try await counter.value
                print("Output: \(output)")
                XCTFail("Output should not be sent")
                exp.fulfill()
            } catch {
                thrown = error
                exp.fulfill()
            }

            XCTAssertNotNil(thrown)
            guard let error = thrown else {
                XCTFail("Error should be thrown")
                return
            }
            XCTAssertTrue(error is CancellationError)
        }

        wait(for: [exp], timeout: delay * Double(input.count) + 1.0)
    }

    func testAsyncValueNotCanceled() async throws {
        var thrown: Error? = nil
        let input = 42

        do {
            let numberProvider = NumberProvider(number: input, delay: delay, shouldCancelTask: false)
            let output = try await numberProvider.value
            print("Number: \(output)")
            XCTAssertEqual(input, output)
        } catch {
            thrown = error
        }

        XCTAssertNil(thrown)
    }

    func testAsyncValueCanceled() async throws {
        var thrown: Error? = nil
        let input = 13

        do {
            let numberProvider = NumberProvider(number: input, delay: delay, shouldCancelTask: true)
            let output = try await numberProvider.value
            print("Number: \(output)")
            XCTFail("Should not return value")
        } catch {
            thrown = error
        }

        XCTAssertNotNil(thrown)
        guard let error = thrown else {
            XCTFail("Error should be thrown")
            return
        }
        XCTAssertTrue(error is CancellationError)
    }
}

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

struct Worker {
    func work() {
        let double: (Int) async throws -> Int = { value in
            try await Task.sleep(seconds: 1.0)
            return value * 2
        }
        Task {
            let result = try await double(2)
            print("Result: \(result)")
        }
    }
}
