//
//  MiniRxSwift
//
//  Copyright © 2021 Orion Edwards. Licensed under the MIT License
//  https://opensource.org/licenses/MIT
//

import Foundation
import XCTest
@testable import MiniRxSwift

class MergeTests : XCTestCase {
    func testMergeWorksNormally() {
        let r = RefArray<Evt<Int>>()
        
        _ = Observable.merge(
            Observable.just(12),
            Observable.just(13),
            Observable.just(14))
        .subscribe(into: r)
        
        XCTAssertEqual([.next(12), .next(13), .next(14), .completed, .disposed], r.array)
    }
    
    func testMergeCompletesAfterAllComplete() {
        let r = RefArray<Evt<Int>>()
        
        let s1 = PublishSubject<Int>()
        let s2 = PublishSubject<Int>()
        let s3 = PublishSubject<Int>()
        
        _ = Observable.merge(s1, s2, s3).subscribe(into: r)
        
        s1.onNext(3)
        s2.onNext(4)
        s3.onNext(5)
        
        s2.onCompleted()
        s2.onNext(99) // should be ignored
        
        s1.onNext(13)
        s1.onCompleted()
        s1.onNext(99) // should be ignored
        
        s3.onNext(53)
        s3.onCompleted()
        s3.onNext(99) // should be ignored
        
        XCTAssertEqual([.next(3), .next(4), .next(5), .next(13), .next(53), .completed, .disposed], r.array)
    }
    
    func testMergeCompletesImmediatelyForZeroSources() {
        let r = RefArray<Evt<Int>>()
        
        _ = Observable.merge([]).subscribe(into: r)
        
        XCTAssertEqual([.completed, .disposed], r.array)
    }
    
    func testMergeCompletesAfterAllComplete_Empty() {
        let r = RefArray<Evt<Int>>()
        
        let s1 = PublishSubject<Int>()
        let s2 = PublishSubject<Int>()
        let s3 = PublishSubject<Int>()
        
        _ = Observable.merge(s1, s2, s3).subscribe(into: r)
        
        s2.onCompleted()
        s2.onNext(99) // should be ignored
        
        s1.onCompleted()
        s1.onNext(99) // should be ignored
        
        s3.onCompleted()
        s3.onNext(99) // should be ignored
        
        XCTAssertEqual([.completed, .disposed], r.array)
    }
    
    func testStopsWhenSourcesStop() {
        let s1 = PublishSubject<Int>()
        let s2 = PublishSubject<Int>()
        
        let r = RefArray<Evt<Int>>()
        
        _ = Observable.merge(s1, s2).subscribe(into: r)
        XCTAssertEqual([], r.array)
        
        s1.onNext(1)
        s2.onNext(100)
        s2.onNext(103)
        s1.onNext(3)
        
        XCTAssertEqual([.next(1), .next(100), .next(103), .next(3)], r.array)
        
        s2.onCompleted()
        XCTAssertEqual([.next(1), .next(100), .next(103), .next(3)], r.array)
        
        s1.onCompleted()
        XCTAssertEqual([.next(1), .next(100), .next(103), .next(3), .completed, .disposed], r.array)
    }
    
    func testStopsOnFirstError() {
        let s1 = PublishSubject<Int>()
        let s2 = PublishSubject<Int>()
        
        let r = RefArray<Evt<Int>>()
        
        _ = Observable.merge(s1, s2).subscribe(into: r)
        XCTAssertEqual([], r.array)
        
        s1.onNext(1)
        s2.onError(MockError("fish"))
        s2.onNext(103)
        s1.onNext(3)
        
        XCTAssertEqual([.next(1), .error(MockError("fish")), .disposed], r.array)
        
        s2.onCompleted()
        XCTAssertEqual([.next(1), .error(MockError("fish")), .disposed], r.array)
        
        s1.onCompleted()
        XCTAssertEqual([.next(1), .error(MockError("fish")), .disposed], r.array)
    }
}
