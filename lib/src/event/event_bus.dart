/// Event bus for bidirectional Dart ↔ Lua event notifications.
///
/// Stores listener entries from both sides in a unified map keyed by event
/// name.  Dispatch logic lives in [LuaStateImpl]; this class only manages
/// storage.
library;

/// Synchronous Dart event callback.
typedef EventCallback = void Function(List<dynamic> args);

/// Asynchronous Dart event callback.
typedef EventCallbackAsync = Future<void> Function(List<dynamic> args);

/// A single listener entry inside the [EventBus].
class ListenerEntry {
  /// Monotonically increasing id, unique across all entries.
  final int id;

  /// The event name this listener was registered for.
  final String event;

  /// When `true`, the callback is a Lua function stored by [luaRef] in the
  /// Lua registry.
  final bool isLua;

  /// Registry reference (valid only when [isLua] is `true`).
  final int? luaRef;

  /// Synchronous Dart callback (valid when [isLua] is `false` and
  /// [dartCallbackAsync] is `null`).
  final EventCallback? dartCallback;

  /// Asynchronous Dart callback (valid when [isLua] is `false` and
  /// [dartCallback] is `null`).
  final EventCallbackAsync? dartCallbackAsync;

  /// When `true`, the entry is automatically removed after its first
  /// invocation.
  final bool once;

  /// Thread id of the [LuaStateImpl] that registered this listener.
  ///
  /// Used by Lua-side removal paths to enforce that a Lua state can only
  /// remove listeners that it itself registered for defense.
  final int ownerId;

  ListenerEntry({
    required this.id,
    required this.event,
    required this.isLua,
    required this.ownerId,
    this.luaRef,
    this.dartCallback,
    this.dartCallbackAsync,
    required this.once,
  });
}

/// Central storage for event listeners registered from both Dart and Lua.
///
/// This class is intentionally state-management-only; the actual dispatch
/// (calling Lua functions via the VM, pushing stack values, etc.) is
/// implemented in `LuaStateImpl`.
class EventBus {
  final Map<String, List<ListenerEntry>> _listeners = {};
  int _nextId = 1;

  // ------------------------------------------------------------------
  // Registration
  // ------------------------------------------------------------------

  /// Register a Lua-side listener.  [luaRef] is the registry reference
  /// obtained via `LuaStateImpl.ref()`.  [ownerId] is the thread id of the
  /// state that registered the listener.
  int addLuaListener(String event, int luaRef,
      {required int ownerId, bool once = false}) {
    final entry = ListenerEntry(
      id: _nextId++,
      event: event,
      isLua: true,
      ownerId: ownerId,
      luaRef: luaRef,
      once: once,
    );
    _listeners.putIfAbsent(event, () => []).add(entry);
    return entry.id;
  }

  /// Register a synchronous Dart listener.  [ownerId] is the thread id of
  /// the state that registered the listener.
  int addDartListener(String event, EventCallback cb,
      {required int ownerId, bool once = false}) {
    final entry = ListenerEntry(
      id: _nextId++,
      event: event,
      isLua: false,
      ownerId: ownerId,
      dartCallback: cb,
      once: once,
    );
    _listeners.putIfAbsent(event, () => []).add(entry);
    return entry.id;
  }

  /// Register an asynchronous Dart listener.  [ownerId] is the thread id of
  /// the state that registered the listener.
  int addDartListenerAsync(String event, EventCallbackAsync cb,
      {required int ownerId, bool once = false}) {
    final entry = ListenerEntry(
      id: _nextId++,
      event: event,
      isLua: false,
      ownerId: ownerId,
      dartCallbackAsync: cb,
      once: once,
    );
    _listeners.putIfAbsent(event, () => []).add(entry);
    return entry.id;
  }

  // ------------------------------------------------------------------
  // Removal
  // ------------------------------------------------------------------

  /// Remove a listener by its unique id.  Returns `true` if found and removed.
  bool removeById(int id) {
    for (final entry in _listeners.entries) {
      final list = entry.value;
      final idx = list.indexWhere((e) => e.id == id);
      if (idx != -1) {
        list.removeAt(idx);
        _cleanEmpty(entry.key, list);
        return true;
      }
    }
    return false;
  }

  /// Remove a Lua listener by its registry ref within a specific event.
  /// Returns `true` if found and removed.
  bool removeLuaListenerByRef(String event, int luaRef) {
    final list = _listeners[event];
    if (list == null) return false;
    final idx = list.indexWhere((e) => e.isLua && e.luaRef == luaRef);
    if (idx != -1) {
      list.removeAt(idx);
      _cleanEmpty(event, list);
      return true;
    }
    return false;
  }

  /// Remove a sync Dart listener by reference equality within a specific
  /// event.  Returns `true` if found and removed.
  bool removeDartListener(String event, EventCallback cb) {
    final list = _listeners[event];
    if (list == null) return false;
    final idx = list.indexWhere((e) => !e.isLua && e.dartCallback == cb);
    if (idx != -1) {
      list.removeAt(idx);
      _cleanEmpty(event, list);
      return true;
    }
    return false;
  }

  /// Remove an async Dart listener by reference equality within a specific
  /// event.  Returns `true` if found and removed.
  bool removeDartListenerAsync(String event, EventCallbackAsync cb) {
    final list = _listeners[event];
    if (list == null) return false;
    final idx = list.indexWhere((e) => !e.isLua && e.dartCallbackAsync == cb);
    if (idx != -1) {
      list.removeAt(idx);
      _cleanEmpty(event, list);
      return true;
    }
    return false;
  }

  /// Remove [event] from [_listeners] when its list is empty, preventing
  /// accumulation of dead keys over time.
  void _cleanEmpty(String event, List<ListenerEntry> list) {
    if (list.isEmpty) _listeners.remove(event);
  }

  /// Remove all listeners for [event], or all listeners for all events if
  /// [event] is `null`.  Returns the list of removed Lua refs so the caller
  /// can release them via `unRef`.
  List<int> removeAllListeners([String? event]) {
    final removedRefs = <int>[];
    if (event != null) {
      final list = _listeners.remove(event);
      if (list != null) {
        for (final e in list) {
          if (e.isLua && e.luaRef != null) {
            removedRefs.add(e.luaRef!);
          }
        }
      }
    } else {
      for (final list in _listeners.values) {
        for (final e in list) {
          if (e.isLua && e.luaRef != null) {
            removedRefs.add(e.luaRef!);
          }
        }
      }
      _listeners.clear();
    }
    return removedRefs;
  }

  // ------------------------------------------------------------------
  // Query
  // ------------------------------------------------------------------

  /// Return a snapshot (copy) of the listener list for [event].
  /// Safe to iterate while listeners may be added/removed.
  List<ListenerEntry> getListeners(String event) {
    final list = _listeners[event];
    if (list == null || list.isEmpty) return const [];
    return List.unmodifiable(list);
  }

  /// Return all event names that currently have listeners.
  Iterable<String> get eventNames => _listeners.keys;
}
