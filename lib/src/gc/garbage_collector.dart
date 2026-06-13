import '../state/closure.dart';
import '../state/lua_state_impl.dart';
import '../state/lua_table.dart';
import '../state/lua_userdata.dart';
import '../api/lua_type.dart';
import 'gc_constants.dart';
import 'gc_object.dart';

/// Phases of the garbage collection cycle.
///
/// The collector operates as an incremental state machine:
/// ```
/// pause ──▶ markPropagate ──▶ sweep ──▶ finalize ──▶ pause
/// ```
/// Each phase can be entered and exited across multiple [step] calls.
enum GcPhase {
  /// Idle between cycles.
  pause,

  /// Incrementally propagating gray marks.
  markPropagate,

  /// Incrementally sweeping unmarked objects.
  sweep,

  /// Running `__gc` finalizers.
  finalize,
}

// ── Lua 5.3 mode constants (for API compatibility) ──────────────────

/// Incremental mode (the only mode implemented).
const int luaGcInc = 0;

/// Generational mode (accepted but treated as incremental).
/// I guess... whatever. Would anyone use this?
/// 
/// TODO: Implement generational mode. And maybe a few other things.
const int luaGcGen = 1;

/// A Lua-level incremental garbage collector with `__gc` finalizer support
/// and the `collectgarbage()` API.
///
/// Cooperates with Dart's GC rather than replacing it:
/// - Dart handles actual memory reclamation.
/// - This collector tracks Lua-level reachability, runs `__gc` finalizers,
///   and provides memory accounting.
///
/// ## Incremental state machine
///
/// The collector is driven by allocation *debt*.  Each registered object
/// adds to the debt; when the debt exceeds zero the VM loop calls [checkDebt],
/// which advances the state machine by one [step].  This spreads GC work
/// across many small increments instead of one large pause.
class LuaGarbageCollector {
  /// The currently active GC instance.
  ///
  /// Set in [LuaStateImpl]'s constructor and during VM execution so that
  /// newly created [GCObject] instances can auto-register themselves.
  static LuaGarbageCollector? current;

  /// The owning Lua state.
  final LuaStateImpl _state;

  // ── Object tracking ────────────────────────────────────────────────

  final Set<GCObject> _allObjects = {};

  /// Objects awaiting `__gc` finalization.
  final List<GCObject> _tobefnz = [];

  /// Tables with weak references (`__mode`).
  ///
  /// Registered when [setmetatable] is called with a metatable that has
  /// a `__mode` field. Cleaned during the sweep phase to remove entries
  /// whose weakly-referenced keys/values have become unreachable.
  final List<LuaTable> _weakTables = [];

  // ── Incremental mark state ─────────────────────────────────────────

  /// Gray queue for the incremental mark phase.
  final List<GCObject> _gray = [];

  // ── Incremental sweep state ────────────────────────────────────────

  /// Snapshot of [_allObjects] taken at the start of sweep.
  /// Iterated incrementally so the sweep can be paused and resumed.
  List<GCObject> _sweepList = [];
  int _sweepIndex = 0;

  // ── GC state ───────────────────────────────────────────────────────
  GcPhase _phase = GcPhase.pause;
  bool _running = true;

  // ── Tuning ─────────────────────────────────────────────────────────
  int _pause = GcConstants.defaultPause;
  int _stepMul = GcConstants.defaultStepMul;
  double _totalBytes = 0;
  double _gcDebt = 0;
  double _lastSurvived = 0;

  // ── Counters ───────────────────────────────────────────────────────
  int _cycleCount = 0;
  int _stepCount = 0;

  LuaGarbageCollector(this._state);

  // ── Public getters ─────────────────────────────────────────────────

  GcPhase get phase => _phase;
  bool get isRunning => _running;
  double get totalBytes => _totalBytes;
  int get objectCount => _allObjects.length;
  int get cycleCount => _cycleCount;
  int get stepCount => _stepCount;

  int get pause => _pause;
  set pause(int v) => _pause = v;

  int get stepMul => _stepMul;
  set stepMul(int v) => _stepMul = v;

  // ── Object registration ────────────────────────────────────────────

  /// Register a newly created object for GC tracking.
  ///
  /// Called automatically by the constructors of [LuaTable], [Closure],
  /// [Userdata], and [LuaStateImpl] via [LuaGarbageCollector.current].
  void register(GCObject obj) {
    if (_allObjects.add(obj)) {
      final size = obj.estimatedSize;
      _totalBytes += size;
      _gcDebt += size;
    }
  }

  /// Register a table as having weak references.
  ///
  /// Called from [LuaStateImpl._setMetatable] when the metatable contains
  /// a `__mode` field. The [mode] string should be one of `'k'`, `'v'`,
  /// or `'kv'`.
  void registerWeakTable(LuaTable table, String mode) {
    table.weakMode = mode;
    if (!_weakTables.contains(table)) {
      _weakTables.add(table);
    }
  }

  /// Unregister a table from weak table tracking.
  ///
  /// Called when [setmetatable] is called with `nil` or a metatable
  /// that has no `__mode` field.
  void unregisterWeakTable(LuaTable table) {
    table.weakMode = null;
    _weakTables.remove(table);
  }

  // ── Collection control ─────────────────────────────────────────────

  /// Stop automatic collection.
  void stop() {
    _running = false;
  }

  /// Restart automatic collection.
  ///
  /// Resumes the automatic collector; does **not** force a full collection cycle.
  void restart() {
    _running = true;
  }

  /// Run a complete mark → sweep → finalize cycle synchronously.
  ///
  /// If a cycle is already in progress it is first completed, then a
  /// fresh full cycle is executed.  This is what `collectgarbage("collect")`
  /// maps to.
  void fullCycle() {
    _stepCount++;

    // Complete any in-progress incremental cycle.
    if (_phase != GcPhase.pause) {
      _completeCycle();
    }
    // Start and complete a fresh full cycle.
    _startMark();
    _markStep(_unlimitedWork);
    _startSweep();
    _sweepStep(_unlimitedWork);
    _runFinalize();
    _cycleCount++;
  }

  /// A very large work value used for full-cycle operations like [fullCycle].
  /// This SHOULD PROBABLY be larger than any reasonable amount of work.
  static const double _unlimitedWork = 1e18;

  /// Perform one incremental step.
  ///
  /// [amount] controls how much work to do in this step (0 = automatic).
  /// Returns `true` if the step completed a full cycle (i.e. we returned
  /// to [GcPhase.pause]).
  bool step([int amount = 0]) {
    if (!_running) return false;

    final work = amount > 0
        ? amount * 1024.0
        : _gcDebt * _stepMul / 100;

    _gcDebt = 0;

    final clampedWork = work.clamp(
      GcConstants.minStepWork.toDouble(),
      double.maxFinite ~/ 2,
    ) as double;
    return _stepInternal(clampedWork);
  }

  /// Called from the VM instruction loop to check GC debt.
  void checkDebt() {
    if (!_running) return;
    if (_gcDebt <= 0) return;

    final work = (_gcDebt * _stepMul / 100).clamp(
      GcConstants.minStepWork.toDouble(),
      double.maxFinite ~/ 2,
    ) as double;
    _gcDebt = 0;

    _stepInternal(work);
  }

  // ── Internal step state machine ────────────────────────────────────

  bool _stepInternal(double work) {
    _stepCount++;
    final prevPhase = _phase;

    switch (_phase) {
      case GcPhase.pause:
        // Check whether enough memory has been allocated to start a new cycle.
        if (_totalBytes >= _lastSurvived * _pause / 100) {
          _startMark();
          _markStep(work);
        } else {
          return false;
        }
        break;
      case GcPhase.markPropagate:
        _markStep(work);
        break;
      case GcPhase.sweep:
        _sweepStep(work);
        break;
      case GcPhase.finalize:
        _runFinalize();
        break;
    }

    // Return true if we completed a cycle (transitioned back to pause).
    return prevPhase != GcPhase.pause && _phase == GcPhase.pause;
  }

  /// Complete whatever cycle is currently in progress.
  void _completeCycle() {
    while (_phase != GcPhase.pause) {
      _stepInternal(_unlimitedWork);
    }
  }

  // ── Mark phase ─────────────────────────────────────────────────────

  /// Initialize the mark phase: reset all colors and seed the gray queue.
  void _startMark() {
    _phase = GcPhase.markPropagate;
    _gray.clear();

    // Reset every tracked object to white.
    for (final obj in _allObjects) {
      obj.markWhite();
    }

    // ── Seed roots ───────────────────────────────────────────────────

    // 1. Registry table (shared by all threads).
    _enqueueRoot(_state.registry);

    // 2. All non-dead threads.
    //
    //    In Lua 5.3, suspended/running/normal coroutines are GC roots —
    //    they cannot be collected regardless of whether they are reachable
    //    from the object graph.  Dead coroutines are not roots.
    for (final obj in _allObjects) {
      if (obj is LuaStateImpl && obj.status != ThreadStatus.luaDead) {
        _enqueueRoot(obj);
      }
    }
  }

  void _enqueueRoot(Object? val) {
    if (val is GCObject && val.isWhite) {
      val.markGray();
      _gray.add(val);
    }
  }

  /// Propagate gray marks through the object graph.
  ///
  /// Processes gray objects from the queue until the queue is empty or
  /// [work] units have been consumed.  Returns `true` when the gray queue
  /// is fully drained (i.e. propagation is complete).
  bool _propagateGray(double work) {
    double remaining = work;

    while (_gray.isNotEmpty && remaining > 0) {
      final obj = _gray.removeLast();
      if (!obj.isGray) continue; // already processed (e.g. re-enqueued)

      obj.markBlack();
      remaining -= obj.estimatedSize;

      // Trace children: white children become gray.
      obj.traceReferences((child) {
        if (child.isWhite) {
          child.markGray();
          _gray.add(child);
        }
      });
    }

    return _gray.isEmpty;
  }

  /// Incremental mark propagation.
  ///
  /// Processes gray objects from the queue until the queue is empty or
  /// [work] units have been consumed.
  void _markStep(double work) {
    if (_propagateGray(work)) {
      // Mark phase complete → transition to sweep.
      _startSweep();
    }
  }

  // ── Sweep phase ────────────────────────────────────────────────────

  /// Initialize the sweep phase: clean weak tables, snapshot the object
  /// set, and start iterating from the beginning.
  void _startSweep() {
    _phase = GcPhase.sweep;

    // Clean weak tables BEFORE sweeping: remove entries whose weakly-
    // referenced keys/values are still white (unreachable).
    _cleanWeakTables();

    _sweepList = _allObjects.toList();
    _sweepIndex = 0;
  }

  // ── Weak table cleanup ──────────────────────────────────────────────

  /// Clean all weak tables before the sweep phase.
  ///
  /// For each reachable weak table, removes entries whose weakly-referenced
  /// keys and/or values are still white (unreachable). Unreachable weak
  /// tables are removed from the tracking list.
  void _cleanWeakTables() {
    for (int i = _weakTables.length - 1; i >= 0; i--) {
      final table = _weakTables[i];

      // If the weak table itself is unreachable, remove it from tracking.
      // It will be handled by the sweep phase (moved to tobefnz or removed).
      if (table.isWhite) {
        _weakTables.removeAt(i);
        continue;
      }

      // Clean weak references in reachable tables.
      if (table.hasWeakKeys) {
        _cleanWeakKeys(table);
      }
      if (table.hasWeakValues) {
        _cleanWeakValues(table);
      }
    }
  }

  /// Remove entries from [table]'s hash map whose keys are unreachable
  /// (white) GCObjects.
  void _cleanWeakKeys(LuaTable table) {
    if (table.map == null) return;
    table.map!.removeWhere((key, value) {
      return key is GCObject && key.isWhite;
    });
    table.changed = true;
  }

  /// Remove entries from [table] whose values are unreachable (white)
  /// GCObjects. Handles both the array part and the hash map part.
  void _cleanWeakValues(LuaTable table) {
    // Clean array part: null out weak values that are unreachable.
    if (table.arr != null) {
      for (int i = 0; i < table.arr!.length; i++) {
        final v = table.arr![i];
        if (v is GCObject && v.isWhite) {
          table.arr![i] = null;
        }
      }
      // Only remove TRAILING nulls. Unlike shrinkArray() which removes
      // ALL null entries, we must preserve interior nulls to maintain
      // the correct index mapping (Lua index i → arr[i-1]).
      while (table.arr!.isNotEmpty && table.arr!.last == null) {
        table.arr!.removeLast();
      }
    }
    // Clean map part: remove entries whose values are unreachable.
    if (table.map != null) {
      table.map!.removeWhere((key, value) {
        return value is GCObject && value.isWhite;
      });
    }
    table.changed = true;
  }

  /// Incremental sweep.
  ///
  /// Processes objects from [_sweepList] until the list is exhausted or
  /// [work] units have been consumed.
  void _sweepStep(double work) {
    double remaining = work;
    final dead = <GCObject>[];

    while (_sweepIndex < _sweepList.length && remaining > 0) {
      final obj = _sweepList[_sweepIndex++];

      // Skip objects that were already removed from _allObjects
      // (e.g. by a previous sweep step or an explicit unregister).
      if (!_allObjects.contains(obj)) continue;

      remaining -= obj.estimatedSize;

      if (obj.isWhite) {
        // Unreachable.
        dead.add(obj);
      } else {
        // Reachable — reset to white for the next cycle.
        obj.markWhite();
      }
    }

    // Process dead objects found in this step.
    _processDead(dead);

    if (_sweepIndex >= _sweepList.length) {
      // Sweep complete.
      _afterSweep();
    }
  }

  /// Separate dead objects into finalizable (→ tobefnz) and reclaimable.
  void _processDead(List<GCObject> dead) {
    for (final obj in dead) {
      if (_hasGcMetamethod(obj)) {
        _tobefnz.add(obj);
        // Keep the object alive during finalization.
        // It stays in _allObjects; __gc may resurrect it.
      } else {
        _allObjects.remove(obj);
        _totalBytes -= obj.estimatedSize;
      }
    }
  }

  /// Compute survived bytes and transition out of sweep.
  void _afterSweep() {
    // ── Re-mark from tobefnz objects ─────────────────────────────────
    //
    // Lua 5.3 §2.5.3: objects with __gc that are about to be finalized
    // are "resurrected" — they and everything they reference must be
    // kept alive so the finalizer can safely access their fields,
    // metatables, and closure upvalues.
    if (_tobefnz.isNotEmpty) {
      // Seed the gray queue with the tobefnz objects.
      for (final obj in _tobefnz) {
        if (obj.isWhite) {
          obj.markGray();
          _gray.add(obj);
        }
      }
      // Propagate marks through everything reachable from tobefnz.
      _propagateGray(_unlimitedWork);
    }

    // Compute survived bytes.
    _lastSurvived = 0;
    for (final obj in _allObjects) {
      _lastSurvived += obj.estimatedSize;
    }

    _sweepList = [];
    _sweepIndex = 0;

    if (_tobefnz.isNotEmpty) {
      _phase = GcPhase.finalize;
    } else {
      _phase = GcPhase.pause;
      _cycleCount++;
    }
  }

  // ── Finalize phase ─────────────────────────────────────────────────

  /// Execute all pending `__gc` metamethods.
  ///
  /// Objects are finalized in reverse order of detection (LIFO), matching
  /// Lua 5.3's behavior where the most recently created objects are
  /// finalized first.
  void _runFinalize() {
    _phase = GcPhase.finalize;

    while (_tobefnz.isNotEmpty) {
      final obj = _tobefnz.removeLast();
      _callGcMetamethod(obj);
      // After __gc runs, the object stays in _allObjects.
      // If Lua code re-references it, it survives the next cycle.
      // If it becomes unreachable again, it will be collected and
      // finalized again (Lua 5.3 does NOT mark objects as "already finalized").
    }

    _phase = GcPhase.pause;
    _cycleCount++;
  }

  // ── __gc helpers ───────────────────────────────────────────────────

  bool _hasGcMetamethod(GCObject obj) {
    final mt = _getMetatableOf(obj);
    if (mt == null) return false;
    return mt.get('__gc') != null;
  }

  void _callGcMetamethod(GCObject obj) {
    try {
      final mt = _getMetatableOf(obj);
      if (mt == null) return;
      final gcFn = mt.get('__gc');
      if (gcFn is! Closure) return;

      _state.pushObjectRaw(gcFn);
      _state.pushObjectRaw(obj);
      _state.pCall(1, 0, 0);
    } catch (e) {
      // Errors in __gc are silently caught (matches Lua 5.3 behavior).
      // ignore: avoid_print
      print('warning: error in __gc metamethod: $e');
    }
  }

  LuaTable? _getMetatableOf(GCObject obj) {
    if (obj is LuaTable) return obj.metatable;
    if (obj is Userdata) return obj.metatable;
    // Closures and threads do not have per-instance metatables.
    // Lua 5.3 only supports __gc on tables and userdata.
    return null;
  }

  // ── Info / stats ───────────────────────────────────────────────────

  /// Returns a map of GC statistics for `collectgarbage("info")`.
  Map<String, Object> info() {
    return {
      'count': _totalBytes / 1024, // KB
      'collectbytes': _totalBytes,
      'pause': _pause,
      'stepmul': _stepMul,
      'steps': _stepCount,
      'collections': _cycleCount,
      'objects': _allObjects.length,
      'tobefnz': _tobefnz.length,
      'weaktables': _weakTables.length,
      'isrunning': _running,
      'mode': _running ? 'incremental' : 'stopped',
      'phase': _phase.name,
    };
  }
}
