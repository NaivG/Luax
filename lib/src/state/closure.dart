import '../api/lua_type.dart';
import '../binchunk/binary_chunk.dart';
import '../gc/garbage_collector.dart';
import '../gc/gc_object.dart';
import 'upvalue_holder.dart';

class Closure with GCObject {
  final Prototype? proto;
  final DartFunction? dartFunc;
  final DartFunctionAsync? dartFuncAsync;

  /// Optional human-readable name for the closure. Used by host-registered
  /// async functions so the "attempt to call async function `name` without
  /// await or in non-async context" error message can name the symbol that
  /// was called.
  final String? name;
  final List<UpvalueHolder?> upvals;

  /// Number of expected results for coroutine support
  int nResults = 0;

  Closure(Prototype this.proto)
      : dartFunc = null,
        dartFuncAsync = null,
        name = null,
        upvals = List<UpvalueHolder?>.filled(proto.upvalues.length, null) {
    LuaGarbageCollector.current?.register(this);
  }

  Closure.DartFunc(this.dartFunc, int nUpvals)
      : proto = null,
        dartFuncAsync = null,
        name = null,
        upvals = List<UpvalueHolder?>.filled(nUpvals, null) {
    LuaGarbageCollector.current?.register(this);
  }

  Closure.DartFuncAsync(this.name, this.dartFuncAsync, int nUpvals)
      : proto = null,
        dartFunc = null,
        upvals = List<UpvalueHolder?>.filled(nUpvals, null) {
    LuaGarbageCollector.current?.register(this);
  }

  /// Whether this closure wraps an async Dart function.
  bool get isAsync => dartFuncAsync != null;

  /// Whether this closure wraps a sync Dart function.
  bool get isDartFunc => dartFunc != null;

  /// Whether this closure is a Lua function.
  bool get isLuaFunc => proto != null;

  // ── GCObject implementation ──────────────────────────────────────

  @override
  int get estimatedSize {
    int size = 80; // object header + field pointers
    if (proto != null) {
      size += 128; // Prototype base overhead
      size += proto!.code.length * 4; // Uint32List
      size += proto!.constants.length * 8;
      size += proto!.upvalues.length * 16;
      size += proto!.protos.length * 8;
      if (proto!.lineInfo.isNotEmpty) {
        size += proto!.lineInfo.length * 4;
      }
    }
    size += upvals.length * 16;
    return size < 32 ? 32 : size;
  }

  @override
  void traceReferences(void Function(GCObject obj) visit) {
    // Trace upvalue values.
    for (final uv in upvals) {
      if (uv != null) {
        final val = uv.get();
        if (val is GCObject) visit(val);
      }
    }

    // Trace table/function constants in this prototype and all
    // sub-prototypes (sub-protos are created lazily by CLOSURE
    // instructions but their constants must stay alive).
    if (proto != null) {
      _tracePrototype(proto!, visit);
    }
  }

  static void _tracePrototype(Prototype p, void Function(GCObject obj) visit) {
    for (final c in p.constants) {
      if (c is GCObject) visit(c);
    }
    for (final sub in p.protos) {
      if (sub != null) _tracePrototype(sub, visit);
    }
  }
}
