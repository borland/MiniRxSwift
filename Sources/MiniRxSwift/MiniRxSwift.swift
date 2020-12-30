//
//  MiniRxSwift version 0.0.1
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
        return _subscribeHandler(AnyObserver(observer: observer))
    }
}

public extension ObservableType {
    
    /** Creates a new observable by calling your closure to perform some operation:
    http://www.introtorx.com/content/v1.0.10621.0/04_CreatingObservableSequences.html#ObservableCreate */
    static func create(subscribe: @escaping (AnyObserver<Element>) -> Disposable) -> Observable<Element> {
        return AnonymousObservable(subscribe)
    }
    
    /** Creates a new observable which returns the given error:
    http://www.introtorx.com/content/v1.0.10621.0/04_CreatingObservableSequences.html#ObservableThrow */
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
    http://www.introtorx.com/content/v1.0.10621.0/04_CreatingObservableSequences.html#ObservableEmpty */
    static func empty() -> Observable<Element> {
        return create { observer in
            observer.onCompleted()
            return Disposables.create()
        }
    }
    
    /** Creates a new observable which immediately returns the provided value, then completes:
    http://www.introtorx.com/content/v1.0.10621.0/04_CreatingObservableSequences.html#ObservableReturn */
    static func just(_ value: Element) -> Observable<Element> {
        return create { observer in
            observer.onNext(value)
            observer.onCompleted()
            return Disposables.create()
        }
    }
    
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
            withLock {
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
    public typealias Element = T
    private var _subscribers = Bag<AnyObserver<T>>()
    
    public override init() {
        super.init()
    }
    
    public override func subscribe<O : ObserverType>(_ observer: O) -> Disposable where O.Element == T {
        let wrapper = AnyObserver(observer: observer)
        let removeKey =  withLock {
            _subscribers.insert(wrapper)
        }
        return Disposables.create(with: {
            self.withLock {
                self._subscribers.removeKey(removeKey)
            }
            print()
        })
    }
    public func onNext(_ element: T) {
        let subscribers = withLock { _subscribers.toArray() }
        for s in subscribers { s.onNext(element) }
    }
    public func onError(_ error: Error) {
        let subscribers = withLock { _subscribers.toArray() }
        for s in subscribers { s.onError(error) }
    }
    public func onCompleted() {
        let subscribers = withLock { _subscribers.toArray() }
        for s in subscribers { s.onCompleted() }
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
    
    public func insert(_ disposable: Disposable) -> DisposeKey? {
        withLock {
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
        withLock {
            let v = _disposables.removeKey(disposeKey.value)
            v?.dispose()
        }
    }
    
    public func dispose() {
        let copy:[Disposable] = withLock {
            _disposed = true
            let copy = _disposables.toArray()
            _disposables = .init()
            return copy
        }
        for d in copy { d.dispose() }
    }
}

public class SerialDisposable : Disposable, Lockable {
    private var _disposable: Disposable?
    private var _disposed = false

    public init() {}
    
    public init(disposable: Disposable) {
        _disposable = disposable
    }
    
    public var disposable:Disposable? {
        get { return _disposable }
        set {
            if let old: Disposable = withLock({
                let x = _disposable
                _disposable = newValue
                return x
            }) {
                old.dispose()
            }
        }
    }
    
    public func dispose() {
        if let copy:Disposable = withLock({
            let x = _disposable
            _disposable = nil
            return x
        }) {
            copy.dispose()
        }
    }
}

/** Linq */
public extension ObservableType {
    
    // untested
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
    
    // untested
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
    
    // untested
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
    
    // untested
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
}

fileprivate protocol Lockable : AnyObject { }

fileprivate extension Lockable {
    @discardableResult // sometimes you just want to lock something and don't care about the return value
    func withLock<T>(_ block:() throws -> T) rethrows -> T {
        objc_sync_enter(self)
        defer{ objc_sync_exit(self) }
        
        return try block()
    }
}
