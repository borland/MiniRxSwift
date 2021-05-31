//
//  MiniRxSwift
//
//  Copyright © 2021 Orion Edwards. Licensed under the MIT License
//  https://opensource.org/licenses/MIT
//

import Foundation
import XCTest
@testable import MiniRxSwift

class ToArrayTests : XCTestCase {
    // note rxSwift toArray returns a single, so we need an additional "asObservable" to get back to sensibility. MiniRx doesn't have this
    
    func testSimple() {
        let src: Observable<Int> = .create { observer in
            observer.onNext(1)
            observer.onNext(2)
            observer.onNext(3)
            observer.onCompleted()
            return Disposables.create()
        }
        
        let results = RefArray<Evt<[Int]>>()
        
        _ = src.toArray().subscribe(into: results)
        
        XCTAssertEqual([.next([1,2,3]), .completed, .disposed], results.array)
    }
    
    func testNextAfterComplete() {
        let src: Observable<Int> = .create { observer in
            observer.onNext(1)
            observer.onNext(2)
            observer.onCompleted()
            observer.onNext(99)
            return Disposables.create()
        }
        
        let results = RefArray<Evt<[Int]>>()
        
        _ = src.toArray().subscribe(into: results)
        
        XCTAssertEqual([.next([1,2]), .completed, .disposed], results.array)
    }
    
    func testNextAfterError() {
        let src: Observable<Int> = .create { observer in
            observer.onNext(1)
            observer.onNext(2)
            observer.onError(MockError("fish"))
            observer.onNext(99)
            return Disposables.create()
        }
        
        let results = RefArray<Evt<[Int]>>()
        
        _ = src.toArray().subscribe(into: results)
        
        // we get no results at all
        XCTAssertEqual([.error(MockError("fish")), .disposed], results.array)
    }
}
