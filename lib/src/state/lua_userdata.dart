import '../gc/garbage_collector.dart';
import '../gc/gc_object.dart';
import 'lua_table.dart';

/// Fix #36: Add per-instance metatable support to Userdata
/// Previously, all Userdata objects shared the same metatable via registry key,
/// which caused setting metatable on one userdata to affect all userdata.
class Userdata<T> with GCObject {

  final List<T?> _data = List.filled(1,null);

  /// Per-instance metatable, similar to LuaTable
  LuaTable? metatable;

  Userdata() {
    LuaGarbageCollector.current?.register(this);
  }

  T? get data => _data.first;

  set data(T? data)=> _data.first = data;

  // ── GCObject implementation ──────────────────────────────────────

  @override
  int get estimatedSize => 64;

  @override
  void traceReferences(void Function(GCObject obj) visit) {
    if (metatable != null) visit(metatable!);
  }
}