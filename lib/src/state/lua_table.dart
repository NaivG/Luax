import 'dart:collection';

import '../gc/garbage_collector.dart';
import '../gc/gc_object.dart';
import '../number/lua_number.dart';

class LuaTable with GCObject {
  /// 元表
  LuaTable? metatable;
  List<Object?>? arr;
  Map<Object?, Object>? map;

  // used by next()
  Map<Object?, Object?>? keys;
  Object? lastKey;
  late bool changed;

  /// Weak reference mode, null means non-weak table.
  /// 'k' = weak keys, 'v' = weak values, 'kv' = both.
  ///
  /// Set when [setmetatable] is called with a metatable containing `__mode`.
  /// Matches Lua 5.3 behavior: the mode is captured at setmetatable time,
  /// subsequent changes to the metatable's __mode field do not affect
  /// the table's weak status.
  String? weakMode;

  /// Whether this table has weak keys.
  bool get hasWeakKeys => weakMode != null && weakMode!.contains('k');

  /// Whether this table has weak values.
  bool get hasWeakValues => weakMode != null && weakMode!.contains('v');

  LuaTable(int nArr, int nRec) {
    if (nArr > 0) {
      arr = <Object?>[];
    }
    if (nRec > 0) {
      map = HashMap<Object?, Object>();
    }
    LuaGarbageCollector.current?.register(this);
  }

  bool hasMetafield(String fieldName) {
    return metatable != null && metatable!.get(fieldName) != null;
  }

  int length() {
    return arr == null ? 0 : arr!.length;
  }

  Object? get(Object? key) {
    key = floatToInteger(key);

    if (arr != null && key is int) {
      int idx = key;
      if (idx >= 1 && idx <= arr!.length) {
        return arr![idx - 1];
      }
    }

    return map != null ? map![key] : null;
  }

  void put(Object? key, Object? val) {
    if (key == null) {
      throw Exception("table index is nil!");
    }
    if (key is double && key.isNaN) {
      throw Exception("table index is NaN!");
    }
    changed = true;
    key = floatToInteger(key);
    if (key is int) {
      int idx = key;
      if (idx >= 1) {
        if (arr == null) {
          arr = <Object?>[];
        }

        int arrLen = arr!.length;
        if (idx <= arrLen) {
          arr![idx - 1] = val;
          if (idx == arrLen && val == null) {
            shrinkArray();
          }
          return;
        }
        if (idx == arrLen + 1) {
          if (map != null) {
            map!.remove(key);
          }
          if (val != null) {
            arr!.add(val);
            expandArray();
          }
          return;
        }
      }
    }

    if (val != null) {
      if (map == null) {
        map = HashMap<Object?, Object>();
      }
      map![key] = val;
    } else {
      if (map != null) {
        map!.remove(key);
      }
    }
  }

  Object? floatToInteger(Object? key) {
    if (key is double) {
      double f = key;
      if (LuaNumber.isInteger(f)) {
        return f.toInt();
      }
    }
    return key;
  }

  void shrinkArray() {
    for (int i = arr!.length - 1; i >= 0; i--) {
      if (arr![i] == null) {
        arr!.removeAt(i);
      }
    }
  }

  void expandArray() {
    if (map != null) {
      for (int idx = arr!.length + 1;; idx++) {
        Object? val = map!.remove(idx);
        if (val != null) {
          arr!.add(val);
        } else {
          break;
        }
      }
    }
  }

  Object? nextKey(Object? key) {
    if (keys == null || (key == null && changed)) {
      initKeys();
      changed = false;
    }

    Object? nextKey = keys![key];
    if (nextKey == null && key != null && key != lastKey) {
      throw Exception("invalid key to 'next'");
    }

    return nextKey;
  }

  void initKeys() {
    if (keys == null) {
      keys = HashMap<Object?, Object?>();
    } else {
      keys!.clear();
    }
    Object? key = null;
    if (arr != null) {
      for (int i = 0; i < arr!.length; i++) {
        if (arr![i] != null) {
          int nextKey = i + 1;
          keys![key] = nextKey;
          key = nextKey;
        }
      }
    }
    if (map != null) {
      for (Object? k in map!.keys) {
        Object? v = map![k];
        if (v != null) {
          keys![key] = k;
          key = k;
        }
      }
    }
    lastKey = key;
  }

  // ── GCObject implementation ──────────────────────────────────────

  @override
  int get estimatedSize {
    int size = 64; // object header + field pointers
    if (arr != null) size += 24 + arr!.length * 8;
    if (map != null) size += 48 + map!.length * 32;
    if (keys != null) size += 48 + keys!.length * 16;
    return size < 32 ? 32 : size;
  }

  @override
  void traceReferences(void Function(GCObject obj) visit) {
    // Metatable is always a strong reference.
    if (metatable != null) visit(metatable!);

    // Array values: skip if values are weak.
    if (arr != null && !hasWeakValues) {
      for (final v in arr!) {
        if (v is GCObject) visit(v);
      }
    }

    // Hash map: skip keys and/or values according to weak mode.
    if (map != null) {
      for (final entry in map!.entries) {
        if (!hasWeakKeys && entry.key is GCObject) {
          visit(entry.key as GCObject);
        }
        if (!hasWeakValues && entry.value is GCObject) {
          visit(entry.value as GCObject);
        }
      }
    }
  }
}
