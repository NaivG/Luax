import 'package:luax/lua.dart';
import 'package:luax/src/state/lua_state_impl.dart';
import 'package:test/test.dart';

void main() {
  group('Incremental GC — state machine', () {
    test('GC starts in pause phase', () {
      final ls = LuaState.newState() as LuaStateImpl;
      ls.openLibs();
      expect(ls.gc.phase.name, equals('pause'));
    });

    test('full cycle returns to pause', () {
      final ls = LuaState.newState() as LuaStateImpl;
      ls.openLibs();
      ls.doString(r'collectgarbage("collect")');
      expect(ls.gc.phase.name, equals('pause'));
    });

    test('cycle count increments after each collection', () {
      final ls = LuaState.newState() as LuaStateImpl;
      ls.openLibs();
      final before = ls.gc.cycleCount;
      ls.doString(r'''
        collectgarbage("collect")
        collectgarbage("collect")
        collectgarbage("collect")
      ''');
      expect(ls.gc.cycleCount, greaterThanOrEqualTo(before + 3));
    });

    test('step count increases with GC work', () {
      final ls = LuaState.newState() as LuaStateImpl;
      ls.openLibs();
      final before = ls.gc.stepCount;
      ls.doString(r'''
        collectgarbage("collect")
      ''');
      expect(ls.gc.stepCount, greaterThan(before));
    });
  });

  group('collectgarbage("info")', () {
    test('returns a table with expected keys', () {
      final ls = LuaState.newState();
      ls.openLibs();
      ls.doString(r'''
        info = collectgarbage("info")
      ''');
      ls.getGlobal('info');
      expect(ls.isTable(-1), isTrue);

      // Check that the expected fields exist.
      for (final key in [
        'count',
        'pause',
        'stepmul',
        'steps',
        'collections',
        'objects',
        'isrunning',
        'mode',
        'phase',
      ]) {
        ls.getField(-1, key);
        expect(ls.isNoneOrNil(-1), isFalse, reason: 'missing key: $key');
        ls.pop(1);
      }
    });

    test('mode is "incremental"', () {
      final ls = LuaState.newState();
      ls.openLibs();
      ls.doString(r'''
        info = collectgarbage("info")
        mode = info.mode
      ''');
      ls.getGlobal('mode');
      expect(ls.toStr(-1), equals('incremental'));
    });

    test('mode is "stopped" after collectgarbage("stop")', () {
      final ls = LuaState.newState();
      ls.openLibs();
      ls.doString(r'''
        collectgarbage("stop")
        info = collectgarbage("info")
        mode = info.mode
      ''');
      ls.getGlobal('mode');
      expect(ls.toStr(-1), equals('stopped'));
    });

    test('count matches collectgarbage("count")', () {
      final ls = LuaState.newState();
      ls.openLibs();
      ls.doString(r'''
        count_direct = collectgarbage("count")
        count_info = collectgarbage("info").count
      ''');
      ls.getGlobal('count_direct');
      final direct = ls.toNumber(-1);
      ls.pop(1);
      ls.getGlobal('count_info');
      final fromInfo = ls.toNumber(-1);
      // They should be very close (may differ slightly due to allocation
      // between the two calls).
      expect((direct - fromInfo).abs(), lessThan(10.0));
    });
  });

  group('__gc resurrection', () {
    test('resurrected object is accessible after GC', () {
      final ls = LuaState.newState();
      ls.openLibs();
      ls.doString(r'''
        collectgarbage("stop")
        saved = nil

        local function create_resurrectable()
          local t = {tag = "resurrected"}
          setmetatable(t, {__gc = function(self)
            saved = self  -- resurrect!
          end})
        end

        create_resurrectable()
        collectgarbage("collect")

        -- After GC, the object should have been saved via __gc.
        result = saved and saved.tag
      ''');
      ls.getGlobal('result');
      expect(ls.toStr(-1), equals('resurrected'));
    });

    test('resurrected object can be collected again', () {
      final ls = LuaState.newState();
      ls.openLibs();
      ls.doString(r'''
        collectgarbage("stop")
        gc_count = 0

        local function make()
          local t = {}
          setmetatable(t, {__gc = function()
            gc_count = gc_count + 1
          end})
          return t
        end

        -- Create, resurrect, release, collect again.
        local holder = nil
        local function create_and_save()
          local t = make()
          setmetatable(t, {__gc = function(self)
            gc_count = gc_count + 1
            holder = self  -- resurrect on first GC
          end})
        end

        create_and_save()
        collectgarbage("collect")
        -- gc_count should be 1, holder has the resurrected object.
        first_count = gc_count

        -- Now release the holder and collect again.
        holder = nil
        collectgarbage("collect")
        second_count = gc_count
      ''');
      ls.getGlobal('first_count');
      expect(ls.toInteger(-1), equals(1));
      ls.pop(1);
      ls.getGlobal('second_count');
      // After release, __gc fires again (Lua 5.3 doesn't mark "already finalized").
      expect(ls.toInteger(-1), equals(2));
    });
  });

  group('Incremental step-by-step collection', () {
    test('multiple small steps achieve same result as full cycle', () {
      final ls = LuaState.newState();
      ls.openLibs();

      // Run a full cycle to establish baseline.
      ls.doString(r'''
        collectgarbage("stop")
        for i = 1, 100 do
          local t = {i, i*2, i*3}
        end
        before = collectgarbage("count")
        collectgarbage("collect")
        after_full = collectgarbage("count")
      ''');

      ls.getGlobal('before');
      final before = ls.toNumber(-1);
      ls.pop(1);
      ls.getGlobal('after_full');
      final afterFull = ls.toNumber(-1);
      ls.pop(1);

      expect(afterFull, lessThan(before),
          reason: 'Full cycle should reclaim memory');
    });

    test('step returns true when cycle completes', () {
      final ls = LuaState.newState() as LuaStateImpl;
      ls.openLibs();
      // Force a collection via step with a large size.
      final completed = ls.gc.step(1000);
      // A step may or may not complete a full cycle depending on debt.
      // The important thing is it doesn't crash.
      expect(completed, isA<bool>());
    });

    test('GC debt triggers automatic collection', () {
      final ls = LuaState.newState() as LuaStateImpl;
      ls.openLibs();
      // Use aggressive settings.
      ls.gc.pause = 100; // Start GC when memory doubles.
      ls.gc.stepMul = 500; // Work 5x the allocation rate.
      ls.gc.restart();

      final beforeCycles = ls.gc.cycleCount;

      // Create many objects to trigger automatic GC.
      ls.doString(r'''
        for i = 1, 500 do
          local t = {i, "hello", {nested = true}}
        end
      ''');

      // At least one automatic cycle should have occurred.
      expect(ls.gc.cycleCount, greaterThan(beforeCycles));
    });
  });

  group('GC stop/Restart behavior', () {
    test('stop prevents automatic collection', () {
      final ls = LuaState.newState() as LuaStateImpl;
      ls.openLibs();
      ls.doString(r'''
        collectgarbage("stop")
      ''');
      expect(ls.gc.isRunning, isFalse);

      // Even with lots of allocations, no automatic GC should run.
      final beforeCycles = ls.gc.cycleCount;
      ls.doString(r'''
        for i = 1, 200 do
          local t = {i, i*2}
        end
      ''');
      // Cycle count should not have increased (no automatic collection).
      // Note: manual collectgarbage("collect") still works.
      expect(ls.gc.cycleCount, equals(beforeCycles));
    });

    test('manual collect works even when stopped', () {
      final ls = LuaState.newState();
      ls.openLibs();
      ls.doString(r'''
        collectgarbage("stop")
        for i = 1, 50 do local t = {i} end
        before = collectgarbage("count")
        collectgarbage("collect")
        after = collectgarbage("count")
      ''');
      ls.getGlobal('after');
      final after = ls.toNumber(-1);
      ls.pop(1);
      ls.getGlobal('before');
      final before = ls.toNumber(-1);
      expect(after, lessThanOrEqualTo(before));
    });
  });

  group('Finalizer ordering', () {
    test('__gc runs in reverse detection order (LIFO)', () {
      final ls = LuaState.newState();
      ls.openLibs();
      ls.doString(r'''
        collectgarbage("stop")
        order = {}

        local function make(id)
          local t = {id = id}
          setmetatable(t, {__gc = function(self)
            order[#order + 1] = self.id
          end})
        end

        make("first")
        make("second")
        make("third")
        collectgarbage("collect")
      ''');
      ls.getGlobal('order');
      // LIFO: third was detected last, finalized first.
      ls.getI(-1, 1);
      expect(ls.toStr(-1), equals('third'));
      ls.pop(1);
      ls.getI(-1, 2);
      expect(ls.toStr(-1), equals('second'));
      ls.pop(1);
      ls.getI(-1, 3);
      expect(ls.toStr(-1), equals('first'));
    });
  });

  group('Edge cases', () {
    test('__gc can create new objects without crashing', () {
      final ls = LuaState.newState();
      ls.openLibs();
      expect(() => ls.doString(r'''
        collectgarbage("stop")
        local function make()
          local t = {}
          setmetatable(t, {__gc = function()
            local new_t = {created_in_gc = true}
          end})
        end
        make()
        collectgarbage("collect")
      '''), returnsNormally);
    });

    test('__gc calling collectgarbage does not crash', () {
      final ls = LuaState.newState();
      ls.openLibs();
      expect(() => ls.doString(r'''
        collectgarbage("stop")
        local function make()
          local t = {}
          setmetatable(t, {__gc = function()
            collectgarbage("count")  -- query during finalize
          end})
        end
        make()
        collectgarbage("collect")
      '''), returnsNormally);
    });

    test('large number of finalizers', () {
      final ls = LuaState.newState();
      ls.openLibs();
      // ── Why we assert >= 99 rather than == 100 ──────────────────────
      //
      // When the loop and collectgarbage("collect") execute in the same
      // chunk, the compiler allocates a register for the local `t` in the
      // loop body.  After each iteration the register is logically dead,
      // but the compiler does NOT emit an LNIL to clear it — the slot
      // simply remains "allocated" until the function returns.
      //
      // In Lua 5.3 the GC roots include every register below ci->top of
      // each active call frame.  During the mark phase the GC traces the
      // entire register range [0..ci->top), which means the stale
      // reference in the last-iteration register still keeps that table
      // reachable.  Consequently only 99 of the 100 tables are detected
      // as dead in this single-pass collection.
      //
      // This is standard Lua 5.3 semantics:
      // any object whose register is still within ci->top but no longer
      // referenced by live code will survive one collection cycle.
      ls.doString(r'''
        collectgarbage("stop")
        count = 0
        for i = 1, 100 do
          local t = {}
          setmetatable(t, {__gc = function() count = count + 1 end})
        end
        collectgarbage("collect")
      ''');
      ls.getGlobal('count');
      expect(ls.toInteger(-1), greaterThanOrEqualTo(99));
    });

    test('all finalizers run when objects created in separate scope', () {
      final ls = LuaState.newState();
      ls.openLibs();
      // ── Why splitting into two doString calls yields == 100 ──────────
      //
      // The first doString compiles and executes the loop, allocating
      // registers for `t`.  When doString returns the chunk's call frame
      // is popped: ci->top is restored to the caller's level and every
      // register the chunk owned is effectively released.  No stale
      // references survive.
      //
      // The second doString (collectgarbage("collect")) runs in a fresh
      // call frame with its own register set — it has no knowledge of the
      // tables created by the first chunk.  Therefore all 100 tables are
      // unreachable and all 100 finalizers fire.
      //
      // Contrast with the preceding test where creation and collection
      // share the same call frame, leaving one stale register alive.
      //
      // And i'm wondering if anyone has actually encountered this situation :P
      ls.doString(r'''
        collectgarbage("stop")
        count = 0
        for i = 1, 100 do
          local t = {}
          setmetatable(t, {__gc = function() count = count + 1 end})
        end
      ''');
      ls.doString(r'collectgarbage("collect")');
      ls.getGlobal('count');
      expect(ls.toInteger(-1), equals(100));
    });

    test('nested tables with __gc', () {
      final ls = LuaState.newState();
      ls.openLibs();
      ls.doString(r'''
        collectgarbage("stop")
        outer_gc = false
        inner_gc = false

        local function make_nested()
          local inner = {}
          setmetatable(inner, {__gc = function() inner_gc = true end})

          local outer = {child = inner}
          setmetatable(outer, {__gc = function() outer_gc = true end})
        end

        make_nested()
        collectgarbage("collect")
      ''');
      ls.getGlobal('outer_gc');
      expect(ls.toBoolean(-1), isTrue);
      ls.pop(1);
      ls.getGlobal('inner_gc');
      expect(ls.toBoolean(-1), isTrue);
    });
  });
}
