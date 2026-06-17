import '../event/event_bus.dart';

/// Abstract interface for the bidirectional event system.
///
/// Implemented by `LuaStateImpl` so that host (Dart) code can register,
/// trigger, and remove event listeners that are visible to both Dart and
/// Lua sides.
///
/// Note that this is not a standard Lua API. But Lua can implement a similar
/// API using the table-based event system. Implement here for convenience.
abstract class LuaEventAPI {
  /// Register a synchronous Dart listener for [event].
  /// Returns a listener id that can be passed to [offById].
  int on(String event, EventCallback callback);

  /// Register an asynchronous Dart listener for [event].
  /// Returns a listener id that can be passed to [offById].
  int onAsync(String event, EventCallbackAsync callback);

  /// Register a one-time synchronous Dart listener for [event].
  /// The listener is automatically removed after its first invocation.
  /// Returns a listener id.
  int once(String event, EventCallback callback);

  /// Remove a listener from [event].
  ///
  /// If [callback] is provided, removes the first sync Dart listener whose
  /// callback matches by reference equality.
  /// If [asyncCallback] is provided, removes the first async Dart listener
  /// whose callback matches by reference equality.
  /// If [listenerId] is provided, removes the listener with that id
  /// regardless of event name.
  void off(String event,
      {EventCallback? callback,
      EventCallbackAsync? asyncCallback,
      int? listenerId});

  /// Remove a listener by its unique id.
  void offById(int listenerId);

  /// Emit [event] synchronously, firing all registered listeners from both
  /// Dart and Lua sides.
  ///
  /// [args] are passed to each listener.  Only Dart-primitive types
  /// (`null`, `bool`, `int`, `double`, `String`) are automatically converted
  /// to Lua stack values when calling Lua listeners.
  ///
  /// Normally, listeners must not mutate args. This will affect subsequent listeners.
  void emit(String event, [List<dynamic> args = const []]);

  /// Emit [event] asynchronously, firing all registered listeners.
  ///
  /// Async listeners (both Dart and Lua) are awaited.  Sync listeners are
  /// called synchronously within the async flow.
  Future<void> emitAsync(String event, [List<dynamic> args = const []]);

  /// Remove all listeners for [event], or all listeners for all events if
  /// [event] is `null`.
  ///
  /// **WARNING: Removing all listeners is a dangerous operation. Use at your own risk.**
  void removeAllListeners([String? event]);
}
