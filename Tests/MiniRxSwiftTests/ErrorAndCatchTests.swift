//
//  MiniRxSwift
//
//  Copyright © 2021 Orion Edwards. Licensed under the MIT License
//  https://opensource.org/licenses/MIT
//

import Foundation
import XCTest
@testable import MiniRxSwift

class ErrorTests : XCTestCase {
    func test_observableError_producesError() {
        let e = Observable<Int>.error(MockError("foo"))
        
        let results = RefArray<Evt<Int>>()
        _ = e.subscribe(into: results)
        
        XCTAssertEqual([.error(MockError("foo")), .disposed], results.array)
    }
}

class Catchtests : XCTestCase {
    func testContinuesOntoSecondObservableAfterError() {
        let s1 = PublishSubject<Int>()
        let s2 = PublishSubject<Int>()
        
        var trace = [String]()
        let results = RefArray<Evt<Int>>()
        
        _ = s1.catch({ e in
            trace.append("catch:\(e)")
            return s2
        }).subscribe(into: results)
        
        s1.onNext(12)
        s1.onError(MockError("banana"))
        s1.onNext(13) // should get missed
        
        s2.onNext(22)
        s2.onCompleted()
        
        XCTAssertEqual(["catch:MockError:banana"], trace)
        XCTAssertEqual([.next(12), .next(22), .completed, .disposed], results.array)
    }
    
    func testIgnoresSecondObservableUntilFailure() {
        let s1 = PublishSubject<Int>()
        let s2 = PublishSubject<Int>()
        
        var trace = [String]()
        let results = RefArray<Evt<Int>>()
        
        _ = s1.catch({ e in
            trace.append("catch:\(e)")
            return s2
        }).subscribe(into: results)
        
        s2.onNext(99)
        
        s1.onNext(12)
        s1.onError(MockError("banana"))
        s2.onNext(22)
        
        XCTAssertEqual(["catch:MockError:banana"], trace)
        XCTAssertEqual([.next(12), .next(22)], results.array)
    }
    
    func testPropagatesSecondFailure() {
        let s1 = PublishSubject<Int>()
        let s2 = PublishSubject<Int>()
        
        var trace = [String]()
        let results = RefArray<Evt<Int>>()
        
        _ = s1.catch({ e in
            trace.append("catch:\(e)")
            return s2
        }).subscribe(into: results)
        
        s1.onNext(12)
        s1.onError(MockError("banana"))
        s2.onNext(22)
        s2.onError(MockError("fish"))
        
        XCTAssertEqual(["catch:MockError:banana"], trace)
        XCTAssertEqual([.next(12), .next(22), .error(MockError("fish")), .disposed], results.array)
    }
    
    func testStopsAfterFirstCompletion() {
        let s1 = PublishSubject<Int>()
        let s2 = PublishSubject<Int>()
        
        var trace = [String]()
        let results = RefArray<Evt<Int>>()
        
        _ = s1.catch({ e in
            trace.append("catch:\(e)")
            return s2
        }).subscribe(into: results)
        
        s1.onNext(12)
        s1.onCompleted()
        
        // nobody is listening to these
        s1.onError(MockError("banana"))
        s2.onNext(22)
        s2.onError(MockError("fish"))
        
        XCTAssertEqual([], trace)
        XCTAssertEqual([.next(12), .completed, .disposed], results.array)
    }
}
