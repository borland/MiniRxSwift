import XCTest
@testable import MiniRxSwift

final class MiniRxSwiftTests: XCTestCase {
    func testAllTheThings() {
        var lastSideEffect: String? = nil
        
        var captured = "<not captured>"
        var done = false
        
        _ = Observable.from([1,2,3,4,5])
            .flatMap { i in
                Observable.from([i * 10, i * 10 + 1])
            }
            .filter { i in
                i > 29
            }
            .map { i in
                "$\(i)"
            }
            .do(onNext: { s in
                lastSideEffect = s
            })
            .reduce("") { (result, s) in
                if result.isEmpty {
                    return "\(s ?? "null")"
                } else {
                    return result + ",\(s ?? "null")"
                }
            }.subscribe(
                onNext: { s in captured = s },
                onError: { err in fatalError() },
                onCompleted: { done = true })
        
        XCTAssertEqual(true, done)
        XCTAssertEqual("$30,$31,$40,$41,$50,$51", captured)
        XCTAssertEqual("$51", lastSideEffect)
    }

    static var allTests = [
        ("testAllTheThings", testAllTheThings),
    ]
    
    func test_observableCreateWontAllowErrorAfterComplete() {
        let observable: Observable<Int> = Observable.create { observer in
            observer.onCompleted()
            observer.onError(NSError())
            
            return Disposables.create()
        }
        
        _ = observable.subscribe(
            onNext: { _ in },
            onError: { _ in
                // shouldn't error after onComplete is hit
                XCTFail()
            },
            onCompleted: {})
    }
}
