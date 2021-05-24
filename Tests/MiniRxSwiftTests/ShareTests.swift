//
//  MiniRxSwift
//
//  Copyright © 2021 Orion Edwards. Licensed under the MIT License
//  https://opensource.org/licenses/MIT
//

import Foundation
import XCTest
@testable import MiniRxSwift

class ShareTests : XCTestCase {
    func testShareSendsValueToTwoSubscribers() {
        let s1 = PublishSubject<Int>();
        
        let shared = s1.share()
        
        let r1 = RefArray<Evt<Int>>()
        let r2 = RefArray<Evt<Int>>()
        
        _ = shared.subscribe(into: r1)
        _ = shared.subscribe(into: r2)
        
        XCTAssertEqual([], r1.array)
        XCTAssertEqual([], r2.array)
        
        s1.onNext(12)
        
        XCTAssertEqual([.next(12)], r1.array)
        XCTAssertEqual([.next(12)], r2.array)
        
        s1.onCompleted()
        
        XCTAssertEqual([.next(12), .completed, .disposed], r1.array)
        XCTAssertEqual([.next(12), .completed, .disposed], r2.array)
    }
    
    func testShareOnlySubscribesOnceToSource() {
        let s1 = PublishSubject<Int>();
        var trace = [String]()
        
        let shared = Observable.create { (observer:AnyObserver<Int>) -> Disposable in
            trace.append("subscribed")
            return s1.subscribe(observer)
        }.share()
        
        let r1 = RefArray<Evt<Int>>()
        let r2 = RefArray<Evt<Int>>()
        
        _ = shared.subscribe(into: r1)
        _ = shared.subscribe(into: r2)
        
        XCTAssertEqual(["subscribed"], trace)
        
        XCTAssertEqual([], r1.array)
        XCTAssertEqual([], r2.array)
        
        s1.onNext(12)
        
        XCTAssertEqual([.next(12)], r1.array)
        XCTAssertEqual([.next(12)], r2.array)
        
        s1.onCompleted()
        
        XCTAssertEqual([.next(12), .completed, .disposed], r1.array)
        XCTAssertEqual([.next(12), .completed, .disposed], r2.array)
    }
    
    func testShareReleasesSourceSubscriptionWhenAllRelease() {
        let source = PublishSubject<Int>();
        
        let shared = source.share()
        
        let r1 = RefArray<Evt<Int>>()
        let r2 = RefArray<Evt<Int>>()
        
        let d1 = shared.subscribe(into: r1)
        let d2 = shared.subscribe(into: r2)
        
        XCTAssert(source.hasObservers)
        XCTAssertEqual([], r1.array)
        XCTAssertEqual([], r2.array)
        
        source.onNext(12)
        
        XCTAssertEqual([.next(12)], r1.array)
        XCTAssertEqual([.next(12)], r2.array)
        
        d1.dispose()
        XCTAssertEqual([.next(12), .disposed], r1.array)
        
        source.onNext(13)
        
        XCTAssert(source.hasObservers)
        XCTAssertEqual([.next(12), .disposed], r1.array)
        XCTAssertEqual([.next(12), .next(13)], r2.array)
        
        d2.dispose()
        
        XCTAssertFalse(source.hasObservers)
        
        XCTAssertEqual([.next(12), .disposed], r1.array)
        XCTAssertEqual([.next(12), .next(13), .disposed], r2.array)
    }
    
    func testShareReleasesSourceSubscriptionAfterError() {
        let source = PublishSubject<Int>();
        
        let shared = source.share()
        
        let r1 = RefArray<Evt<Int>>()
        let r2 = RefArray<Evt<Int>>()
        
        _ = shared.subscribe(into: r1)
        _ = shared.subscribe(into: r2)
        
        XCTAssert(source.hasObservers)
        XCTAssertEqual([], r1.array)
        XCTAssertEqual([], r2.array)
        
        source.onNext(12)
        XCTAssertEqual([.next(12)], r1.array)
        XCTAssertEqual([.next(12)], r2.array)
        
        source.onError(MockError("fish"))
        
        XCTAssertFalse(source.hasObservers)
        XCTAssertEqual([.next(12), .error(MockError("fish")), .disposed], r1.array)
        XCTAssertEqual([.next(12), .error(MockError("fish")), .disposed], r2.array)
    }
}
