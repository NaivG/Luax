/// Mixin for objects tracked by the Lua garbage collector.
///
/// Mixed into [LuaTable], [Closure], [Userdata], and [LuaStateImpl] (threads).
/// Provides tri-color marking state and a visitor interface for the mark phase.
mixin GCObject {
  // Tri-color mark constants
  // 2-bit value, for memory efficiency - why not? :D
  static const int _white = 0;
  static const int _gray = 1;
  static const int _black = 2;

  /// Tri-color mark state: 0 = white, 1 = gray, 2 = black.
  int _gcColor = _white;

  bool get isWhite => _gcColor == _white;
  bool get isGray => _gcColor == _gray;
  bool get isBlack => _gcColor == _black;

  void markWhite() {
    _gcColor = _white;
  }

  void markGray() {
    _gcColor = _gray;
  }

  void markBlack() {
    _gcColor = _black;
  }

  /// Estimated memory footprint in bytes (used for GC pacing).
  int get estimatedSize;

  /// Visit every [GCObject] directly referenced by this object.
  ///
  /// The [visit] callback is invoked once per child; the mark phase uses it
  /// to enqueue newly discovered white objects into the gray queue.
  void traceReferences(void Function(GCObject obj) visit);
}
