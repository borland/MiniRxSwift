//
//  MiniRxSwift
//
//  Copyright © 2021 Adric Lloyd. Licensed under the MIT License
//  https://opensource.org/licenses/MIT
//

import Foundation
import XCTest
@testable import MiniRxSwift

class FirstTests: XCTestCase {
    func test_first_simpleArray() {
        let src = Observable.from([1,2,3])
        
        let results = RefArray<Evt<Int?>>()
        
        _ = src.first().subscribe(into: results)
        
        XCTAssertEqual([.next(1), .completed, .disposed], results.array)
    }
    
    func test_first_singleValueArray() {
        let src = Observable.from([3])
        
        let results = RefArray<Evt<Int?>>()
        
        _ = src.first().subscribe(into: results)
        
        XCTAssertEqual([.next(3), .completed, .disposed], results.array)
    }
    
    func test_first_emptyArray() {
        let src = Observable<Int>.empty()
        
        let results = RefArray<Evt<Int?>>()
        
        _ = src.first().subscribe(into: results)
        
        XCTAssertEqual([.next(nil), .completed, .disposed], results.array)
    }
    
    func test_firstOrDefault_simpleArray() {
        let src = Observable.from([1,2,3])
        
        let results = RefArray<Evt<Int>>()
        
        _ = src.firstOrDefault(0).subscribe(into: results)
        
        XCTAssertEqual([.next(1), .completed, .disposed], results.array)
    }
    
    func test_firstOrDefault_singleValueArray() {
        let src = Observable.from([3])
        
        let results = RefArray<Evt<Int>>()
        
        _ = src.firstOrDefault(0).subscribe(into: results)
        
        XCTAssertEqual([.next(3), .completed, .disposed], results.array)
    }
    
    func test_firstOrDefault_emptyArray() {
        let src = Observable<Int>.empty()
        
        let results = RefArray<Evt<Int>>()
        
        _ = src.firstOrDefault(0).subscribe(into: results)
        
        XCTAssertEqual([.next(0), .completed, .disposed], results.array)
    }
}
