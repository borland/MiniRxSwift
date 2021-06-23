//
//  MiniRxSwift
//
//  Copyright © 2021 Adric Lloyd. Licensed under the MIT License
//  https://opensource.org/licenses/MIT
//

import Foundation
import XCTest
@testable import MiniRxSwift

class LastTests: XCTestCase {
    func test_last_simpleArray() {
        let src = Observable.from([1,2,3])
        
        let results = RefArray<Evt<Int?>>()
        
        _ = src.last().subscribe(into: results)
        
        XCTAssertEqual([.next(3), .completed, .disposed], results.array)
    }
    
    func test_last_singleValueArray() {
        let src = Observable.from([3])
        
        let results = RefArray<Evt<Int?>>()
        
        _ = src.last().subscribe(into: results)
        
        XCTAssertEqual([.next(3), .completed, .disposed], results.array)
    }
    
    func test_last_emptyArray() {
        let src = Observable<Int>.empty()
        
        let results = RefArray<Evt<Int?>>()
        
        _ = src.last().subscribe(into: results)
        
        XCTAssertEqual([.next(nil), .completed, .disposed], results.array)
    }
    
    func test_lastOrDefault_simpleArray() {
        let src = Observable.from([1,2,3])
        
        let results = RefArray<Evt<Int>>()
        
        _ = src.lastOrDefault(0).subscribe(into: results)
        
        XCTAssertEqual([.next(3), .completed, .disposed], results.array)
    }
    
    func test_lastOrDefault_singleValueArray() {
        let src = Observable.from([3])
        
        let results = RefArray<Evt<Int>>()
        
        _ = src.lastOrDefault(0).subscribe(into: results)
        
        XCTAssertEqual([.next(3), .completed, .disposed], results.array)
    }
    
    func test_lastOrDefault_emptyArray() {
        let src = Observable<Int>.empty()
        
        let results = RefArray<Evt<Int>>()
        
        _ = src.lastOrDefault(0).subscribe(into: results)
        
        XCTAssertEqual([.next(0), .completed, .disposed], results.array)
    }
}
