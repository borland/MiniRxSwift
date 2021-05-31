//
//  MiniRxSwift
//
//  Copyright © 2021 Orion Edwards. Licensed under the MIT License
//  https://opensource.org/licenses/MIT
//

import Foundation
import XCTest
@testable import MiniRxSwift

class ReduceTests : XCTestCase {
    func testReduceAddsNumbers() {
        let src = Observable.from([1,2,3,4,5,6,7])
        
        let results = RefArray<Evt<Int>>()
        
        _ = src.reduce(0) { acc, value in
            acc + value
        }.subscribe(into: results)
        
        XCTAssertEqual([.next(28), .completed, .disposed], results.array)
    }
    
    func testReduceAddsNumbers_differentSeed() {
        let src = Observable.from([1,2,3,4,5,6,7])
        
        let results = RefArray<Evt<Int>>()
        
        _ = src.reduce(100) { acc, value in
            acc + value
        }.subscribe(into: results)
        
        XCTAssertEqual([.next(128), .completed, .disposed], results.array)
    }
    
    func testReduceIntoDifferentType() {
        let src = Observable.from([1,2,3,4,5,6,7])
        
        let results = RefArray<Evt<String>>()
        
        _ = src.reduce("") { acc, value in
            acc + "\(value)"
        }.subscribe(into: results)
        
        XCTAssertEqual([.next("1234567"), .completed, .disposed], results.array)
    }
    
    func testReduceMergesThingsIntoMap() {
        let src: Observable<Int> = .from([1,2,3])
        
        let results = RefArray<Evt<[Int:String]>>()

        _ = src.reduce([:]) { (acc:[Int:String], value:Int) -> [Int:String] in
            return acc.merging([value: "\(value)"], uniquingKeysWith: { a,b in a })
        }.subscribe(into: results)
        
        XCTAssertEqual([.next([
            1: "1",
            2: "2",
            3: "3",
        ]), .completed, .disposed], results.array)
    }
    
    func testReduceOutputsSeedIfEmpty() {
        let src:Observable<Int> = .empty()
        let results = RefArray<Evt<Int>>()
        _ = src.reduce(0) { acc, value in acc + value }.subscribe(into: results)
        XCTAssertEqual([.next(0), .completed, .disposed], results.array)
    }
    
    func testReduceOutputsSeedIfEmptyTypeChange() {
        let src:Observable<Int> = .empty()
        let results = RefArray<Evt<String>>()
        _ = src.reduce("x") { acc, value in acc + "\(value)" }.subscribe(into: results)
        XCTAssertEqual([.next("x"), .completed, .disposed], results.array)
    }
    
    func testReduceOutputsSeedIfEmpty_Map() {
        let src:Observable<Int> = .empty()
        let results = RefArray<Evt<[Int:String]>>()
        _ = src.reduce([:]) { acc, value in acc.merging([value: "\(value)"], uniquingKeysWith: { a,b in a }) }.subscribe(into: results)
        XCTAssertEqual([.next([:]), .completed, .disposed], results.array)
    }
    
    func testOutputAfterCompleted() {
        let src:Observable<Int> = .create { observer in
            observer.onNext(1)
            observer.onNext(2)
            observer.onCompleted()
            observer.onNext(100)
            return Disposables.create()
        }
        
        let results = RefArray<Evt<Int>>()
        _ = src.reduce(0) { acc, value in acc + value }.subscribe(into: results)
        XCTAssertEqual([.next(3), .completed, .disposed], results.array)
    }
    
    func testOutputAfterError() {
        let src:Observable<Int> = .create { observer in
            observer.onNext(1)
            observer.onNext(2)
            observer.onError(MockError("banana"))
            observer.onNext(100)
            return Disposables.create()
        }
        
        let results = RefArray<Evt<Int>>()
        _ = src.reduce(0) { acc, value in acc + value }.subscribe(into: results)
        XCTAssertEqual([.error(MockError("banana")), .disposed], results.array)
    }
}
