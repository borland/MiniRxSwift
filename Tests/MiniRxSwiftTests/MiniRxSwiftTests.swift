import XCTest
@testable import MiniRxSwift

final class MiniRxSwiftTests: XCTestCase {
    func testAllTheThings() {
        var captured = "<not captured>"
        var done = false
        
        _ = Observable.from([1,2,3,4,5])
            .flatMap { i in
                Observable.just(value: i * 10)
            }
            .filter { i in i > 29 }
            .map { i in "\(i)" }
            .reduce("") { (result, s) in
                if result.isEmpty {
                    return s
                } else {
                    return result + ",\(s)"
                }
            }.subscribe(
                onNext: { s in captured = s },
                onError: { err in fatalError() },
                onCompleted: { done = true })
        
        XCTAssertEqual(true, done)
        XCTAssertEqual("30,40,50", captured)
    }

    static var allTests = [
        ("testAllTheThings", testAllTheThings),
    ]
}
