//
//         Copyright Gallagher Group Ltd 2021 All Rights Reserved
//             THIS IS UNPUBLISHED PROPRIETARY SOURCE CODE OF
//                Gallagher Group Research and Development
//                          Hamilton, New Zealand
    

import Foundation
import XCTest
@testable import MiniRxSwift

class SerialDisposableTests: XCTestCase {
    func test_serialDisposableDisposes() throws {
        let serialDisposable = SerialDisposable()
        
        let publishSubject = PublishSubject<Int>()
        
        serialDisposable.disposable = publishSubject.subscribe(onNext: { _ in
            XCTFail()
        }, onError: { _ in }
        ,onCompleted: {})
        
        serialDisposable.disposable = Disposables.create()
        publishSubject.onNext(1)
    }
    
    func test_serialDisposableCanBeReplaced() {
        let serialDisposable = SerialDisposable()
        
        let publishSubjectOne = PublishSubject<Int>()
        let publishSubjectTwo = PublishSubject<Int>()
        
        let r = RefArray<Evt<Int>>()
        
        serialDisposable.disposable = publishSubjectOne.subscribe(into: r)
        
        publishSubjectOne.onNext(1)
        publishSubjectTwo.onNext(2) // should be ignored
        
        serialDisposable.disposable = publishSubjectTwo.subscribe(into: r)
        
        publishSubjectOne.onError(NSError())
        
        publishSubjectOne.onNext(3) // should be ignored
        publishSubjectTwo.onNext(4)
        
        publishSubjectTwo.onCompleted()
        
        XCTAssertEqual(r.array, [.next(1), .disposed, .next(4), .completed, .disposed])
    }
    
    func test_serialDisposableCanBeReplacedAfterError() {
        let serialDisposable = SerialDisposable()
        
        let publishSubjectOne = PublishSubject<Int>()
        let publishSubjectTwo = PublishSubject<Int>()
        
        let r = RefArray<Evt<Int>>()
        
        serialDisposable.disposable = publishSubjectOne.subscribe(into: r)
        
        publishSubjectOne.onNext(1)
        publishSubjectTwo.onNext(2) // should be ignored
        
        publishSubjectOne.onError(MockError(""))
        
        serialDisposable.disposable = publishSubjectTwo.subscribe(into: r)
        
        publishSubjectOne.onNext(3) // should be ignored
        publishSubjectTwo.onNext(4)
        
        publishSubjectTwo.onCompleted()
        
        XCTAssertEqual(r.array, [.next(1), .error(MockError("")), .disposed, .next(4), .completed, .disposed])
    }
    
    func test_serialDisposableCanBeReplacedAfterComplete() {
        let serialDisposable = SerialDisposable()
        
        let publishSubjectOne = PublishSubject<Int>()
        let publishSubjectTwo = PublishSubject<Int>()
        
        let r = RefArray<Evt<Int>>()
        
        serialDisposable.disposable = publishSubjectOne.subscribe(into: r)
        
        publishSubjectOne.onNext(1)
        publishSubjectTwo.onNext(2) // should be ignored
        
        publishSubjectOne.onCompleted()
            
        serialDisposable.disposable = publishSubjectTwo.subscribe(into: r)
        
        publishSubjectOne.onNext(3) // should be ignored
        publishSubjectTwo.onNext(4)
        
        publishSubjectTwo.onCompleted()
        
        XCTAssertEqual(r.array, [.next(1), .completed, .disposed, .next(4), .completed, .disposed])
    }
}
