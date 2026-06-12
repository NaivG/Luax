// ignore_for_file: avoid_print
//
// Benchmarks the LuaDardo GC along three dimensions:
//
//   1. Aggressive vs relaxed GC tuning (pause + stepMul) under realistic
//      allocation workloads — measures the cost of incremental collection
//      while real code runs.
//
//   2. Stop-the-world fullCycle() vs incremental step() loop throughput on
//      a pre-populated heap — measures pure collector throughput.
//
//   3. With __gc finalizers vs without, on table churn — measures the
//      per-collection overhead of finalizer dispatch.
//
// Each iteration uses a fresh LuaState so measurements are hermetic:
// LuaGarbageCollector.current is reassigned on every LuaState.newState()
// (lib/src/state/lua_state_impl.dart:96-97) and counters do not leak
// across runs.
//
// Run:
//   dart run test/perf/gc_perf_test.dart
//
// With CPU profiling (prints a per-leg top-N after each run):
//   dart run --enable-vm-service test/perf/gc_perf_test.dart

import 'package:luax/lua.dart';
import 'package:luax/src/state/lua_state_impl.dart';

import 'perf_tester.dart';

// ---------------------------------------------------------------------------
// Lua workloads — each stresses a different allocation pattern.
// ---------------------------------------------------------------------------

/// Pure table churn: build, populate, drop. Tables dominate this script.
const _tableChurn = r'''
local n = 0
for i = 1, 8000 do
  local t = { i, i + 1, i + 2, i + 3, i + 4 }
  t[i] = t[1] + t[2] + t[3] + t[4] + t[5]
  n = n + t[i]
end
return n
''';

/// Heavy closure churn: every loop iteration defines a new function with
/// upvalues.  Closures are a distinct GCObject subtype from tables.
const _closureChurn = r'''
local function makeAdder(k)
  return function(x) return x + k end
end
local n = 0
for i = 1, 8000 do
  local f = makeAdder(i)
  n = n + f(i)
end
return n
''';

/// Mixed: tables nested inside tables with string keys.  The string keys
/// and the parent tables each allocate separately.
const _nestedTables = r'''
local n = 0
for i = 1, 4000 do
  local t = {
    a = {1, 2, 3, 4, 5},
    b = {x = i, y = i + 1, z = i + 2},
    c = {6, 7, 8, 9, 10},
  }
  n = n + t.b.x + t.b.y + t.b.z + t.a[5] + t.c[1]
end
return n
''';

/// String-concat churn: forces new string allocations each iteration
/// (Lua 5.3 does not intern the result of `..`) and grows the string
/// table.
const _stringChurn = r'''
local s = ""
for i = 1, 5000 do
  s = s .. tostring(i) .. ","
end
return #s
''';

/// Realistic mixed: tables + closures + strings.  The closest to a real
/// mod workload.  The final table survives, ensuring a non-trivial root
/// set so the collector has to distinguish live from dead.
const _mixedWorkload = r'''
local function build(i)
  return {
    id = i,
    name = "item" .. tostring(i),
    tags = {"a", "b", "c"},
    score = i * 7,
  }
end
local keep = {}
for i = 1, 5000 do
  keep[i] = build(i)
end
local n = 0
for _, v in ipairs(keep) do n = n + v.score end
return n
''';

// Heap-sizing scripts for Run B.  Each builds a known number of tables
// that the collector must later sweep.  All surviving tables are kept
// alive in a single root table.

const _smallHeap = r'''
local keep = {}
for i = 1, 2000 do
  keep[i] = { i, i + 1, i + 2, i + 3, i + 4 }
end
return #keep
''';

const _mediumHeap = r'''
local keep = {}
for i = 1, 10000 do
  keep[i] = { i, i + 1, i + 2, i + 3, i + 4 }
end
return #keep
''';

const _largeHeap = r'''
local keep = {}
for i = 1, 25000 do
  keep[i] = { i, i + 1, i + 2, i + 3, i + 4 }
end
return #keep
''';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Run a script in a fresh LuaState, returning the tostring of the
/// single return value (or 'nil' for no return).
String _runScript(String script) {
  final ls = LuaState.newState();
  ls.openLibs();
  ls.loadString(script);
  ls.pCall(0, 1, 0);
  return ls.toStr(-1) ?? 'nil';
}

/// Run a script in a fresh LuaState with custom GC tuning applied
/// before the script executes.
String _runScriptWithGcTuning(String script, int pause, int stepMul) {
  final ls = LuaState.newState();
  ls.openLibs();
  ls.doString(
    'collectgarbage("setpause", $pause); '
    'collectgarbage("setstepmul", $stepMul)',
  );
  ls.loadString(script);
  ls.pCall(0, 1, 0);
  return ls.toStr(-1) ?? 'nil';
}

/// Build a heap of GC pressure, then time the collector.  The GC is
/// stopped before the workload runs so the heap grows untouched; we
/// snapshot objectCount before and after the collection phase.
String _runGcSweep(String script, bool useStw) {
  final ls = LuaState.newState() as LuaStateImpl;
  ls.openLibs();
  // Stop GC during the workload so the heap builds up without any
  // incremental steps firing inside the VM loop.
  ls.gc.stop();
  ls.loadString(script);
  ls.pCall(0, 1, 0);
  final preCount = ls.gc.objectCount;
  // `step()` is a no-op while the GC is stopped, so the incremental
  // leg must restart the collector before driving the step loop.
  // `fullCycle()` does not check `_running`, so the STW leg does not
  // need to restart.
  if (useStw) {
    ls.gc.fullCycle();
  } else {
    ls.gc.restart();
    // `step()` returns true when a full cycle has completed (i.e. the
    // collector transitioned back to the `pause` phase from a
    // non-pause one).  We loop until that signal fires.  A safety cap
    // protects against pathological heaps where the cycle never
    // completes; in practice a single step drains a multi-MB heap
    // because each step does up to `stepMul/100 * debt` work.
    int safety = 0;
    while (!ls.gc.step() && safety < 10000) {
      safety++;
    }
  }
  final postCount = ls.gc.objectCount;
  return 'pre=$preCount,post=$postCount';
}

/// Build the table-churn script for Run C, with or without a `__gc`
/// metatable attached to each table.  The finalizer is a true no-op
/// (`function() end`) so we measure dispatch cost, not body cost.
String _buildChurnWithFinalizer(bool withFinalizer) {
  final finalizeBit = withFinalizer ? 'setmetatable(t, mt)' : '-- no metatable';
  final mtDef =
      withFinalizer ? 'local mt = {__gc = function() end}' : 'local mt = nil';
  return '''
$mtDef
local n = 0
for i = 1, 8000 do
  local t = {i, i + 1, i + 2, i + 3, i + 4}
  $finalizeBit
  n = n + t[1] + t[2] + t[3] + t[4] + t[5]
end
return n
''';
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

void main() async {
  // ─────────────────────────────────────────────────────────────────────
  // Run A: Aggressive vs Relaxed GC tuning under allocation workloads
  // ─────────────────────────────────────────────────────────────────────
  print('\n[1/3] Aggressive vs Relaxed GC tuning under allocation workloads');
  final tuning = PerfTester<String, String>(
    testName: 'GC tuning: aggressive (pause=100, stepMul=500)  vs  '
        'relaxed (pause=400, stepMul=100)',
    testCases: const [
      _tableChurn,
      _closureChurn,
      _nestedTables,
      _stringChurn,
      _mixedWorkload,
    ],
    implementation1: (script) => _runScriptWithGcTuning(script, 100, 500),
    implementation2: (script) => _runScriptWithGcTuning(script, 400, 100),
    impl1Name: 'Aggressive',
    impl2Name: 'Relaxed',
  );
  await tuning.run(warmupRuns: 10, benchmarkRuns: 50);

  // ─────────────────────────────────────────────────────────────────────
  // Run B: Stop-the-world fullCycle() vs incremental step() loop
  // ─────────────────────────────────────────────────────────────────────
  print('\n[2/3] Stop-the-world fullCycle() vs incremental step() throughput');
  final sweep = PerfTester<String, String>(
    testName: 'GC throughput: fullCycle() stop-the-world  vs  '
        'step() incremental loop on a pre-populated heap',
    testCases: const [_smallHeap, _mediumHeap, _largeHeap],
    implementation1: (script) => _runGcSweep(script, true),
    implementation2: (script) => _runGcSweep(script, false),
    impl1Name: 'StopTheWorld',
    impl2Name: 'Incremental',
  );
  await sweep.run(warmupRuns: 10, benchmarkRuns: 50);

  // ─────────────────────────────────────────────────────────────────────
  // Run C: With __gc finalizers vs without on table churn
  // ─────────────────────────────────────────────────────────────────────
  // PerfTester passes the same Input to both implementations, so we
  // supply a single placeholder input.  Each implementation closure
  // picks the correct script variant to actually run.  Both scripts
  // return the same integer `n` (the finalizer is a no-op), so the
  // default parity check via jsonEncode succeeds.
  final placeholder = _buildChurnWithFinalizer(false);
  final withFinalizer = _buildChurnWithFinalizer(true);
  print('\n[3/3] GC overhead: with __gc finalizers vs without, on table churn');
  final finalizers = PerfTester<String, String>(
    testName: 'GC overhead: with __gc finalizers  vs  without, on table churn',
    testCases: [placeholder],
    implementation1: (_) => _runScript(placeholder),
    implementation2: (_) => _runScript(withFinalizer),
    impl1Name: 'NoFinalizer',
    impl2Name: 'WithFinalizer',
  );
  await finalizers.run(warmupRuns: 10, benchmarkRuns: 50);
}
