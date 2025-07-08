import XCTest

class BasicTest: XCTestCase {
    func testBasicAssertion() {
        XCTAssertTrue(true)
    }
    
    func testBasicEquality() {
        XCTAssertEqual(1 + 1, 2)
    }
}