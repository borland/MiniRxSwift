//
//  MiniRxSwift
//
//  Copyright © 2021 Orion Edwards. Licensed under the MIT License
//  https://opensource.org/licenses/MIT
//

import Foundation
import XCTest
@testable import MiniRxSwift

class BehaviorSubjectTests : XCTestCase {
    
    func testSubscriberSeesInitialValue() {
        let captured = RefArray<Evt<Int>>()
        
        let s = BehaviorSubject(value: 12)
        _ = s.subscribe(into: captured)
        
        XCTAssertEqual([.next(12)], captured.array)
    }
    
    func testSubscriberSeesSubsequentValuesUntilCompletion() {
        let captured = RefArray<Evt<Int>>()
        
        let s = BehaviorSubject(value: 12)
        _ = s.subscribe(into: captured)
        
        s.onNext(13)
        s.onNext(14)
        s.onCompleted()
        s.onNext(15)
        
        XCTAssertEqual([.next(12), .next(13), .next(14), .completed, .disposed], captured.array)
    }
    
    func testSubscriberSeesSubsequentValuesUntilDisposed() {
        let captured = RefArray<Evt<Int>>()
        
        let s = BehaviorSubject(value: 12)
        let d = s.subscribe(into: captured)
        
        s.onNext(13)
        s.onNext(14)
        d.dispose()
        s.onCompleted()
        s.onNext(15)
        
        XCTAssertEqual([.next(12), .next(13), .next(14), .disposed], captured.array)
    }
}
