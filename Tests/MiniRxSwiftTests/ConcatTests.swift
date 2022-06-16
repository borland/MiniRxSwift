//
//  MiniRxSwift
//
//  Copyright © 2021 Orion Edwards. Licensed under the MIT License
//  https://opensource.org/licenses/MIT
//

import Foundation
import XCTest
@testable import MiniRxSwift

// Note: as at 16-06-2022 all these exact literal tests ran against "real" RxSwift and produce exactly the same output
class ConcatTests: XCTestCase {
    func test_concat() {
        let r = RefArray<Evt<String>>()
        
        let o = Observable.from(["1","3","5","7"])
        let e = Observable.from(["2","4","6"])
        
        let _ = Observable.concat(o,e).subscribe(into: r)
        
        XCTAssertEqual(r.array, [.next("1"),.next("3"),.next("5"),.next("7"),.next("2"),.next("4"),.next("6"),.completed, .disposed])
    }
    
    func test_concatTrampolining() {
        // this tests the order of operations in a single-threaded scenario
        let r = RefArray<Evt<String>>()
        var hits = [String]()
        
        hits.append("begin")
        let o = Observable<String>.create { observer in
            hits.append("o-start")
            
            observer.onNext("o")
            observer.onCompleted()
            hits.append("o-afterCompleted")
            
            return Disposables.create {
                hits.append("o-dispose")
            }
        }
        let e = Observable<String>.create { observer in
            hits.append("e-start")
            
            observer.onNext("e")
            observer.onCompleted()
            hits.append("e-afterCompleted")
            
            return Disposables.create {
                hits.append("e-dispose")
            }
        }
        hits.append("begin2")
        
        let _ = Observable.concat(o,e).subscribe(into: r)
        hits.append("end")
        
        XCTAssertEqual(hits, ["begin", "begin2", "o-start", "o-afterCompleted", "o-dispose", "e-start", "e-afterCompleted", "e-dispose", "end"])
        XCTAssertEqual(r.array, [.next("o"),.next("e"),.completed, .disposed])
    }
    
    func test_simpleAsyncConcat() {
        let r = RefArray<Evt<String>>()
        
        let subjectO = PublishSubject<String>()
        let subjectE = PublishSubject<String>()
        
        let _ = Observable.concat(subjectO, subjectE).subscribe(into: r)
        
        subjectO.onNext("1")
        subjectO.onCompleted()
        subjectE.onNext("3")
        subjectE.onCompleted()
        
        XCTAssertEqual(r.array, [.next("1"),.next("3"),.completed, .disposed])
    }
    
    func test_secondSourceWontEmitUntilFirstCompletes() {
        let r = RefArray<Evt<String>>()
        
        let subjectO = PublishSubject<String>()
        let subjectE = PublishSubject<String>()
        
        let _ = Observable.concat(subjectO, subjectE).subscribe(into: r)
        
        subjectO.onNext("1")
        subjectE.onNext("5")
        subjectO.onCompleted()
        subjectE.onNext("3")
        subjectE.onCompleted()
        
        XCTAssertEqual(r.array, [.next("1"),.next("3"),.completed, .disposed])
    }
    
    func test_concatObservableJusts() {
        let r = RefArray<Evt<String>>()
        
        let o = Observable.just("1")
        let e = Observable.just("2")
        
        let _ = Observable.concat(o,e).subscribe(into: r)
        
        XCTAssertEqual(r.array, [.next("1"),.next("2"),.completed, .disposed])
    }
    func test_concatInnerSleepOneAsyncCreate() {
        let r = RefArray<Evt<String>>()
        
        let firstExpectation = self.expectation(description: "first operation completed")
        let secondExpectation = self.expectation(description: "second operation completed")
        
        let o = Observable<String>.create { observer in
                observer.onNext("1")
                observer.onCompleted()
               firstExpectation.fulfill()
            
            return Disposables.create {
                observer.onError(MockError("Apple"))
            }
        }
        
        let e = Observable<String>.create { observer in
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(5)) {
                observer.onNext("2")
                observer.onCompleted()
               secondExpectation.fulfill()
            }
            
            return Disposables.create {
                observer.onError(MockError("Banana"))
            }
        }
        let _ = Observable.concat(o,e).subscribe(into: r)
        
        self.waitForExpectations(timeout: 15.0, handler: nil)
        
        XCTAssertEqual(r.array, [.next("1"),.next("2"),.completed, .disposed])
    }
    
    func test_concatInnerSleepTwoAsyncCreates() {
        let r = RefArray<Evt<String>>()
        
        let firstExpectation = self.expectation(description: "operation completed")
        let secondExpectation = self.expectation(description: "operation completed")
        
        let o = Observable<String>.create { observer in
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(0)) {
                observer.onNext("1")
                observer.onCompleted()
               firstExpectation.fulfill()
            }
            
            return Disposables.create {
                observer.onError(MockError("Apple"))
            }
        }
        
        let e = Observable<String>.create { observer in
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(5)) {
                observer.onNext("2")
                observer.onCompleted()
               secondExpectation.fulfill()
            }
            
            return Disposables.create {
                observer.onError(MockError("Banana"))
            }
        }
        
        let _ = Observable.concat(o,e).subscribe(into: r)
        
        self.waitForExpectations(timeout: 15.0, handler: nil)
        
        XCTAssertEqual(r.array, [.next("1"),.next("2"),.completed, .disposed])
    }
    
    func test_concatInnerSleepTwoFirstIsJust() {
        let r = RefArray<Evt<String>>()
        
        let completionExpectation = self.expectation(description: "operation completed")
        
        let o = Observable.just("1")
        
        let e = Observable<String>.create { observer in
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(1)) {
                observer.onNext("2")
                observer.onCompleted()
                completionExpectation.fulfill()
            }
            
            return Disposables.create {
                observer.onError(MockError("Banana"))
            }
        }
        
        let _ = Observable.concat(o,e).subscribe(into: r)
        
        self.waitForExpectations(timeout: 15.0, handler: nil)
        
        XCTAssertEqual(r.array, [.next("1"),.next("2"),.completed, .disposed])
    }
    
    func test_concatInnerSleepTwoFirstIsFrom() {
        let r = RefArray<Evt<String>>()
        
        let completionExpectation = self.expectation(description: "operation completed")
        
        let o = Observable.from(["1"])
        
        let e = Observable<String>.create { observer in
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(1)) {
                observer.onNext("2")
                observer.onCompleted()
                completionExpectation.fulfill()
            }
            
            return Disposables.create {
                observer.onError(MockError("Banana"))
            }
        }
        
        let _ = Observable.concat([o,e]).subscribe(into: r)
        
        self.waitForExpectations(timeout: 15.0, handler: nil)
        
        XCTAssertEqual(r.array, [.next("1"),.next("2"),.completed, .disposed])
    }
    
    func test_concatInnerSleepTwoFirstIsDeferred() {
        let r = RefArray<Evt<String>>()
        
        let completionExpectation = self.expectation(description: "operation completed")
        
        let o = Observable.deferred { () -> Observable<String> in
            return Observable.just("1")
        }
        
        let e = Observable<String>.create { observer in
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(1)) {
                observer.onNext("2")
                observer.onCompleted()
                completionExpectation.fulfill()
            }
            
            return Disposables.create {
                observer.onError(MockError("Banana"))
            }
        }
        
        let _ = Observable.concat(o,e).subscribe(into: r)
        
        self.waitForExpectations(timeout: 15.0, handler: nil)
        
        XCTAssertEqual(r.array, [.next("1"),.next("2"),.completed, .disposed])
    }
    
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
