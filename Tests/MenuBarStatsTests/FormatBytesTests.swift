import XCTest
@testable import MenuBarStats

final class FormatBytesTests: XCTestCase {

    // MARK: - formatBytes

    func testBytes() {
        XCTAssertEqual(formatBytes(0),    "0.0 B")
        XCTAssertEqual(formatBytes(512),  "512.0 B")
        XCTAssertEqual(formatBytes(1023), "1023.0 B")
    }

    func testKilobytes() {
        XCTAssertEqual(formatBytes(1024),       "1.0 KB")
        XCTAssertEqual(formatBytes(2048),       "2.0 KB")
        XCTAssertEqual(formatBytes(1536),       "1.5 KB")
        XCTAssertEqual(formatBytes(1024 * 1023), "1023.0 KB")
    }

    func testMegabytes() {
        XCTAssertEqual(formatBytes(1024 * 1024),       "1.0 MB")
        XCTAssertEqual(formatBytes(1024 * 1024 * 512), "512.0 MB")
    }

    func testGigabytes() {
        XCTAssertEqual(formatBytes(1024 * 1024 * 1024), "1.0 GB")
    }

    func testTerabytes() {
        XCTAssertEqual(formatBytes(1024 * 1024 * 1024 * 1024), "1.0 TB")
    }

    func testDecimalsParameter() {
        XCTAssertEqual(formatBytes(1536, decimals: 0), "2 KB")
        XCTAssertEqual(formatBytes(1536, decimals: 2), "1.50 KB")
    }

    func testNegativeBytes() {
        // Negative input: stays in bytes, no unit promotion
        XCTAssertEqual(formatBytes(-512), "-512.0 B")
    }

    // MARK: - formatThroughput

    func testThroughputAppendsSuffix() {
        XCTAssertEqual(formatThroughput(1024), "1.0 KB/s")
        XCTAssertEqual(formatThroughput(0),    "0.0 B/s")
    }
}
