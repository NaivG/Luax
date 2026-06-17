import '../api/lua_state.dart';
import '../api/lua_type.dart';
import '../state/lua_state_impl.dart';

/// Lua standard library module for the bidirectional event system.
///
/// Exposes `event.on`, `event.off`, `event.emit`, `event.once`, and
/// `event.emitAsync` to Lua scripts.  `event.removeAllListeners` is
/// intentionally not exposed — Lua is sandboxed to only operate on
/// listeners it itself registered; removing Dart-side listeners is the
/// host's responsibility via `LuaState.removeAllListeners`.
class EventLib {
  /// Registry key for the fn-map table: `{[eventName] = {[ref] = fn}}`.
  /// Refs are unique (from [LuaState.ref]), so duplicate registrations of
  /// the same function never collide; each ref key maps back to the original
  /// Lua function for fast cleanup by ref.
  static const String fnMapKey = '__event_fn_map';

  static int openEventLib(LuaState ls) {
    // Create the module table with sync functions.
    ls.newLib(_syncFuncs);

    // Register emitAsync as an async Dart function.
    ls.pushDartFunctionAsync(_emitAsync, 'event.emitAsync');
    ls.setField(-2, 'emitAsync');

    // Create the fn-map table in the registry.
    _ensureFnMap(ls);

    return 1;
  }

  static const Map<String, DartFunction?> _syncFuncs = {
    'on': _on,
    'off': _off,
    'emit': _emit,
    'once': _once,
  };

  // ------------------------------------------------------------------
  // Lua-side API
  // ------------------------------------------------------------------

  /// `event.on(name, callback)` → returns listener id
  static int _on(LuaState ls) {
    final name = ls.checkString(1)!;
    ls.checkType(2, LuaType.luaFunction);

    // Store fn→ref mapping for later off() lookup.
    final ref = _refLuaFunction(ls, 2, name);

    final impl = ls as LuaStateImpl;
    final id = impl.eventBus.addLuaListener(name, ref, ownerId: impl.id);

    ls.pushInteger(id);
    return 1;
  }

  /// `event.off(name, callback_or_id)`
  static int _off(LuaState ls) {
    final name = ls.checkString(1)!;
    final impl = ls as LuaStateImpl;

    if (ls.type(2) == LuaType.luaNumber) {
      // Remove by listener id.  Lua may only remove listeners that it
      // itself registered on this state (isLua + ownerId match).  Any
      // other id — including a Dart-registered listener's id — is a
      // silent no-op.
      final id = ls.checkInteger(2)!;
      final entry = impl.findEntryById(id);
      if (entry != null && entry.isLua && entry.ownerId == impl.id) {
        impl.offById(id);
      }
    } else if (ls.type(2) == LuaType.luaFunction) {
      // Find all refs for this function (handles duplicate registrations).
      final refs = _findRefsByFn(ls, name, 2);
      for (final ref in refs) {
        final removed = impl.eventBus.removeLuaListenerByRef(name, ref);
        if (removed) {
          ls.unRef(luaRegistryIndex, ref);
        }
        // Clean fn-map entry regardless — the ref is always a key now.
        removeFnMapEntryByRef(ls, name, ref);
      }
    }
    return 0;
  }

  /// `event.emit(name, ...)`
  static int _emit(LuaState ls) {
    final name = ls.checkString(1)!;
    final args = _collectVarArgs(ls);
    final impl = ls as LuaStateImpl;
    impl.emitSyncInternal(name, args);
    return 0;
  }

  /// `event.once(name, callback)` → returns listener id
  static int _once(LuaState ls) {
    final name = ls.checkString(1)!;
    ls.checkType(2, LuaType.luaFunction);

    final ref = _refLuaFunction(ls, 2, name);

    final impl = ls as LuaStateImpl;
    final id =
        impl.eventBus.addLuaListener(name, ref, ownerId: impl.id, once: true);

    ls.pushInteger(id);
    return 1;
  }

  /// `event.emitAsync(name, ...)`
  static Future<int> _emitAsync(LuaState ls) async {
    final name = ls.checkString(1)!;
    final args = _collectVarArgs(ls);
    final impl = ls as LuaStateImpl;
    await impl.emitAsyncInternal(name, args);
    return 0;
  }

  // ------------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------------

  /// Collect variadic arguments (everything after arg 1) as Dart values.
  static List<dynamic> _collectVarArgs(LuaState ls) {
    final n = ls.getTop();
    if (n <= 1) return const [];
    final args = <dynamic>[];
    for (int i = 2; i <= n; i++) {
      args.add(_stackToDartValue(ls, i));
    }
    return args;
  }

  /// Convert a Lua stack value to a Dart value.
  static Object? _stackToDartValue(LuaState ls, int idx) {
    switch (ls.type(idx)) {
      case LuaType.luaNil:
        return null;
      case LuaType.luaBoolean:
        return ls.toBoolean(idx);
      case LuaType.luaNumber:
        final n = ls.toNumber(idx);
        final i = ls.toIntegerX(idx);
        // Prefer integer representation when exact.
        if (i != null && i.toDouble() == n) return i;
        return n;
      case LuaType.luaString:
        return ls.toStr(idx);
      default:
        // For tables, functions, userdata, etc. return a sentinel string.
        return '<${ls.type(idx).name}>';
    }
  }

  // ------------------------------------------------------------------
  // Fn-map helpers (per-event {fn → ref} stored in registry)
  // ------------------------------------------------------------------

  /// Ensure the fn-map table exists in the registry.
  static void _ensureFnMap(LuaState ls) {
    ls.getField(luaRegistryIndex, fnMapKey);
    if (ls.isNil(-1)) {
      ls.pop(1);
      ls.createTable(0, 4);
      ls.pushValue(-1);
      ls.setField(luaRegistryIndex, fnMapKey);
    }
    ls.pop(1);
  }

  /// Ref the Lua function at [fnIdx] and store it in the fn-map.
  /// Returns the registry ref.
  static int _refLuaFunction(LuaState ls, int fnIdx, String event) {
    // Push a copy of the function and ref it.
    ls.pushValue(fnIdx);
    final ref = ls.ref(luaRegistryIndex);

    // fnMap[event][ref] = fn.  Ensure the fn-map exists.
    _ensureFnMap(ls);
    ls.getField(luaRegistryIndex, fnMapKey);
    ls.getField(-1, event);
    if (ls.isNil(-1)) {
      ls.pop(1);
      ls.createTable(0, 4);
      ls.pushValue(-1);
      ls.setField(-3, event);
    }
    // Stack: fnMap, eventTable
    ls.pushInteger(ref); // key: the ref (always unique — no collision)
    ls.pushValue(fnIdx); // value: the function itself
    ls.setTable(-3); // eventTable[ref] = fn
    ls.pop(2); // pop eventTable, fnMap

    return ref;
  }

  /// Find all registry refs for the Lua function at stack index [fnIdx]
  /// registered under [event].  Returns empty list if none found.
  ///
  /// Iterates the per-event table in the fn-map (keyed by ref) and collects
  /// every ref whose value (the stored Lua function) matches via raw equality.
  /// The fn-map is not modified; the Lua stack is restored on return.
  static List<int> _findRefsByFn(LuaState ls, String event, int fnIdx) {
    final refs = <int>[];
    // Read-only: don't recreate the fn-map just to look something up.
    ls.getField(luaRegistryIndex, fnMapKey);
    if (ls.isNil(-1)) {
      ls.pop(1);
      return refs;
    }
    ls.getField(-1, event);
    if (ls.isNil(-1)) {
      ls.pop(2);
      return refs;
    }
    // Stack: fnMap, eventTable
    ls.pushNil(); // first key for lua_next
    while (ls.next(-2)) {
      // Stack: fnMap, eventTable, key (ref), value (fn)
      if (ls.rawEqual(-1, fnIdx)) {
        if (ls.type(-2) == LuaType.luaNumber) {
          refs.add(ls.toInteger(-2));
        }
      }
      ls.pop(1); // pop value, keep key for next iteration
    }
    ls.pop(2); // pop eventTable, fnMap
    return refs;
  }

  /// Remove the fn-map entry for the given [ref] under [event].
  ///
  /// Because the fn-map is now keyed by ref (`eventTable[ref] = fn`), this
  /// is a direct `nil` write — no iteration required.  Used when a Lua
  /// listener is removed by its listener id rather than by its function
  /// reference.
  static void removeFnMapEntryByRef(LuaState ls, String event, int ref) {
    ls.getField(luaRegistryIndex, fnMapKey);
    if (ls.isNil(-1)) {
      ls.pop(1);
      return;
    }
    ls.getField(-1, event);
    if (ls.isNil(-1)) {
      ls.pop(2);
      return;
    }
    // Stack: fnMap, eventTable
    ls.pushInteger(ref);
    ls.pushNil();
    ls.setTable(-3); // eventTable[ref] = nil
    ls.pop(2); // pop eventTable, fnMap
  }
}
