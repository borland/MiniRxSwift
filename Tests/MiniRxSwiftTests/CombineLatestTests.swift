//
//  MiniRxSwift
//
//  Copyright © 2021 Orion Edwards. Licensed under the MIT License
//  https://opensource.org/licenses/MIT
//

import Foundation
import XCTest
@testable import MiniRxSwift

class CombineLatestTests : XCTestCase {
    func testCombineLatest_standard() {
        let s1 = PublishSubject<Int>()
        let s2 = PublishSubject<Int>()
        
        let results = RefArray<Evt<String>>()
        
        _ = Observable<String>.combineLatest(s1, s2) { a, b in "\(a),\(b)" }.subscribe(into: results)
        XCTAssertEqual([], results.array)
        
        s1.onNext(1)
        XCTAssertEqual([], results.array)
        
        s2.onNext(100)
        XCTAssertEqual([.next("1,100")], results.array)
        
        s2.onNext(101)
        XCTAssertEqual([.next("1,100"), .next("1,101")], results.array)
        
        s2.onNext(102)
        XCTAssertEqual([.next("1,100"), .next("1,101"), .next("1,102")], results.array)
        
        s1.onNext(2)
        XCTAssertEqual([.next("1,100"), .next("1,101"), .next("1,102"), .next("2,102")], results.array)
    }
    
    func testCombineLatest_afterCompleted_immediate() {
        let s1 = PublishSubject<Int>()
        let s2 = PublishSubject<Int>()
        
        let results = RefArray<Evt<String>>()
        
        _ = Observable<String>.combineLatest(s1, s2) { a, b in "\(a),\(b)" }.subscribe(into: results)
        XCTAssertEqual([], results.array)
        
        s1.onNext(1)
        s1.onCompleted() // s1 is done!
        
        XCTAssertEqual([], results.array)
        
        s2.onNext(100) // s2 keeps going with the remembered value from s1
        XCTAssertEqual([.next("1,100")], results.array)
        
        s2.onNext(101)
        XCTAssertEqual([.next("1,100"), .next("1,101")], results.array)
    }
    
    func testCombineLatest_afterCompleted_longer() {
        let s1 = PublishSubject<Int>()
        let s2 = PublishSubject<Int>()
        
        let results = RefArray<Evt<String>>()
        
        _ = Observable<String>.combineLatest(s1, s2) { a, b in "\(a),\(b)" }.subscribe(into: results)
        XCTAssertEqual([], results.array)
        
        s1.onNext(1)
        XCTAssertEqual([], results.array)
        
        s2.onNext(100)
        XCTAssertEqual([.next("1,100")], results.array)
        
        s2.onCompleted()
        XCTAssertEqual([.next("1,100")], results.array)
        
        s2.onNext(101) // 101 from s2 should be ignored as s2 is completed
        XCTAssertEqual([.next("1,100")], results.array)
        
        s1.onNext(2) // s1 keeps going, remembering the last value that s2 emitted before it stopped
        XCTAssertEqual([.next("1,100"), .next("2,100")], results.array)
    }
    
    func testCombineLatest_afterCompleted_both() {
        let s1 = PublishSubject<Int>()
        let s2 = PublishSubject<Int>()
        
        let results = RefArray<Evt<String>>()
        
        _ = Observable<String>.combineLatest(s1, s2) { a, b in "\(a),\(b)" }.subscribe(into: results)
        XCTAssertEqual([], results.array)
        
        s1.onNext(1)
        XCTAssertEqual([], results.array)
        
        s2.onNext(100)
        XCTAssertEqual([.next("1,100")], results.array)
        
        s2.onCompleted()
        XCTAssertEqual([.next("1,100")], results.array)
        
        s2.onNext(101) // 101 from s2 should be ignored as s2 is completed
        XCTAssertEqual([.next("1,100")], results.array)
        
        s1.onNext(2) // s1 keeps going, remembering the last value that s2 emitted before it stopped
        XCTAssertEqual([.next("1,100"), .next("2,100")], results.array)
        
        s1.onCompleted()
        XCTAssertEqual([.next("1,100"), .next("2,100"), .completed, .disposed], results.array)
    }
    
    func testCombineLatest_afterError_immediate() {
        let s1 = PublishSubject<Int>()
        let s2 = PublishSubject<Int>()
        
        let results = RefArray<Evt<String>>()
        
        _ = Observable<String>.combineLatest(s1, s2) { a, b in "\(a),\(b)" }.subscribe(into: results)
        XCTAssertEqual([], results.array)
        
        s1.onNext(1)
        s1.onError(MockError("broken")) // s1 is done!
        
        XCTAssertEqual([.error(MockError("broken")), .disposed], results.array)
    }
    
    func testCombineLatest_afterError_later() {
        let s1 = PublishSubject<Int>()
        let s2 = PublishSubject<Int>()
        
        let results = RefArray<Evt<String>>()
        
        _ = Observable<String>.combineLatest(s1, s2) { a, b in "\(a),\(b)" }.subscribe(into: results)
        XCTAssertEqual([], results.array)
        
        s1.onNext(1)
        s2.onNext(100)
        
        XCTAssertEqual([.next("1,100")], results.array)
        
        s1.onError(MockError("broken"))
        
        XCTAssertEqual([.next("1,100"), .error(MockError("broken")), .disposed], results.array)
        
        // subsequent emissions get dropped
        s1.onNext(2)
        s2.onNext(101)
        
        XCTAssertEqual([.next("1,100"), .error(MockError("broken")), .disposed], results.array)
    }
    
    // as above but s2 experiences the error rather than s1
    func testCombineLatest_afterError_later_2() {
        let s1 = PublishSubject<Int>()
        let s2 = PublishSubject<Int>()
        
        let results = RefArray<Evt<String>>()
        
        _ = Observable<String>.combineLatest(s1, s2) { a, b in "\(a),\(b)" }.subscribe(into: results)
        XCTAssertEqual([], results.array)
        
        s1.onNext(1)
        s2.onNext(100)
        
        XCTAssertEqual([.next("1,100")], results.array)
        
        s2.onError(MockError("broken"))
        
        XCTAssertEqual([.next("1,100"), .error(MockError("broken")), .disposed], results.array)
        
        // subsequent emissions get dropped
        s1.onNext(2)
        s2.onNext(101)
        
        XCTAssertEqual([.next("1,100"), .error(MockError("broken")), .disposed], results.array)
    }
}
