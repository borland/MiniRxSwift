//
//  MiniRxSwift
//
//  Copyright © 2021 Orion Edwards. Licensed under the MIT License
//  https://opensource.org/licenses/MIT
//

import Foundation
import XCTest
@testable import MiniRxSwift

class DoTests : XCTestCase {
    func testSideEffectsOnNext() {
        let src = Observable.from([1,2,3])
        
        var sideEffects:[Int] = []
        let results = RefArray<Evt<Int>>()
        
        _ = src.do { value in
            sideEffects.append(value)
        }.subscribe(into: results)
        
        XCTAssertEqual([.next(1),.next(2),.next(3), .completed, .disposed], results.array)
        XCTAssertEqual([1,2,3], sideEffects)
    }
    
    func testSideEffectsDontChangeReturnValue() {
        let src = Observable.from([1,2,3])
        
        var sideEffects:[String] = []
        let results = RefArray<Evt<Int>>()
        
        _ = src.do { value in
            sideEffects.append("\(value)")
        }.subscribe(into: results)
        
        XCTAssertEqual([.next(1),.next(2),.next(3), .completed, .disposed], results.array)
        XCTAssertEqual(["1","2","3"], sideEffects)
    }
        
    func testSideEffectsOnEverything() {
        let src = Observable.from([1,2])
        
        var sideEffects:[String] = []
        let results = RefArray<Evt<Int>>()
        
        _ = src.do { value in
            sideEffects.append("next:\(value)")
        } onError: { error in
            sideEffects.append("error:\(error)")
        } onCompleted: {
            sideEffects.append("completed")
        } onDispose: {
            sideEffects.append("dispose")
        }
        .subscribe(into: results)
        
        XCTAssertEqual([.next(1),.next(2), .completed, .disposed], results.array)
        XCTAssertEqual(["next:1","next:2", "completed", "dispose"], sideEffects)
    }
    
    func testSideEffectsOnError_andAfter() {
        let src: Observable<Int> = .create { observer in
            observer.onNext(1)
            observer.onError(MockError("fish"))
            observer.onNext(99)
            return Disposables.create()
        }
        
        var sideEffects:[String] = []
        let results = RefArray<Evt<Int>>()
        
        _ = src.do { value in
            sideEffects.append("next:\(value)")
        } onError: { error in
            sideEffects.append("error:\(error)")
        } onCompleted: {
            sideEffects.append("completed")
        } onDispose: {
            sideEffects.append("dispose")
        }
        .subscribe(into: results)
        
        XCTAssertEqual([.next(1), .error(MockError("fish")), .disposed], results.array)
        XCTAssertEqual(["next:1","error:MockError:fish", "dispose"], sideEffects)
    }
    
    func testSideEffectThrowsOnNext() {
        let src = Observable.from([1,2,3])
        
        var sideEffects:[String] = []
        let results = RefArray<Evt<Int>>()
        
        _ = src.do { value in
            if value == 2 {
                throw MockError("abort")
            }
            sideEffects.append("\(value)")
        }.subscribe(into: results)
        
        XCTAssertEqual([.next(1), .error(MockError("abort")), .disposed], results.array)
        XCTAssertEqual(["1"], sideEffects)
    }
    
    func testSideEffectThrowsOnCompleted() {
        let src: Observable<Int> = .create { observer in
            observer.onNext(1)
            observer.onNext(2)
            observer.onCompleted()
            observer.onNext(99)
            return Disposables.create()
        }
        
        var sideEffects:[String] = []
        let results = RefArray<Evt<Int>>()
        
        _ = src.do { value in
            sideEffects.append("\(value)")
        } onCompleted: {
            sideEffects.append("completed")
            throw MockError("abortCompleted")
        }.subscribe(into: results)
        
        XCTAssertEqual([.next(1), .next(2), .error(MockError("abortCompleted")), .disposed], results.array)
        XCTAssertEqual(["1", "2", "completed"], sideEffects)
    }
    
    func testSideEffectThrowsOnError() {
        let src: Observable<Int> = .create { observer in
            observer.onNext(1)
            observer.onError(MockError("primary"))
            observer.onNext(99)
            return Disposables.create()
        }
        
        var sideEffects:[String] = []
        let results = RefArray<Evt<Int>>()
        
        _ = src.do { value in
            sideEffects.append("\(value)")
        } onError: { error in
            sideEffects.append("error:\(error)")
            throw MockError("secondary")
        }.subscribe(into: results)
        
        XCTAssertEqual([.next(1), .error(MockError("secondary")), .disposed], results.array)
        XCTAssertEqual(["1", "error:MockError:primary"], sideEffects)
    }
}
