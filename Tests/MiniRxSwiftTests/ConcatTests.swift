//
//  MiniRxSwift
//
//  Copyright © 2021 Orion Edwards. Licensed under the MIT License
//  https://opensource.org/licenses/MIT
//

import Foundation
import XCTest
@testable import MiniRxSwift

class ConcatTests: XCTestCase {
    func test_concat() {
        let r = RefArray<Evt<String>>()
        
        let o = Observable.from(["1","3","5","7"])
        let e = Observable.from(["2","4","6"])
        
        let _ = Observable.concat(o,e).subscribe(into: r)
        
        XCTAssertEqual(r.array, [.next("1"),.next("3"),.next("5"),.next("7"),.next("2"),.next("4"),.next("6"),.completed, .disposed])
    }
    
    func test_simpleAsyncConcat() {
        let r = RefArray<Evt<String>>()
        
        let subjectO = PublishSubject<String>()
        let subjectE = PublishSubject<String>()
        
        let _ = Observable.concat(subjectO, subjectE).subscribe(into: r)
        
        subjectO.onNext("1")
        subjectO.onCompleted()
        subjectE.onNext("3")
        subjectE.onCompleted()
        
        XCTAssertEqual(r.array, [.next("1"),.next("3"),.completed, .disposed])
    }
    
    func test_secondSourceWontEmitUntilFirstCompletes() {
        let r = RefArray<Evt<String>>()
        
        let subjectO = PublishSubject<String>()
        let subjectE = PublishSubject<String>()
        
        let _ = Observable.concat(subjectO, subjectE).subscribe(into: r)
        
        subjectO.onNext("1")
        subjectE.onNext("5")
        subjectO.onCompleted()
        subjectE.onNext("3")
        subjectE.onCompleted()
        
        XCTAssertEqual(r.array, [.next("1"),.next("3"),.completed, .disposed])
    }
    
    func test_concatObservableJusts() {
        let r = RefArray<Evt<String>>()
        
        let o = Observable.just("1")
        let e = Observable.just("2")
        
        let _ = Observable.concat(o,e).subscribe(into: r)
        
        XCTAssertEqual(r.array, [.next("1"),.next("2"),.completed, .disposed])
    }
}
