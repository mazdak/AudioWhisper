import SwiftUI
import Combine

/// A SwiftUI property wrapper that bridges `View` state to a typed `AppDefaults`
/// accessor. Equivalent to `@AppStorage` but reads/writes go through the
/// strongly-typed `AppDefaults` namespace instead of raw `UserDefaults` keys.
///
/// Usage:
///   @AppDefault(\.transcriptionProvider) var provider
///   @AppDefault(\.enableSmartPaste) var enableSmartPaste
///
/// The view re-renders when the underlying value changes. Two-way binding
/// works through `$provider`.
///
/// See ADR 0004 for the migration plan from `@AppStorage`.
@propertyWrapper
struct AppDefault<Value>: DynamicProperty {
    private let keyPath: ReferenceWritableKeyPath<AppDefaults.Type, Value>
    @State private var value: Value
    @StateObject private var observer: AppDefaultObserver

    init(_ keyPath: ReferenceWritableKeyPath<AppDefaults.Type, Value>) {
        self.keyPath = keyPath
        let initial = AppDefaults.self[keyPath: keyPath]
        self._value = State(initialValue: initial)
        self._observer = StateObject(wrappedValue: AppDefaultObserver())
    }

    var wrappedValue: Value {
        get { value }
        nonmutating set {
            value = newValue
            AppDefaults.self[keyPath: keyPath] = newValue
        }
    }

    var projectedValue: Binding<Value> {
        Binding(
            get: { wrappedValue },
            set: { wrappedValue = $0 }
        )
    }

    func update() {
        // Re-read once per body invocation in case the underlying store changed
        // out from under us (e.g. user toggled a setting in another window).
        let current = AppDefaults.self[keyPath: keyPath]
        if !valuesEqual(current, value) {
            DispatchQueue.main.async { self.value = current }
        }
    }

    private func valuesEqual(_ a: Value, _ b: Value) -> Bool {
        guard let lhs = a as? AnyHashable, let rhs = b as? AnyHashable else { return false }
        return lhs == rhs
    }
}

/// Listens for UserDefaults change notifications and triggers a SwiftUI
/// invalidation by mutating its own `@Published`.
private final class AppDefaultObserver: ObservableObject {
    @Published private var tick: UInt64 = 0
    private var cancellable: AnyCancellable?
    init() {
        cancellable = NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                Task { @MainActor in self?.tick &+= 1 }
            }
    }
}
