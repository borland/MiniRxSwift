//
//  MiniRxSwift
//
//  Copyright © 2021 Orion Edwards. Licensed under the MIT License
//  https://opensource.org/licenses/MIT
//

import Foundation
import XCTest
@testable import MiniRxSwift

class FlatMapTests : XCTestCase {
    func test_flatMap_chainsNextTogether() {
        let r = RefArray<Evt<Int>>()
        
        _ = Observable.deferred {
            Observable.just(12)
        }.flatMap { i in
            Observable.just(i * 2) //24
        }.subscribe(into: r)
        
        XCTAssertEqual([.next(24), .completed, .disposed], r.array)
    }
    
    func test_flatMap_chainsNextTogether_multiple() {
        let r = RefArray<Evt<Int>>()
        
        _ = Observable.deferred {
            Observable.just(12)
        }.flatMap { i in
            Observable.just(i * 2) //24
        }.flatMap { i in
            Observable.just(i * 2) //48
        }.flatMap { i in
            Observable.just(i * 2)
        }.subscribe(into: r)
        
        XCTAssertEqual([.next(96), .completed, .disposed], r.array)
    }
    
    func test_flatMap_chainsNextTogether_arrayBehaviour() {
        let r = RefArray<Evt<Int>>()
        
        _ = Observable.deferred {
            Observable.just(12)
        }.flatMap { i in
            return Observable.create { observer in
                observer.onNext(i)
                observer.onNext(i * 2) // 24
                observer.onNext(i * 3) // 36
                observer.onCompleted()
                return Disposables.create()
            }
        }.subscribe(into: r)
        
        XCTAssertEqual([.next(12), .next(24), .next(36), .completed, .disposed], r.array)
    }
    
    func test_flatMap_chainsNextTogether_stopOnError() {
        let r = RefArray<Evt<Int>>()
        
        _ = Observable.deferred {
            Observable.just(12)
        }.flatMap { i in
            return Observable.create { observer in
                observer.onNext(i)
                observer.onError(MockError("fish"))
                return Disposables.create()
            }
        }.subscribe(into: r)
        
        XCTAssertEqual([.next(12), .error(MockError("fish")), .disposed], r.array)
    }
    
    func test_flatMap_chainStopsAfterFailure() {
        let r = RefArray<Evt<Int>>()
        
        _ = Observable.deferred {
            Observable.error(MockError("banana"))
        }.flatMap { (i:Int) in
            Observable.just(99)
        }.subscribe(into: r)
        
        XCTAssertEqual([.error(MockError("banana")), .disposed], r.array)
    }
    
    func test_flatMap_chainStopsAfterFailure_throwing() {
        let r = RefArray<Evt<Int>>()
        
        _ = Observable.deferred {
            Observable.just(12)
        }.flatMap { (i:Int) -> Observable<Int> in
            throw MockError("banana")
        }.subscribe(into: r)
        
        XCTAssertEqual([.error(MockError("banana")), .disposed], r.array)
    }
    
    func test_flatMap_chainStopsAfterFailureInsideFlatMap() {
        let r = RefArray<Evt<Int>>()
        
        _ = Observable.deferred {
            Observable.just(12)
        }.flatMap { (i:Int) in
            Observable.create { observer in
                observer.onNext(i) // 12
                observer.onError(MockError("banana"))
                observer.onNext(99) // flatmap should drop and we should ignore this value
                observer.onCompleted()
                return Disposables.create()
            }
        }
        .flatMap { (i:Int) in
            Observable.just(i * 2) // 24
        }.subscribe(into: r)
        
        XCTAssertEqual([.next(24), .error(MockError("banana")), .disposed], r.array)
    }
}
