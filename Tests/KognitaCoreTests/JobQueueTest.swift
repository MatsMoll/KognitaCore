import KognitaCore
import XCTest
import Vapor

class JobQueueTest: VaporTestCase {

    func testScheduleJob() throws {
        let jobQueue = try app.make(JobQueueable.self)
        let startDate = Date.now
        var endDate: Date?
        let hasRanExpectation = XCTestExpectation()

        jobQueue.scheduleFutureJob(after: .seconds(1)) { (_, conn) -> EventLoopFuture<Void> in
            endDate = Date.now
            hasRanExpectation.fulfill()
            return conn.future()
        }
        XCTAssertNil(endDate)
        wait(for: [hasRanExpectation], timeout: .seconds(2))
        let completedDate = try XCTUnwrap(endDate)
        let duration = completedDate.timeIntervalSince(startDate)
        XCTAssertTrue(duration < 1.1 && duration > 0.9, "Duration between is: \(duration)")
    }
}
