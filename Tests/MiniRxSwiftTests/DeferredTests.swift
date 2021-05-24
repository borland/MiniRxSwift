//
//  MiniRxSwift
//
//  Copyright © 2021 Orion Edwards. Licensed under the MIT License
//  https://opensource.org/licenses/MIT
//

import Foundation
import XCTest
@testable import MiniRxSwift

class DeferredTests : XCTestCase {
    func test_observableDeferred_doesNotRunUntilSubscribe() {
        var trace = [String]()
        let results = RefArray<Evt<Int>>()
        
        let subject = Observable<Int>.deferred {
            trace.append("subscribe")
            return Observable.just(12)
        }
        
        XCTAssertEqual([], trace)
        XCTAssertEqual([], results.array)
        
        _ = subject.subscribe(into: results)
        
        XCTAssertEqual(["subscribe"], trace)
        XCTAssertEqual([.next(12), .completed, .disposed], results.array)
    }
    
    func test_observableDeferred_runsBlockForEachSubscription() {
        var trace = [String]()
        
        var counter = 1
        let subject = Observable<Int>.deferred {
            trace.append("subscribe\(counter)")
            counter += 1
            return Observable.just(12)
        }
        
        _ = subject.subscribe()
        _ = subject.subscribe()
        _ = subject.subscribe()
        
        XCTAssertEqual(["subscribe1", "subscribe2", "subscribe3"], trace)
    }
    
    func test_observableDeferred_doesNotRunUntilSubscribe_complex() {
        var trace = [String]()
        let results = RefArray<Evt<Int>>()
        let results2 = RefArray<Evt<Int>>()
        
        let innerSubject = PublishSubject<Int>()
        let subject = Observable<Int>.deferred {
            trace.append("subscribe")
            return innerSubject
        }
        
        XCTAssertEqual([], trace)
        innerSubject.onNext(12) // this gets missed because we haven't subscribed the deferred yet
        XCTAssertEqual([], results.array)
        
        _ = subject.subscribe(into: results)
        _ = subject.subscribe(into: results2)
        
        XCTAssertEqual(["subscribe", "subscribe"], trace)
        XCTAssertEqual([], results.array)
        
        // both deferreds wrapt he same innerSubject, so they should see the same output
        innerSubject.onNext(12)
        innerSubject.onNext(13)
        
        XCTAssertEqual([.next(12), .next(13)], results.array)
        XCTAssertEqual([.next(12), .next(13)], results2.array)
    }
}
