//
//  RavenTests.swift
//  RavenTests
//
//  Created by Ahsan Minhas on 28/05/2026.
//

import XCTest
@testable import Raven

final class RavenTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
        // XCTest Documentation
        // https://developer.apple.com/documentation/xctest
    }

    func testChapterInfosReturnsEmptyWhenFewerThanTwoMarkers() {
        let groups = [
            (start: 0.0, end: 120.0, title: Optional("Intro"))
        ]

        let chapters = EmbeddedChapterScanner.chapterInfos(
            from: groups,
            assetDuration: 120,
            fallbackTitle: "Book"
        )

        XCTAssertTrue(chapters.isEmpty)
    }

    func testChapterInfosSplitsEmbeddedMarkersIntoChapters() {
        let groups = [
            (start: 0.0, end: 100.0, title: Optional("Chapter 1")),
            (start: 100.0, end: 250.0, title: Optional("Chapter 2")),
            (start: 250.0, end: .infinity, title: Optional("Chapter 3"))
        ]

        let chapters = EmbeddedChapterScanner.chapterInfos(
            from: groups,
            assetDuration: 400,
            fallbackTitle: "Book"
        )

        XCTAssertEqual(chapters.count, 3)
        XCTAssertEqual(chapters[0].title, "Chapter 1")
        XCTAssertEqual(chapters[0].startTime, 0, accuracy: 0.001)
        XCTAssertEqual(chapters[0].duration, 100, accuracy: 0.001)
        XCTAssertEqual(chapters[1].startTime, 100, accuracy: 0.001)
        XCTAssertEqual(chapters[1].duration, 150, accuracy: 0.001)
        XCTAssertEqual(chapters[2].startTime, 250, accuracy: 0.001)
        XCTAssertEqual(chapters[2].duration, 150, accuracy: 0.001)
    }

    func testChapterInfosUsesNextMarkerStartWhenEndIsMissing() {
        let groups = [
            (start: 0.0, end: 0.0, title: Optional("Part 1")),
            (start: 90.0, end: 0.0, title: Optional("Part 2"))
        ]

        let chapters = EmbeddedChapterScanner.chapterInfos(
            from: groups,
            assetDuration: 200,
            fallbackTitle: "Book"
        )

        XCTAssertEqual(chapters.count, 2)
        XCTAssertEqual(chapters[0].duration, 90, accuracy: 0.001)
        XCTAssertEqual(chapters[1].duration, 110, accuracy: 0.001)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
