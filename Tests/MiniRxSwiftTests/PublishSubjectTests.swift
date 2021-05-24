//
//  MiniRxSwift
//
//  Copyright © 2021 Orion Edwards. Licensed under the MIT License
//  https://opensource.org/licenses/MIT
//

import Foundation
import XCTest
@testable import MiniRxSwift

// PublishSubject is the foundation for lots of other things, so these
// tests are more important than most others
class PublishSubjectTests : XCTestCase {
    
    func testSubscriberSeesValues() {
        let captured = RefArray<Evt<Int>>()
        
        let s = PublishSubject<Int>()
        _ = s.subscribe(into: captured)
        
        XCTAssertEqual([], captured.array)
        
        s.onNext(12)
        XCTAssertEqual([.next(12)], captured.array)
    }
    
    func testSubscriberSeesValuesUntilCompleted() {
        let captured = RefArray<Evt<Int>>()
        
        let s = PublishSubject<Int>()
        _ = s.subscribe(into: captured)
        
        s.onNext(14)
        s.onCompleted()
        s.onNext(15) // they shouldn't see this one
        
        XCTAssertEqual([.next(14), .completed, .disposed], captured.array)
    }
    
    func testSubscriberSeesValuesUntilFailed() {
        let captured = RefArray<Evt<Int>>()
        
        let s = PublishSubject<Int>()
        _ = s.subscribe(into: captured)
        
        s.onNext(14)
        s.onError(MockError("fish"))
        s.onNext(15) // they shouldn't see this one
        
        XCTAssertEqual([.next(14), .error(MockError("fish")), .disposed], captured.array)
    }
    
    func testSubscriberSeesValuesUntilDisposed() {
        let captured = RefArray<Evt<Int>>()
        
        let s = PublishSubject<Int>()
        let disposable = s.subscribe(into: captured)
        
        s.onNext(14)
        disposable.dispose()
        s.onNext(15) // they shouldn't see this one
        
        XCTAssertEqual([.next(14), .disposed], captured.array)
    }
    
    func testSharesValuesUntilDisposed() {
        let captured1 = RefArray<Evt<Int>>()
        let captured2 = RefArray<Evt<Int>>()
        
        let s = PublishSubject<Int>()
        
        let disposable1 = s.subscribe(into: captured1)
        s.onNext(14)
        
        let disposable2 = s.subscribe(into: captured2)
        s.onNext(15)
        disposable1.dispose()
        
        s.onNext(16)
        disposable2.dispose()
        
        s.onNext(17)
        
        XCTAssertEqual([.next(14), .next(15), .disposed], captured1.array)
        XCTAssertEqual([.next(15), .next(16), .disposed], captured2.array)
    }
}
