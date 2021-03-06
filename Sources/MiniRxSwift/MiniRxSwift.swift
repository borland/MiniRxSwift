//
//  MiniRxSwift version 0.0.6
//
//  Copyright © 2020 Orion Edwards. Licensed under the MIT License
//  https://opensource.org/licenses/MIT
//
//

import Foundation

public protocol ObserverType {
    associatedtype Element
    
    func onNext(_ element: Element)
    func onCompleted()
    func onError(_ error: Error)
}

public protocol ObservableType {
    associatedtype Element
    func subscribe<O: ObserverType>(_ observer: O) -> Disposable where O.Element == Element
}

public protocol Disposable {
    func dispose()
}

/// Scheduler which only dispatches things immediately and has no concept of time
public protocol ImmediateSchedulerType {
    func schedule<StateType>(_ state: StateType, action: @escaping (StateType) -> Disposable) -> Disposable
}

/// Scheduler which can dispatch things after a time interval
public protocol SchedulerType : ImmediateSchedulerType {
    var now: Date { get }
    func scheduleRelative<StateType>(_ state: StateType, dueTime: DispatchTimeInterval, action: @escaping (StateType) -> Disposable) -> Disposable
}

/** Type-Erasing bridge between Observable protocol and a class we can stick in a variable */
public class Observable<T> : ObservableType {
    public typealias Element = T
    
    public func subscribe<O: ObserverType>(_ observer: O) -> Disposable where O.Element == Element {
        fatalError("Abstract method Observable.subscribe must be overridden")
    }
}

class AnonymousObservable<T> : Observable<T> {
    private let _subscribeHandler: (AnyObserver<Element>) -> Disposable
    
    public init(_ subcribeHandler: @escaping (AnyObserver<Element>) -> Disposable) {
        _subscribeHandler = subcribeHandler
    }
    
    public override func subscribe<O: ObserverType>(_ observer: O) -> Disposable where O.Element == Element {
        return _subscribeHandler(AnyObserver.from(observer))
    }
}

public extension ObservableType {
    /** Creates a new observable by calling your closure to perform some operation
    # Reference
    [Create](http://reactivex.io/documentation/operators/create.html) */
    static func create(subscribe: @escaping (AnyObserver<Element>) -> Disposable) -> Observable<Element> {
        return AnonymousObservable(subscribe)
    }
    
    /** Creates a new observable which completes immediately with the given error:
    # Reference
    [Throw](http://reactivex.io/documentation/operators/empty-never-throw.html) */
    static func error(_ error: Error) -> Observable<Element> {
        let disposable = BooleanDisposable()
        
        return create { observer in
            if disposable.isDisposed {
                observer.onError(error)
            }
            return disposable
        }
    }
    
    /** Creates a new observable which completes immediately with no value:
    # Reference
    [Empty](http://reactivex.io/documentation/operators/empty-never-throw.html) */
    static func empty() -> Observable<Element> {
        return create { observer in
            observer.onCompleted()
            return Disposables.create()
        }
    }
    
    /** Creates a new observable which never calls onNext/onError or onComplete:
    # Reference
    [Never](http://reactivex.io/documentation/operators/empty-never-throw.html) */
    static func never() -> Observable<Element> {
        return create { observer in
            return Disposables.create()
        }
    }
    
    /** Creates a new observable which immediately returns the given value, then completes.
    # Reference
    [Just](http://reactivex.io/documentation/operators/just.html) */
    static func just(_ value: Element) -> Observable<Element> {
        return create { observer in
            observer.onNext(value)
            observer.onCompleted()
            return Disposables.create()
        }
    }
    
    /** Delays the creation of the observable (via `observableFactory`) until it is subscribed to.
    # Reference
    [Defer](http://reactivex.io/documentation/operators/defer.html) */
    static func deferred(_ observableFactory: @escaping () throws -> Observable<Element>) -> Observable<Element> {
        return create { observer in
            do {
                return try observableFactory().subscribe(observer)
            } catch let err {
                observer.onError(err)
                return Disposables.create()
            }
        }
    }
    
    /** When subscribed to, will iterate the given `sequence`, and push each value immediately, then complete.
    # Reference
    [From](http://reactivex.io/documentation/operators/from.html) */
    static func from<S : Sequence>(_ sequence: S) -> Observable<Element> where S.Element == Element {
        return create { observer in
            for item in sequence {
                observer.onNext(item)
            }
            observer.onCompleted()
            // un-cancellable because we execute immediately.
            // This is a problem if the onNext handler wants to cancel after the first item (e.g. take(1))
            // however we can't solve it without schedulers and thread-jumping so let's deal with that later
            return Disposables.create()
        }
    }
    
    /** Creates an observable which internally subscribes to all the `sources` concurrently, publishing values as soon as they arrive.
    Completes when all sources complete, or errors on the first error from any source
    # Reference
    [Merge](http://reactivex.io/documentation/operators/merge.html) */
    static func merge(_ sources: Observable<Element>...) -> Observable<Element> {
        return merge(sources)
    }
    
    /** Creates an observable which internally subscribes to all the `sources` concurrently, publishing values as soon as they arrive.
    Completes when all sources complete, or errors on the first error from any source
    # Reference
    [Merge](http://reactivex.io/documentation/operators/merge.html) */
    static func merge(_ sources: [Observable<Element>]) -> Observable<Element> {
        return create { observer in
            let group = CompositeDisposable()
            
            for source in sources {
                var subKey: CompositeDisposable.DisposeKey? = nil
                subKey = group.insert(source.subscribe(onNext: { value in
                    observer.onNext(value)
                }, onError: { err in
                    group.dispose() // if one fails, abort everything
                    observer.onError(err)
                }, onCompleted: {
                    if let sk = subKey {
                        group.remove(for: sk)
                    }
                }))
            }
            
            return group
        }
    }
    
    /** Creates an observable which subscribes each of `sources` one after the other. It will move from the first source to the second after it completes, etc.
    Completes after the last source completes, or errors on the first error from any source.
    # Reference
    [Concat](http://reactivex.io/documentation/operators/concat.html) */
    static func concat(_ sources: Observable<Element> ...) -> Observable<Element> {
        return concat(sources)
    }
    
    /** Creates an observable which subscribes each of `sources` one after the other. It will move from the first source to the second after it completes, etc.
    Completes after the last source completes, or errors on the first error from any source.
    # Reference
    [Concat](http://reactivex.io/documentation/operators/concat.html) */
    static func concat(_ sources: [Observable<Element>]) -> Observable<Element> {
        return create { observer in
            let current = SerialDisposable()
            
            var iter = sources.makeIterator()
            func processNext() {
                if let source = iter.next() {
                    current.disposable = source.subscribe(
                        onNext: observer.onNext,
                        onError: { err in
                            current.dispose()
                            observer.onError(err)
                        },
                        onCompleted: {
                            processNext()
                        })
                } else { // end of sequence
                    current.disposable = nil
                    observer.onCompleted()
                }
            }
            processNext()
            return current
        }
    }
    
    /** Creates an observable which calls onNext after `dueTime`. If `period` is specified, then it will call onNext repeatedly after each `period`. If not, then it will complete.
    # Reference
    [Timer](http://reactivex.io/documentation/operators/timer.html) */
    static func timer(_ dueTime: DispatchTimeInterval, period: DispatchTimeInterval? = nil, scheduler: SchedulerType)
        -> Observable<Element> where Element : FixedWidthInteger {
        return create { observer in
            if let p = period {
                let current = Element()
                func handler(next: Element) -> Disposable {
                    observer.onNext(next) // repeating timer never completes
                    return scheduler.scheduleRelative(next.advanced(by: 1), dueTime: p, action: handler)
                }
                return scheduler.scheduleRelative(current, dueTime: dueTime, action: handler)
                
            } else { // one-shot timer
                return scheduler.scheduleRelative(Element(), dueTime: dueTime) { (i) -> Disposable in
                    observer.onNext(i)
                    observer.onCompleted()
                    return Disposables.create()
                }
            }
        }
    }
    
    /** Creates an observable which emits items from `source1` and `source2` paired together, using `resultSelector` to process each pair.
     Stops after the first sequence stops
    # Reference
    [CombineLatest](http://reactivex.io/documentation/operators/combinelatest.html) */
    static func combineLatest<O1: ObservableType, O2: ObservableType, R>(
        _ source1: O1,
        _ source2: O2,
        resultSelector: @escaping (O1.Element, O2.Element) -> R) -> Observable<R> {
        return Observable<R>.create { observer in
            let group = CompositeDisposable()
            
            var lastA: O1.Element? = nil
            var lastB: O2.Element? = nil
            
            var d1: CompositeDisposable.DisposeKey?
            var d2: CompositeDisposable.DisposeKey?
            
            d1 = group.insert(source1.subscribe(onNext: { (a) in
                lastA = a
                if let b = lastB { observer.onNext(resultSelector(a, b)) }
            }, onError: { (err) in
                if let other = d2 { group.remove(for: other) }
                observer.onError(err)
            }, onCompleted: {
                if let other = d2 { group.remove(for: other) }
            }))
            
            d2 = group.insert(source2.subscribe(onNext: { (b) in
                lastB = b
                if let a = lastA { observer.onNext(resultSelector(a, b)) }
            }, onError: { (err) in
                if let other = d1 { group.remove(for: other) }
                observer.onError(err)
            }, onCompleted: {
                if let other = d1 { group.remove(for: other) }
            }))
            
            return group
        }
    }
}

public struct Disposables {
    private init() { }
    
    private struct NopDisposable : Disposable {
        func dispose() { }
    }
    
    private class AnyDisposable : Disposable, Lockable {
        private var _disposeAction: (() -> Void)?
        
        init(disposeAction: @escaping () -> Void) {
            _disposeAction = disposeAction
        }
        
        func dispose() {
            var action: (() -> Void)? = nil
            synchronized {
                if let d = _disposeAction {
                    action = d
                    _disposeAction = nil
                }
            }
            action?()
        }
    }
    
    public static func create() -> Disposable {
        NopDisposable()
    }
    
    public static func create(with dispose: @escaping () -> Void) -> Disposable {
        AnyDisposable(disposeAction: dispose)
    }
}

public protocol Cancelable : Disposable {
    var isDisposed: Bool { get }
}

public class BooleanDisposable : Cancelable {
    public var isDisposed: Bool = false
    
    public init() { }
    
    public func dispose() {
        self.isDisposed = true
    }
}

struct BagKey : Equatable, Hashable {
    static func update(state: inout BagKey) -> BagKey {
        let nextValue = state.value + 1
        let result = BagKey(value: nextValue)
        state = result // update
        return result
    }
    
    let value: Int64
    init() {
        self.value = 0
    }
    
    private init(value: Int64) {
        self.value = value
    }
}

// we need to add and remove observers and stuff to arrays, but the things aren't themselves equatable,
// so we need to attach some arbitrary key to each one.
// Unlike the RxSwift version, this isn't optimised for speed, we want smaller code size.
// Note: Like the RxSwift version this is NOT THREAD SAFE
struct Bag<T> {
    
    private var _nextKey = BagKey()
    private var _items: [BagKey: T] = [:]
    
    mutating func insert(_ item: T) -> BagKey {
        let key = BagKey.update(state: &_nextKey)
        _items[key] = item
        return key
    }
    
    mutating func removeKey(_ key: BagKey) -> T? {
        return _items.removeValue(forKey: key)
    }
    
    // copies the current items into a new array
    func toArray() -> [T] {
        var result:[T] = []
        result.reserveCapacity(_items.count)
        for (_, v) in _items {
            result.append(v)
        }
        return result
    }
}

/** Represents an Event Source that you can use to publish values:
http://www.introtorx.com/content/v1.0.10621.0/02_KeyTypes.html#Subject */
public class PublishSubject<T> : Observable<T>, ObserverType, Lockable {
    private var _subscribers = Bag<AnyObserver<T>>()
    
    public override init() {
        super.init()
    }
    
    public override func subscribe<O : ObserverType>(_ observer: O) -> Disposable where O.Element == T {
        let wrapper = AnyObserver.from(observer)
        let removeKey =  synchronized {
            _subscribers.insert(wrapper)
        }
        return Disposables.create(with: {
            self.synchronized {
                self._subscribers.removeKey(removeKey)
            }
            print()
        })
    }
    public func onNext(_ element: T) {
        let subscribers = synchronized { _subscribers.toArray() }
        for s in subscribers { s.onNext(element) }
    }
    public func onError(_ error: Error) {
        let subscribers = synchronized { _subscribers.toArray() }
        for s in subscribers { s.onError(error) }
    }
    public func onCompleted() {
        let subscribers = synchronized { _subscribers.toArray() }
        for s in subscribers { s.onCompleted() }
    }
}

// observable.share needs to dispose of its underlying source when dispose.
// otherwise the same as a publish subject
private class SharedSubject<T> : PublishSubject<T>, Disposable {
    private let _source: Disposable
    
    init(source: Disposable) {
        _source = source
    }
    
    func dispose() {
        _source.dispose()
    }
    
    
}

public class BehaviorSubject<T> : PublishSubject<T> {
    private var _value: Element
    private var _error: Error? = nil
    
    public init(value: Element) {
        _value = value
        super.init()
    }
    
    public func value() throws -> Element {
        _value
    }
    
    public override func subscribe<O : ObserverType>(_ observer: O) -> Disposable where O.Element == T {
        return synchronized {
            if let err = _error { // already failed
                observer.onError(err)
                return Disposables.create()
            }
            
            observer.onNext(_value)
            return super.subscribe(onNext: { val in
                self.synchronized {
                    self._value = val
                    observer.onNext(val)
                }
            }, onError: { err in
                self.synchronized {
                    self._error = err
                    observer.onError(err)
                }
            }, onCompleted: {
                observer.onCompleted()
            })
        }
    }
}

/** Overloads on subscribe to make it nice to use */
public extension ObservableType {
    /** type erasing wrapper */
    func asObservable() -> Observable<Element> {
        return AnonymousObservable(self.subscribe)
    }
    
    func subscribe(onNext: ((Element) -> Void)? = nil, onError: ((Swift.Error) -> Void)? = nil, onCompleted: (() -> Void)? = nil) -> Disposable {
        return subscribe(AnyObserver(onNext: onNext, onError: onError, onCompleted: onCompleted))
    }
}

// type-erased ObserverType
public struct AnyObserver<Element> : ObserverType {
    private let _onNext: ((Element) -> Void)?
    private let _onError: ((Swift.Error) -> Void)?
    private let _onCompleted: (() -> Void)?
    
    /// Creates an AnyObserver from an existing observer, with a fast-path if the incoming observer is already an AnyObserver
    public static func from<T>(_ observer: T) -> AnyObserver<Element> where T : ObserverType, Element == T.Element  {
        if let alreadyAnyObserver = observer as? AnyObserver<Element> {
            return alreadyAnyObserver
        } else {
            return AnyObserver(observer: observer)
        }
    }
    
    public init(onNext: ((Element) -> Void)? = nil, onError: ((Swift.Error) -> Void)? = nil, onCompleted: (() -> Void)? = nil) {
        _onNext = onNext
        _onError = onError
        _onCompleted = onCompleted
    }
    
    public init<O: ObserverType>(observer: O) where O.Element == Element {
        _onNext = observer.onNext
        _onError = observer.onError
        _onCompleted = observer.onCompleted
    }
    
    public func onNext(_ element: Element) {
        _onNext?(element)
    }
    public func onCompleted() {
        _onCompleted?()
    }
    public func onError(_ error: Error) {
        _onError?(error)
    }
}

public class CompositeDisposable : Disposable, Lockable {
    private var _disposables = Bag<Disposable>()
    private var _disposed = false
    
    public struct DisposeKey {
        fileprivate let value: BagKey
        fileprivate init(value: BagKey) {
            self.value = value
        }
    }
    
    public init() { }
    
    public init(_ disposables: Disposable...) {
        for d in disposables {
            _ = _disposables.insert(d) // discard the DisposeKey as there's no way for the caller to see it
        }
    }
    
    public func insert(_ disposable: Disposable) -> DisposeKey? {
        synchronized {
            if _disposed {
                disposable.dispose()
                return nil
            }
            let bagKey = _disposables.insert(disposable)
            return DisposeKey(value: bagKey)
        }
    }
    
    // removes and disposes the value identified by disposeKey
    public func remove(for disposeKey: DisposeKey) {
        synchronized {
            _disposables.removeKey(disposeKey.value)
        }?.dispose()
    }
    
    public func dispose() {
        let copy:[Disposable] = synchronized {
            _disposed = true
            let copy = _disposables.toArray()
            _disposables = .init()
            return copy
        }
        for d in copy { d.dispose() }
    }
}

public class SerialDisposable : Cancelable, Lockable {
    private var _disposable: Disposable?
    private var _disposed = false

    public init() {}
    
    public init(disposable: Disposable) {
        _disposable = disposable
    }
    
    public var isDisposed: Bool {
        synchronized { _disposed }
    }
    
    public var disposable:Disposable? {
        get { return _disposable }
        set {
            if let old: Disposable = synchronized({
                let x = _disposable
                _disposable = newValue
                return x
            }) {
                old.dispose()
            }
            // needs to come after the old/swap so dispose() can call this
            if _disposed {
                newValue?.dispose()
                return
            }
        }
    }
    
    public func dispose() {
        _disposed = true
        self.disposable = nil
    }
}

public class TimeoutError : Error { }

public extension ObservableType {
    /** Transforms values as they are emitted by an observable
    # Reference
    [Map](http://reactivex.io/documentation/operators/map.html) */
    func map<R>(transform: @escaping (Element) throws -> R) -> Observable<R> {
        return Observable.create { observer in
            self.subscribe(onNext: { value in
                do {
                    observer.onNext(try transform(value))
                } catch let error {
                    observer.onError(error)
                }
            },
            onError: observer.onError,
            onCompleted: observer.onCompleted)
        }
    }
    
    /** Transforms values from the source observable into subsequent observables (a chain of async operations) then flattens into a single observable
    # Reference
    [FlatMap](http://reactivex.io/documentation/operators/flatmap.html) */
    func flatMap<T:ObservableType, R>(transform: @escaping (Element) throws -> T) -> Observable<R> where T.Element == R {
        return Observable.create { observer in
            let group = CompositeDisposable()
            var count:Int32 = 1
            let completionHandler = {
                let newCount = OSAtomicDecrement32(&count)
                if newCount == 0 { // all done
                    observer.onCompleted()
                }
            }
            
            _ = group.insert(self.subscribe(
                onNext: { (value) -> Void in
                    do {
                        OSAtomicIncrement32(&count)
                        let innerDisposable = (try transform(value)).subscribe(
                            onNext: { value in
                                observer.onNext(value)
                            },
                            onError: { error in
                                group.dispose()
                                observer.onError(error)
                            },
                            onCompleted: completionHandler)
                        
                        _ = group.insert(innerDisposable)
                        
                    } catch let error {
                        group.dispose()
                        observer.onError(error)
                    }
                },
                onError: observer.onError,
                onCompleted: completionHandler))
            
            return group
        }
    }

    /** Accumulates values from a sequence into a single result, using `accumulator` to merge each value into the result
    # Reference
    [Reduce](http://reactivex.io/documentation/operators/reduce.html) */
    func reduce<Result>(_ seed: Result, accumulator: @escaping (Result, Element) throws -> Result) -> Observable<Result> {
        return Observable.create { observer in
            var result: Result = seed
            var disposable: Disposable!
            disposable = self.subscribe(onNext: { value in
                do {
                    result = try accumulator(result, value)
                } catch let err {
                    disposable.dispose()
                    observer.onError(err)
                }
            },
            onError: observer.onError,
            onCompleted: {
                observer.onNext(result)
                observer.onCompleted()
            })
            return disposable
        }
    }
    
    /** Discards values from a sequence which do not match the given `predicate`
    # Reference
    [Filter](http://reactivex.io/documentation/operators/filter.html) */
    func filter(predicate: @escaping (Element) throws -> Bool) -> Observable<Element> {
        return Observable.create { (observer) -> Disposable in
            self.subscribe(onNext: { (value) in
                do {
                    if try predicate(value) {
                        observer.onNext(value)
                    }
                } catch let error {
                    observer.onError(error)
                }
            },
            onError: observer.onError,
            onCompleted: observer.onCompleted)
        }
    }
    
    /** Attaches side effects to a sequence without modifying its values
    # Reference
    [Do](http://reactivex.io/documentation/operators/do.html) */
    func `do`(onNext: ((Element) throws -> Void)? = nil, onError: ((Swift.Error) throws -> Void)? = nil, onCompleted: (() throws -> Void)? = nil) -> Observable<Element> {
        return Observable.create { (observer) -> Disposable in
            var disposable: Disposable! = nil
            disposable = self.subscribe(onNext: { (value) in
                do {
                    try onNext?(value)
                    observer.onNext(value)
                } catch let error {
                    disposable?.dispose()
                    observer.onError(error)
                }
            },
            onError: { err in
                do {
                    try onError?(err)
                    observer.onError(err)
                } catch let error {
                    disposable?.dispose()
                    observer.onError(error)
                }
            },
            onCompleted: {
                do {
                    try onCompleted?()
                    observer.onCompleted()
                } catch let error {
                    disposable?.dispose()
                    observer.onError(error)
                }
            })
            return disposable
        }
    }
    
    /** If an observable emits an error, rather than stopping, this will continue the sequence with a second observable produced by `handler`
    # Reference
    [Catch](http://reactivex.io/documentation/operators/catch.html) */
    func catchError(_ handler: @escaping (Error) throws -> Observable<Element>) -> Observable<Element> {
        return Observable.create { (observer) -> Disposable in
            let disposable = SerialDisposable()
                
            disposable.disposable = self.subscribe(
                onNext: observer.onNext,
                onError: { error in
                    do {
                        disposable.disposable = try handler(error).subscribe(observer)
                    } catch let innerErr { // TODO tests around this behaviour to make sure it matches Rx
                        observer.onError(innerErr)
                        disposable.dispose()
                    }
                },
                onCompleted: observer.onCompleted)
            
            return disposable
        }
    }
    
    /** Ignores duplicate values from a sequence
    # Reference
    [Distinct](http://reactivex.io/documentation/operators/distinct.html) */
    func distinctUntilChanged() -> Observable<Element> where Element: Equatable {
        return distinctUntilChanged { a, b in a == b }
    }
    
    /** Ignores duplicate values from a sequence
    # Reference
    [Distinct](http://reactivex.io/documentation/operators/distinct.html) */
    func distinctUntilChanged(_ comparer: @escaping (Element, Element) throws -> Bool) -> Observable<Element> {
        return Observable.create { observer in
            var _prev: Element? = nil
            return self.subscribe(onNext: { value in
                do {
                    if let prev = _prev, try comparer(prev, value) {
                        return // suppress duplicate value
                    }
                } catch let err {
                    observer.onError(err)
                    return
                }
                _prev = value
                observer.onNext(value)
            },
            onError: observer.onError,
            onCompleted: observer.onCompleted)
        }
    }
    
    /** Causes `onNext/onError/onCompleted` to be called on the given scheduler (usually for thread-jumping to the main thread)
    # Reference
    [ObserveOn](http://reactivex.io/documentation/operators/observeon.html) */
    func observeOn(_ scheduler: ImmediateSchedulerType) -> Observable<Element> {
        return Observable.create { observer in
            return self.subscribe(onNext: { value in
                _ = scheduler.schedule(()) {
                    observer.onNext(value)
                    return Disposables.create()
                }
            },
            onError: { err in
                _ = scheduler.schedule(()) {
                    observer.onError(err)
                    return Disposables.create()
                }
            },
            onCompleted: {
                _ = scheduler.schedule(()) {
                    observer.onCompleted()
                    return Disposables.create()
                }
            })
        }
    }
    
    /** Causes the `subscribe` code to be called on the given scheduler (usually for thread-jumping).
    # Reference
    [SubscribeOn](http://reactivex.io/documentation/operators/subscribeon.html) */
    func subscribeOn(_ scheduler: ImmediateSchedulerType) -> Observable<Element> {
        return Observable.create { observer in
            return scheduler.schedule(()) { () -> Disposable in
                self.subscribe(observer)
            }
        }
    }
    
    /** If the given observable does not emit a value within `dueTime`, will instead publish a `TimeoutError` to abort the observable, rather than waiting forever.
    # Reference
    [ObserveOn](http://reactivex.io/documentation/operators/timeout.html) */
    func timeout(_ dueTime: DispatchTimeInterval, scheduler: SchedulerType) -> Observable<Element> {
        return Observable.create { observer in
            let gate = Lock()
            var innerDisposable: Disposable? = nil
            let timeoutDisposable = scheduler.scheduleRelative((), dueTime: dueTime) {
                gate.synchronized({ () -> Disposable? in
                    let r = innerDisposable
                    innerDisposable = nil
                    return r
                })?.dispose()
                observer.onError(TimeoutError())
                return Disposables.create()
            }
            
            innerDisposable = self.subscribe { (value) in
                if gate.synchronized({ innerDisposable }) == nil {
                    return
                }
                observer.onNext(value)
            } onError: { (err) in
                gate.synchronized { innerDisposable = nil }
                timeoutDisposable.dispose()
            } onCompleted: {
                gate.synchronized { innerDisposable = nil }
                timeoutDisposable.dispose()
            }
            
            return CompositeDisposable(innerDisposable!, timeoutDisposable)
        }
    }
    
    /** Collects all the values emitted by an observable into a single Array. When the source observable completes, this will publish `onNext` with the array containing all the values
    # Reference
    [To](http://reactivex.io/documentation/operators/to.html) */
    func toArray() -> Observable<[Element]> {
        return Observable.create { observer in
            var buffer = [Element]()
            return self.subscribe { (value) in
                buffer.append(value)
            } onError: { (err) in
                observer.onError(err)
            } onCompleted: {
                observer.onNext(buffer)
                observer.onCompleted()
            }
        }
    }
    
    /** If an observable encouters an error, will re-subscribe (to restart the operation) up to `maxAttemptCount` times, before finally allowing it to fail.
    # Reference
    [Retry](http://reactivex.io/documentation/operators/retry.html) */
    func retry(_ maxAttemptCount: Int) -> Observable<Element> {
        if maxAttemptCount == 0 {
            return self.asObservable() // don't catch the error
        }
        return self.catchError { _ in
            return retry(maxAttemptCount - 1) // caught an error, retry with attempt count - 1
        }
    }
    
    /** Funnels values from an observable through an intermediary PublishSubject, so that downstream code can subscribe multiple times where the source only subscribes once
    # Reference
    [Refcount](http://reactivex.io/documentation/operators/refcount.html) */
    func share() -> Observable<Element> {
        return Observable.deferred {
            let source = SerialDisposable()
            let shared = SharedSubject<Element>(source: source)
                
            source.disposable = self.subscribe { (value) in
                shared.onNext(value)
            } onError: { (err) in
                shared.onError(err)
            } onCompleted: {
                shared.onCompleted()
            }
            return shared
        }
    }
}

public class SerialDispatchQueueScheduler : DispatchQueueScheduler { } // for API compat with rxswift

public class DispatchQueueScheduler : SchedulerType {
    let _queue: DispatchQueue
    
    public init(_ queue: DispatchQueue) {
        _queue =  queue
    }
    
    public var now: Date {
       Date()
    }
    
    public func schedule<StateType>(_ state: StateType, action: @escaping (StateType) -> Disposable) -> Disposable {
        let disposable = SerialDisposable()
        _queue.async {
            if disposable.isDisposed { return }
            disposable.disposable = action(state)
        }
        return disposable
    }
    
    public func scheduleRelative<StateType>(_ state: StateType, dueTime: DispatchTimeInterval, action: @escaping (StateType) -> Disposable) -> Disposable {
        let disposable = SerialDisposable()
        _queue.asyncAfter(deadline: .now() + dueTime) {
            if disposable.isDisposed {
                return // don't process the action
            }
            disposable.disposable = action(state)
        }
        return disposable
    }
}

public class MainScheduler : SerialDispatchQueueScheduler {
    public static let instance = MainScheduler()
    
    public init() {
        super.init(DispatchQueue.main)
    }
}

fileprivate protocol Lockable : AnyObject { }

fileprivate extension Lockable {
    @discardableResult // sometimes you just want to lock something and don't care about the return value
    func synchronized<T>(_ block:() throws -> T) rethrows -> T {
        objc_sync_enter(self)
        defer{ objc_sync_exit(self) }
        
        return try block()
    }
}

fileprivate class Lock : Lockable { }
