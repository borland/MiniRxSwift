//
//  MiniRxSwift
//
//  Copyright © 2021 Orion Edwards. Licensed under the MIT License
//  https://opensource.org/licenses/MIT
//

import Foundation
import XCTest
@testable import MiniRxSwift

class TimeoutTests : XCTestCase {
    let sched = MockScheduler(now: Date())
    
    func test_timesOut() {
        let src = PublishSubject<Int>()
        
        let results = RefArray<Evt<Int>>()
        _ = src.timeout(.seconds(3), scheduler: sched).subscribe(into: results)
        
        sched.advanceBy(.milliseconds(2999))
        XCTAssertEqual([], results.array)
        
        sched.advanceBy(.milliseconds(1))
        XCTAssertEqual([.error(MiniRxError.timeout), .disposed], results.array)
    }
    
    func test_noTimeoutIfOnNext() {
        let src = PublishSubject<Int>()
        
        let results = RefArray<Evt<Int>>()
        _ = src.timeout(.seconds(3), scheduler: sched).subscribe(into: results)
        
        sched.advanceBy(.milliseconds(2999))
        XCTAssertEqual([], results.array)
        
        src.onNext(1)
        XCTAssertEqual([.next(1)], results.array)

        sched.advanceBy(.milliseconds(20)) // time has been exceeded, but we don't fail because onNext happened
        XCTAssertEqual([.next(1)], results.array)
        
        src.onNext(2)
        XCTAssertEqual([.next(1), .next(2)], results.array)
        
        src.onCompleted()
        XCTAssertEqual([.next(1), .next(2), .completed, .disposed], results.array)
        
        src.onNext(99) // sanity check for values-after-finished
        XCTAssertEqual([.next(1), .next(2), .completed, .disposed], results.array)
    }
    
    func test_propagatesErrors() {
        let src = PublishSubject<Int>()
        
        let results = RefArray<Evt<Int>>()
        _ = src.timeout(.seconds(3), scheduler: sched).subscribe(into: results)
        
        sched.advanceBy(.milliseconds(2999))
        XCTAssertEqual([], results.array)
        
        src.onError(MockError("fish"))
        XCTAssertEqual([.error(MockError("fish")), .disposed], results.array)
        
        sched.advanceBy(.milliseconds(20)) // time has been exceeded, but we don't fail because we already failed
        src.onNext(99) // sanity check for values-after-finished
        XCTAssertEqual([.error(MockError("fish")), .disposed], results.array)
    }
    
    func test_propagatesEmptyCompletion() {
        let src = PublishSubject<Int>()
        
        let results = RefArray<Evt<Int>>()
        _ = src.timeout(.seconds(3), scheduler: sched).subscribe(into: results)
        
        sched.advanceBy(.milliseconds(2999))
        XCTAssertEqual([], results.array)
        
        src.onCompleted()
        XCTAssertEqual([.completed, .disposed], results.array)
        
        sched.advanceBy(.milliseconds(20)) // time has been exceeded, but we don't fail because we already completed
        src.onNext(99) // sanity check for values-after-finished
        XCTAssertEqual([.completed, .disposed], results.array)
    }
    
    func test_noValueAfterTimeout() {
        let src = PublishSubject<Int>()
        
        let results = RefArray<Evt<Int>>()
        _ = src.timeout(.seconds(3), scheduler: sched).subscribe(into: results)
        
        sched.advanceBy(.milliseconds(2999))
        XCTAssertEqual([], results.array)
        
        sched.advanceBy(.milliseconds(1))
        XCTAssertEqual([.error(MiniRxError.timeout), .disposed], results.array)
        
        src.onNext(99) // sanity check for values-after-finished
        src.onCompleted()
        XCTAssertEqual([.error(MiniRxError.timeout), .disposed], results.array)
    }
    
    func test_noErrorAfterCancelled() {
        let src = PublishSubject<Int>()
        
        let results = RefArray<Evt<Int>>()
        let d = src.timeout(.seconds(3), scheduler: sched).subscribe(into: results)
        
        sched.advanceBy(.milliseconds(2999))
        XCTAssertEqual([], results.array)
        d.dispose()
        
        sched.advanceBy(.milliseconds(1))
        XCTAssertEqual([.disposed], results.array)
        
        src.onNext(99) // sanity check for values-after-finished
        src.onCompleted()
        XCTAssertEqual([.disposed], results.array)
    }
}
