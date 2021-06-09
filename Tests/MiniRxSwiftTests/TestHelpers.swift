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

// mock scheduler

class ScheduledAction {
    let id: Int
    let action: ()->Void
    var dueTime: DispatchTimeInterval
    
    init(id:Int, dueTime:DispatchTimeInterval, action: @escaping ()->Void) {
        self.id = id
        self.dueTime = dueTime
        self.action = action
    }
}

open class MockScheduler : SchedulerType {
    var idCounter : Int = 0
    var scheduledActions = [ScheduledAction]()
    
    init(now: Date) {
        self.now = now
    }
    
    // MARK: - SchedulerType
    
    open var now: Date // settable
    
    open func schedule<StateType>(_ state: StateType, action: @escaping (StateType) -> Disposable) -> Disposable {
        return action(state)
    }

    open func scheduleRelative<StateType>(_ state: StateType, dueTime: DispatchTimeInterval, action: @escaping (StateType) -> Disposable) -> Disposable {
        idCounter += 1
        let id = idCounter
        
        let disposable = SerialDisposable()
        disposable.disposable = Disposables.create {
            if let idx = self.scheduledActions.firstIndex(where: { sa in sa.id == id }) {
                self.scheduledActions.remove(at: idx)
            }
        }
        
        let insertionIndex = scheduledActions.firstIndex{ sa in sa.dueTime > dueTime } ?? scheduledActions.count
        
        scheduledActions.insert(
            ScheduledAction(id: id, dueTime: dueTime, action: {
                disposable.disposable = action(state)
            }),
            at: insertionIndex)
        
        return disposable
    }

    // MARK: - Mock Support
    
    open func advanceBy(_ interval: DispatchTimeInterval) {
        for action in scheduledActions {
            action.dueTime -= interval
            
            if action.dueTime <= .milliseconds(0) {
                action.action()
                // calling the action will
                // trigger onComplete on RxSwift's internal wrapper object, which will call dispose
                // which will call our AnonymousDisposable (added by scheduleRelative)
                // which will remove the ScheduledAction object from our array
                // SO... we don't need to worry about that
            }
        }
        
        now = now.addingTimeInterval(interval.toTimeInterval()!)
    }
}

extension DispatchTimeInterval : Comparable {
    public static func < (lhs: DispatchTimeInterval, rhs: DispatchTimeInterval) -> Bool {
        switch (lhs, rhs) {
        case (.seconds(let s1), .seconds(let s2)): return s1 < s2
        case (.seconds(let s1), .milliseconds(let s2)): return s1 * 1000 < s2
        case (.seconds(let s1), .microseconds(let s2)): return s1 * 1000000 < s2
        case (.seconds(let s1), .nanoseconds(let s2)): return s1 * 1000000000 < s2
            
        case (.milliseconds(let s1), .seconds(let s2)): return s1 < s2 * 1000
        case (.milliseconds(let s1), .milliseconds(let s2)): return s1 < s2
        case (.milliseconds(let s1), .microseconds(let s2)): return s1 * 1000 < s2
        case (.milliseconds(let s1), .nanoseconds(let s2)): return s1 * 1000000 < s2
            
        case (.microseconds(let s1), .seconds(let s2)): return s1 < s2 * 1000000
        case (.microseconds(let s1), .milliseconds(let s2)): return s1 < s2 * 1000
        case (.microseconds(let s1), .microseconds(let s2)): return s1 < s2
        case (.microseconds(let s1), .nanoseconds(let s2)): return s1 * 1000 < s2
            
        case (.nanoseconds(let s1), .seconds(let s2)): return s1 < s2 * 1000000000
        case (.nanoseconds(let s1), .milliseconds(let s2)): return s1 < s2 * 1000000
        case (.nanoseconds(let s1), .microseconds(let s2)): return s1 < s2 * 1000
        case (.nanoseconds(let s1), .nanoseconds(let s2)): return s1 < s2
        
        case (.never, _), (_, .never): return false // never is poisonous
        @unknown default: fatalError("unhandled case \(lhs) \(rhs)")
        }
    }
    
    public static func * (lhs: DispatchTimeInterval, rhs: Int) -> DispatchTimeInterval {
        switch lhs {
        case .seconds(let s): return .seconds(s * rhs)
        case .milliseconds(let s): return .milliseconds(s * rhs)
        case .microseconds(let s): return .microseconds(s * rhs)
        case .nanoseconds(let s): return .nanoseconds(s * rhs)
        case .never: return .never
        @unknown default: fatalError("unhandled case \(self)")
        }
    }
    
    public static func + (lhs: DispatchTimeInterval, rhs: DispatchTimeInterval) -> DispatchTimeInterval {
        switch (lhs, rhs) {
        case (.seconds(let s1), .seconds(let s2)): return .seconds(s1 + s2)
        case (.seconds(let s1), .milliseconds(let s2)): return .milliseconds(s1 * 1000 + s2)
        case (.seconds(let s1), .microseconds(let s2)): return .microseconds(s1 * 1000000 + s2)
        case (.seconds(let s1), .nanoseconds(let s2)): return .nanoseconds(s1 * 1000000000 + s2)
            
        case (.milliseconds(let s1), .seconds(let s2)): return .milliseconds(s1 + s2 * 1000)
        case (.milliseconds(let s1), .milliseconds(let s2)): return .milliseconds(s1 + s2)
        case (.milliseconds(let s1), .microseconds(let s2)): return .microseconds(s1 * 1000 + s2)
        case (.milliseconds(let s1), .nanoseconds(let s2)): return .nanoseconds(s1 * 1000000 + s2)
            
        case (.microseconds(let s1), .seconds(let s2)): return .microseconds(s1 + s2 * 1000000)
        case (.microseconds(let s1), .milliseconds(let s2)): return .microseconds(s1 + s2 * 1000)
        case (.microseconds(let s1), .microseconds(let s2)): return .microseconds(s1 + s2)
        case (.microseconds(let s1), .nanoseconds(let s2)): return .nanoseconds(s1 * 1000 + s2)
            
        case (.nanoseconds(let s1), .seconds(let s2)): return .nanoseconds(s1 + s2 * 1000000000)
        case (.nanoseconds(let s1), .milliseconds(let s2)): return .nanoseconds(s1 + s2 * 1000000)
        case (.nanoseconds(let s1), .microseconds(let s2)): return .nanoseconds(s1 + s2 * 1000)
        case (.nanoseconds(let s1), .nanoseconds(let s2)): return .nanoseconds(s1 + s2)
            
        case (.never, _), (_, .never): return .never // never is poisonous
        @unknown default: fatalError("unhandled case \(self)")
        }
    }
    
    public static func += (lhs: inout DispatchTimeInterval, rhs: DispatchTimeInterval) {
        lhs = lhs + rhs
    }
    
    public static func - (lhs: DispatchTimeInterval, rhs: DispatchTimeInterval) -> DispatchTimeInterval {
        switch rhs {
        case .seconds(let s): return lhs + .seconds(-s)
        case .milliseconds(let s): return lhs + .milliseconds(-s)
        case .microseconds(let s): return lhs + .microseconds(-s)
        case .nanoseconds(let s): return lhs + .nanoseconds(-s)
        case .never: return .never
        @unknown default: fatalError("unhandled case \(rhs)")
        }
    }
    
    public static func -= (lhs: inout DispatchTimeInterval, rhs: DispatchTimeInterval) {
        lhs = lhs - rhs
    }
    
    // can return nil for DispatchTimeInterval.never
    func toTimeInterval() -> TimeInterval? {
        switch self {
        case .seconds(let s): return TimeInterval(s)
        case .milliseconds(let ms): return TimeInterval(ms) / 1000
        case .microseconds(let mcs): return TimeInterval(mcs) / 1000000
        case .nanoseconds(let ns): return TimeInterval(ns) / 1000000000
        case .never: return nil
        @unknown default: fatalError("unhandled case \(self)")
        }
    }
}
