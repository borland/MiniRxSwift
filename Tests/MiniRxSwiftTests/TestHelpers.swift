//
//         Copyright Gallagher Group Ltd 2021 All Rights Reserved
//             THIS IS UNPUBLISHED PROPRIETARY SOURCE CODE OF
//                Gallagher Group Research and Development
//                          Hamilton, New Zealand
    

import Foundation
@testable import MiniRxSwift

class MockError : Error, CustomStringConvertible, Equatable {
    let message: String
    
    init(_ message: String) {
        self.message = message
    }
    
    var description: String {
        "MockError:\(message)"
    }

    static func == (lhs: MockError, rhs: MockError) -> Bool {
        lhs.message == rhs.message
    }
}

// RxSwift.Event isn't equatable and doesn't have an entry for disposed, but this is very similar
enum Evt<Element> : Equatable, CustomStringConvertible where Element : Equatable {
    static func == (lhs: Evt<Element>, rhs: Evt<Element>) -> Bool {
        switch (lhs, rhs) {
        case (.completed, .completed),
             (.disposed, .disposed):
            return true
        case (.next(let lel), .next(let rel)):
            return lel == rel
        case (.error(let lerr), .error(let rerr)):
            return "\(lerr)" == "\(rerr)"
        default:
            return false
        }
    }
    
    case next(Element)
    case error(Error)
    case completed
    case disposed
    
    var description: String {
        switch self {
        case .next(let e): return "next(\(e))"
        case .error(let e): return "error(\(e))"
        case .completed: return "completed"
        case .disposed: return "disposed"
        }
    }
}

class RefArray<TElement> {
    var array: [TElement] = []
}

extension ObservableType {
    
    // subscribes to the observable, writing a record of what happened into the ArrayReference.
    // we'd like to pass an actual array, but it's a value type and thus swift won't let us
    // capture an inout reference to it in our onNext and other closures
    func subscribe<T>(into: RefArray<Evt<T>>) -> Disposable where T == Element {
        return self.subscribe(
            onNext:{ i in
                into.array.append(.next(i))
            }, onError: { (err) in
                into.array.append(.error(err))
            }, onCompleted: {
                into.array.append(.completed)
            }, onDisposed: {
                into.array.append(.disposed)
            })
    }
}
