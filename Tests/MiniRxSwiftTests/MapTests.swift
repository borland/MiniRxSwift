//
//  MiniRxSwift
//
//  Copyright © 2021 Orion Edwards. Licensed under the MIT License
//  https://opensource.org/licenses/MIT
//

import Foundation
import XCTest
@testable import MiniRxSwift

class MapTests : XCTestCase {
    func testMapDoesSimpleTransform() {
        let src = Observable.from([1,2,3,4])
        
        let results = RefArray<Evt<Int>>()
        
        _ = src.map{ value in value + 10 }.subscribe(into: results)
        
        XCTAssertEqual([.next(11),.next(12),.next(13),.next(14), .completed, .disposed], results.array)
    }
    
    func testMapCatchesErrors() {
        let src = Observable.from([1,2,3,4])
        
        let results = RefArray<Evt<Int>>()
        
        _ = src.map{ value in
            if value > 2 {
                throw MockError("fish")
            }
            return value + 10
        }.subscribe(into: results)
        
        XCTAssertEqual([.next(11), .next(12), .error(MockError("fish")), .disposed], results.array)
    }
    
    func testMapDoesNotEmitAfterCompletion() {
        let src: Observable<Int> = .create { observer in
            observer.onNext(1)
            observer.onNext(2)
            observer.onCompleted()
            observer.onNext(100)
            return Disposables.create()
        }
        
        let results = RefArray<Evt<Int>>()
        
        _ = src.map{ value in value + 10 }.subscribe(into: results)
        
        XCTAssertEqual([.next(11),.next(12), .completed, .disposed], results.array)
    }
    
    func testMapDoesNotEmitAfterError() {
        let src: Observable<Int> = .create { observer in
            observer.onNext(1)
            observer.onNext(2)
            observer.onError(MockError("fish"))
            observer.onNext(100)
            return Disposables.create()
        }
        
        let results = RefArray<Evt<Int>>()
        
        _ = src.map{ value in value + 10 }.subscribe(into: results)
        
        XCTAssertEqual([.next(11),.next(12), .error(MockError("fish")), .disposed], results.array)
    }
}
