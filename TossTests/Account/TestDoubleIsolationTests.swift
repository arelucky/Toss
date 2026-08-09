import XCTest
@testable import Toss

final class TestDoubleIsolationTests: XCTestCase {
    func testStartedSignalIsDeliveredAfterSuspensionIsInstalled() async {
        let gate = TestOperationGate()
        let operation = Task { await gate.suspend() }

        await gate.waitUntilStarted()

        XCTAssertTrue(gate.hasInstalledSuspension)
        gate.complete()
        await operation.value
        XCTAssertFalse(gate.hasInstalledSuspension)
    }

    func testCompletionBeforeSuspensionIsRetained() async {
        let gate = TestOperationGate()

        gate.complete()
        await gate.suspend()

        XCTAssertFalse(gate.hasInstalledSuspension)
        XCTAssertTrue(gate.isCompleted)
    }

    func testAccountDoubleExposesOneLockedStateSnapshot() {
        let double = AccountAuthServiceDouble()

        let snapshot = double.snapshot

        XCTAssertEqual(snapshot.restoreCallCount, 0)
        XCTAssertEqual(snapshot.signInCallCount, 0)
        XCTAssertEqual(snapshot.signOutCallCount, 0)
        XCTAssertEqual(snapshot.activeObservationCount, 0)
        XCTAssertEqual(snapshot.observationCreationCount, 0)
        XCTAssertTrue(snapshot.operationLog.isEmpty)
    }

    func testExplicitTeardownReleasesSuspendedOperation() async {
        let gate = TestOperationGate()
        let operation = Task { await gate.suspend() }
        await gate.waitUntilStarted()

        gate.tearDown()
        await operation.value

        XCTAssertFalse(gate.hasInstalledSuspension)
    }
}
