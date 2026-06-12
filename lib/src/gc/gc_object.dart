/// Mixin for objects tracked by the Lua garbage collector.
///
/// Mixed into [LuaTable], [Closure], [Userdata], and [LuaStateImpl] (threads).
/// Provides tri-color marking state and a visitor interface for the mark phase.
mixin GCObject {
  /// Tri-color mark state: 'w' = white, 'g' = gray, 'b' = black.
  String _gcColor = 'w';

  bool get isWhite => _gcColor == 'w';
  bool get isGray => _gcColor == 'g';
  bool get isBlack => _gcColor == 'b';

  void markWhite() {
    _gcColor = 'w';
  }

  void markGray() {
    _gcColor = 'g';
  }

  void markBlack() {
    _gcColor = 'b';
  }

  /// Estimated memory footprint in bytes (used for GC pacing).
  int get estimatedSize;

  /// Visit every [GCObject] directly referenced by this object.
  ///
  /// The [visit] callback is invoked once per child; the mark phase uses it
  /// to enqueue newly discovered white objects into the gray queue.
  void traceReferences(void Function(GCObject obj) visit);
}
