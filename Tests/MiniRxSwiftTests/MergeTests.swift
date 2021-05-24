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
