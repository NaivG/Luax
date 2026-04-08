import '../api/lua_state.dart';
import 'closure.dart';
import 'lua_state_impl.dart';
import 'lua_table.dart';
import 'upvalue_holder.dart';

class LuaStack {
  static const int _defaultCapacity = 40;
  static const int _minCapacity = 20;

  /// Virtual stack — either a fixed-capacity array with an explicit `_top`
  /// pointer, or a growable list (legacy mode, for benchmark baseline).
  List<Object?> slots;

  /// Number of values on the stack.  Only meaningful in fixed-capacity mode;
  /// in growable mode [slots.length] is used instead.
  int _top;

  /// Whether this stack uses the optimised fixed-capacity representation.
  final bool _fixed;

  /// call info
  late LuaStateImpl state;
  Closure? closure;
  List<Object?>? varargs;
  Map<int?, UpvalueHolder?>? openuvs;

  /// Program Counter
  int pc = 0;

  /// linked list
  LuaStack? prev;

  /// Creates a fixed-capacity stack (optimised).
  ///
  /// [capacity] is the initial slot count; the array will grow automatically
  /// if more space is needed, but starting at the right size avoids resizes
  /// on the hot path.
  LuaStack([int capacity = _defaultCapacity])
      : _fixed = true,
        slots = List<Object?>.filled(
            capacity < _minCapacity ? _minCapacity : capacity, null),
        _top = 0;

  /// Creates a growable-list stack (original behaviour).
  ///
  /// Used only as a benchmark baseline via [LuaStateImpl.useFixedStack].
  LuaStack.growable()
      : _fixed = false,
        slots = [],
        _top = 0;

  int top() => _fixed ? _top : slots.length;

  // ── Core push / pop ──────────────────────────────────────────────────

  void push(Object? val) {
    if (_fixed) {
      if (_top >= 10000) throw StackOverflowError();
      if (_top >= slots.length) _grow(_top + 1);
      slots[_top++] = val;
    } else {
      if (slots.length > 10000) throw StackOverflowError();
      slots.add(val);
    }
  }

  Object? pop() {
    if (_fixed) {
      final val = slots[--_top];
      slots[_top] = null; // allow GC
      return val;
    } else {
      return slots.removeAt(slots.length - 1);
    }
  }

  void pushN(List<Object?>? vals, int n) {
    int nVals = vals == null ? 0 : vals.length;
    if (n < 0) n = nVals;
    if (_fixed) {
      _ensureCapacity(_top + n);
      for (int i = 0; i < n; i++) {
        slots[_top++] = i < nVals ? vals![i] : null;
      }
    } else {
      for (int i = 0; i < n; i++) {
        push(i < nVals ? vals![i] : null);
      }
    }
  }

  List<Object?> popN(int n) {
    if (_fixed) {
      // Single allocation, filled back-to-front — no reversal needed.
      final vals = List<Object?>.filled(n, null);
      for (int i = n - 1; i >= 0; i--) {
        vals[i] = slots[--_top];
        slots[_top] = null;
      }
      return vals;
    } else {
      List<Object?> vals = <Object?>[];
      for (int i = 0; i < n; i++) {
        vals.add(pop());
      }
      return vals.reversed.toList();
    }
  }

  /// Discards [n] values from the top without returning them.
  ///
  /// More efficient than calling [pop] in a loop when the values are not
  /// needed (e.g. [LuaStateImpl.pop]).
  void popDiscard(int n) {
    if (_fixed) {
      for (int i = 0; i < n; i++) {
        slots[--_top] = null;
      }
    } else {
      for (int i = 0; i < n; i++) {
        slots.removeAt(slots.length - 1);
      }
    }
  }

  /// Sets the logical stack top to [newTop], growing or shrinking as needed.
  ///
  /// Replaces the push/pop loops in [LuaStateImpl.setTop] with a single
  /// operation.
  void setTopDirect(int newTop) {
    if (_fixed) {
      if (newTop > _top) {
        _ensureCapacity(newTop);
        // New slots are already null from _grow / initial fill.
        // Null them out defensively in case of stale values from a prior frame.
        for (int i = _top; i < newTop; i++) {
          slots[i] = null;
        }
      } else {
        for (int i = newTop; i < _top; i++) {
          slots[i] = null;
        }
      }
      _top = newTop;
    } else {
      if (newTop > slots.length) {
        for (int i = slots.length; i < newTop; i++) {
          slots.add(null);
        }
      } else if (newTop < slots.length) {
        slots.length = newTop;
      }
    }
  }

  // ── Index helpers ────────────────────────────────────────────────────

  int absIndex(int idx) {
    return idx >= 0 || idx <= luaRegistryIndex ? idx : idx + top() + 1;
  }

  bool isValid(int idx) {
    if (idx < luaRegistryIndex) {
      /* upvalues */
      int uvIdx = luaRegistryIndex - idx - 1;
      return closure != null && uvIdx < closure!.upvals.length;
    }

    if (idx == luaRegistryIndex) {
      return true;
    }
    int absIdx = absIndex(idx);
    return absIdx > 0 && absIdx <= top();
  }

  Object? get(int idx) {
    if (idx < luaRegistryIndex) {
      /* upvalues */
      int uvIdx = luaRegistryIndex - idx - 1;
      if (closure != null &&
          closure!.upvals.length > uvIdx &&
          closure!.upvals[uvIdx] != null) {
        return closure!.upvals[uvIdx]!.get();
      } else {
        return null;
      }
    }

    if (idx == luaRegistryIndex) {
      return state.registry;
    }
    int absIdx = absIndex(idx);
    if (absIdx > 0 && absIdx <= top()) {
      return slots[absIdx - 1];
    } else {
      return null;
    }
  }

  void set(int idx, Object? val) {
    if (idx < luaRegistryIndex) {
      /* upvalues */
      int uvIdx = luaRegistryIndex - idx - 1;
      if (closure != null &&
          closure!.upvals.length > uvIdx &&
          closure!.upvals[uvIdx] != null) {
        closure!.upvals[uvIdx]!.set(val);
      }
      return;
    }

    if (idx == luaRegistryIndex) {
      state.registry = (val as LuaTable?);
      return;
    }
    int absIdx = absIndex(idx);
    slots[absIdx - 1] = val;
  }

  void reverse(int from, int to) {
    var obj;
    for (; from < to; from++, to--) {
      obj = slots[from];
      slots[from] = slots[to];
      slots[to] = obj;
    }
  }

  // ── Capacity management (fixed mode only) ────────────────────────────

  /// Ensures the backing array can hold at least [needed] elements.
  void _ensureCapacity(int needed) {
    if (needed <= slots.length) return;
    _grow(needed);
  }

  void _grow(int needed) {
    int newCap = slots.length == 0 ? _minCapacity : slots.length;
    do {
      newCap *= 2;
    } while (newCap < needed);
    final newSlots = List<Object?>.filled(newCap, null);
    for (int i = 0; i < _top; i++) {
      newSlots[i] = slots[i];
    }
    slots = newSlots;
  }

  // ── Debug / error helpers ────────────────────────────────────────────

  /// Fix #33: Get current source line number for error messages
  /// Returns the line number corresponding to the current instruction (pc),
  /// or null if line info is not available.
  int? getCurrentLine() {
    if (closure?.proto != null && pc > 0 && pc <= closure!.proto!.lineInfo.length) {
      return closure!.proto!.lineInfo[pc - 1];
    }
    return null;
  }

  /// Fix #33: Get source file name for error messages
  String? getSource() {
    return closure?.proto?.source;
  }

  /// Fix #33: Format error message with line number
  String formatError(String message) {
    final line = getCurrentLine();
    final source = getSource() ?? 'unknown';
    if (line != null) {
      return '[$source:$line] $message';
    }
    return '[$source] $message';
  }
}
