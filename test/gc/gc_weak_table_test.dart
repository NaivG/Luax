import 'package:luax/lua.dart';
import 'package:luax/src/state/lua_state_impl.dart';
import 'package:test/test.dart';

void main() {
  group('Weak values (__mode = "v")', () {
    test('weak value entries are collected when value is unreachable', () {
      final ls = LuaState.newState();
      ls.openLibs();

      // Create weak table and populate it in one call frame.
      ls.doString(r'''
        collectgarbage("stop")
        weak = {}
        setmetatable(weak, {__mode = "v"})

        local function populate()
          for i = 1, 50 do
            weak[i] = {tag = i}
          end
        end
        populate()
        before_count = 0
        for k, v in pairs(weak) do
          before_count = before_count + 1
        end
      ''');

      // Run GC in a separate call frame so stale registers are released.
      ls.doString(r'''
        collectgarbage("collect")
        after_count = 0
        for k, v in pairs(weak) do
          after_count = after_count + 1
        end
      ''');

      ls.getGlobal('before_count');
      expect(ls.toInteger(-1), equals(50));
      ls.pop(1);

      ls.getGlobal('after_count');
      // All values were unreachable (created inside populate()),
      // so all weak-value entries should have been cleaned.
      expect(ls.toInteger(-1), equals(0));
    });

    test('weak value entries survive when value is still referenced', () {
      final ls = LuaState.newState();
      ls.openLibs();

      ls.doString(r'''
        collectgarbage("stop")
        weak = {}
        setmetatable(weak, {__mode = "v"})

        -- Keep a strong reference to one of the values.
        kept_value = {tag = "keep_me"}

        local function populate()
          weak[1] = kept_value
          for i = 2, 10 do
            weak[i] = {tag = i}
          end
        end
        populate()
      ''');

      ls.doString(r'''
        collectgarbage("collect")
        after_count = 0
        for k, v in pairs(weak) do
          after_count = after_count + 1
        end
        surviving_tag = weak[1] and weak[1].tag
      ''');

      ls.getGlobal('after_count');
      // Only kept_value survives.
      expect(ls.toInteger(-1), equals(1));
      ls.pop(1);

      ls.getGlobal('surviving_tag');
      expect(ls.toStr(-1), equals('keep_me'));
    });

    test('weak values with non-GCObject values are not affected', () {
      final ls = LuaState.newState();
      ls.openLibs();

      ls.doString(r'''
        collectgarbage("stop")
        weak = {}
        setmetatable(weak, {__mode = "v"})
        weak[1] = 42
        weak[2] = "hello"
        weak[3] = true
        weak[4] = {tag = "collectible"}
      ''');

      ls.doString(r'''
        collectgarbage("collect")
        v1 = weak[1]
        v2 = weak[2]
        v3 = weak[3]
        v4 = weak[4]
      ''');

      // Non-GCObject values (number, string, bool) should survive.
      ls.getGlobal('v1');
      expect(ls.toInteger(-1), equals(42));
      ls.pop(1);

      ls.getGlobal('v2');
      expect(ls.toStr(-1), equals('hello'));
      ls.pop(1);

      ls.getGlobal('v3');
      expect(ls.toBoolean(-1), isTrue);
      ls.pop(1);

      // GCObject value (table) should be collected.
      ls.getGlobal('v4');
      expect(ls.isNil(-1), isTrue);
    });
  });

  group('Weak keys (__mode = "k")', () {
    test('weak key entries are collected when key is unreachable', () {
      final ls = LuaState.newState();
      ls.openLibs();

      ls.doString(r'''
        collectgarbage("stop")
        weak = {}
        setmetatable(weak, {__mode = "k"})

        local function populate()
          for i = 1, 50 do
            local key = {id = i}
            weak[key] = i
          end
        end
        populate()
        before_count = 0
        for k, v in pairs(weak) do
          before_count = before_count + 1
        end
      ''');

      ls.doString(r'''
        collectgarbage("collect")
        after_count = 0
        for k, v in pairs(weak) do
          after_count = after_count + 1
        end
      ''');

      ls.getGlobal('before_count');
      expect(ls.toInteger(-1), equals(50));
      ls.pop(1);

      ls.getGlobal('after_count');
      // All keys were unreachable → entries removed.
      expect(ls.toInteger(-1), equals(0));
    });

    test('weak key entries survive when key is still referenced', () {
      final ls = LuaState.newState();
      ls.openLibs();

      ls.doString(r'''
        collectgarbage("stop")
        weak = {}
        setmetatable(weak, {__mode = "k"})

        kept_key = {id = "keep"}

        local function populate()
          weak[kept_key] = "survives"
          for i = 1, 10 do
            local key = {id = i}
            weak[key] = i
          end
        end
        populate()
      ''');

      ls.doString(r'''
        collectgarbage("collect")
        after_count = 0
        for k, v in pairs(weak) do
          after_count = after_count + 1
        end
        surviving_val = weak[kept_key]
      ''');

      ls.getGlobal('after_count');
      expect(ls.toInteger(-1), equals(1));
      ls.pop(1);

      ls.getGlobal('surviving_val');
      expect(ls.toStr(-1), equals('survives'));
    });

    test('weak keys still strongly reference values', () {
      final ls = LuaState.newState();
      ls.openLibs();

      // With __mode = "k", values are strongly referenced.
      // Only keys are weak. So even if the value is only reachable
      // through the weak table's value slot, it should NOT be collected
      // (because values are strong in weak-key tables).
      ls.doString(r'''
        collectgarbage("stop")
        weak = {}
        setmetatable(weak, {__mode = "k"})

        kept_key = {id = "alive"}
        weak[kept_key] = {data = "value_data"}
      ''');

      ls.doString(r'''
        collectgarbage("collect")
        val = weak[kept_key]
        result = val and val.data
      ''');

      ls.getGlobal('result');
      expect(ls.toStr(-1), equals('value_data'));
    });
  });

  group('Weak keys and values (__mode = "kv")', () {
    test('entries removed when both key and value are unreachable', () {
      final ls = LuaState.newState();
      ls.openLibs();

      ls.doString(r'''
        collectgarbage("stop")
        weak = {}
        setmetatable(weak, {__mode = "kv"})

        local function populate()
          for i = 1, 30 do
            local key = {kid = i}
            weak[key] = {vid = i}
          end
        end
        populate()
      ''');

      ls.doString(r'''
        collectgarbage("collect")
        after_count = 0
        for k, v in pairs(weak) do
          after_count = after_count + 1
        end
      ''');

      ls.getGlobal('after_count');
      expect(ls.toInteger(-1), equals(0));
    });

    test('entry survives only if BOTH key and value are reachable', () {
      final ls = LuaState.newState();
      ls.openLibs();

      ls.doString(r'''
        collectgarbage("stop")
        weak = {}
        setmetatable(weak, {__mode = "kv"})

        kept_key = {kid = "alive"}
        kept_val = {vid = "alive"}
        -- Only this entry has both key and value strongly referenced.
        weak[kept_key] = kept_val

        local function add_unreachable()
          for i = 1, 10 do
            local k = {kid = i}
            weak[k] = {vid = i}
          end
        end
        add_unreachable()
      ''');

      ls.doString(r'''
        collectgarbage("collect")
        after_count = 0
        for k, v in pairs(weak) do
          after_count = after_count + 1
        end
        surviving = weak[kept_key]
      ''');

      ls.getGlobal('after_count');
      expect(ls.toInteger(-1), equals(1));
      ls.pop(1);

      ls.getGlobal('surviving');
      expect(ls.isTable(-1), isTrue);
    });
  });

  group('Weak table lifecycle', () {
    test('unreachable weak table is collected and removed from tracking', () {
      final ls = LuaState.newState() as LuaStateImpl;
      ls.openLibs();

      ls.doString(r'''
        collectgarbage("stop")
        local function create_weak()
          local weak = {}
          setmetatable(weak, {__mode = "v"})
          weak[1] = {data = "test"}
        end
        create_weak()
      ''');

      ls.doString(r'''
        collectgarbage("collect")
      ''');

      // The weak table was unreachable, so it should have been collected.
      // We can't directly test the internal _weakTables list from Lua,
      // but we can verify no crash occurs and GC completes normally.
      expect(ls.gc.phase.name, equals('pause'));
    });

    test('reachable weak table is NOT collected', () {
      final ls = LuaState.newState();
      ls.openLibs();

      ls.doString(r'''
        collectgarbage("stop")
        weak = {}
        setmetatable(weak, {__mode = "v"})
        weak[1] = {tag = "value"}
        kept_ref = {tag = "kept"}
        weak[2] = kept_ref
      ''');

      ls.doString(r'''
        collectgarbage("collect")
        -- The weak table itself is a global, so it's reachable.
        -- Entry 1 (unreachable value) should be gone.
        -- Entry 2 (kept_ref is global) should survive.
        v1 = weak[1]
        v2 = weak[2]
      ''');

      ls.getGlobal('v1');
      expect(ls.isNil(-1), isTrue);
      ls.pop(1);

      ls.getGlobal('v2');
      expect(ls.isTable(-1), isTrue);
    });

    test('setmetatable with nil removes weak status', () {
      final ls = LuaState.newState();
      ls.openLibs();

      ls.doString(r'''
        collectgarbage("stop")
        t = {}
        setmetatable(t, {__mode = "v"})
        local function populate()
          t[1] = {tag = "test"}
        end
        populate()

        -- Remove metatable (and thus weak status).
        setmetatable(t, nil)
      ''');

      ls.doString(r'''
        collectgarbage("collect")
        -- After removing the metatable, t is no longer weak.
        -- The value should survive because it's strongly referenced now.
        result = t[1] and t[1].tag
      ''');

      ls.getGlobal('result');
      expect(ls.toStr(-1), equals('test'));
    });

    test('changing metatable to non-weak removes weak status', () {
      final ls = LuaState.newState();
      ls.openLibs();

      ls.doString(r'''
        collectgarbage("stop")
        t = {}
        setmetatable(t, {__mode = "v"})
        local function populate()
          t[1] = {tag = "test"}
        end
        populate()

        -- Replace with a non-weak metatable.
        setmetatable(t, {__index = {}})
      ''');

      ls.doString(r'''
        collectgarbage("collect")
        result = t[1] and t[1].tag
      ''');

      ls.getGlobal('result');
      expect(ls.toStr(-1), equals('test'));
    });
  });

  group('Weak table edge cases', () {
    test('weak table with only non-GCObject keys/values is unaffected by GC',
        () {
      final ls = LuaState.newState();
      ls.openLibs();

      ls.doString(r'''
        collectgarbage("stop")
        weak = {}
        setmetatable(weak, {__mode = "kv"})
        weak["string_key"] = "string_value"
        weak[1] = 42
        weak[true] = false
      ''');

      ls.doString(r'''
        collectgarbage("collect")
        v1 = weak["string_key"]
        v2 = weak[1]
        v3 = weak[true]
      ''');

      ls.getGlobal('v1');
      expect(ls.toStr(-1), equals('string_value'));
      ls.pop(1);

      ls.getGlobal('v2');
      expect(ls.toInteger(-1), equals(42));
      ls.pop(1);

      ls.getGlobal('v3');
      expect(ls.toBoolean(-1), isFalse);
    });

    test('weak table stress: many entries with mixed reachability', () {
      final ls = LuaState.newState();
      ls.openLibs();

      ls.doString(r'''
        collectgarbage("stop")
        weak = {}
        setmetatable(weak, {__mode = "v"})

        kept = {}
        local function populate()
          for i = 1, 200 do
            local v = {id = i}
            weak[i] = v
            if i <= 10 then
              kept[i] = v  -- keep first 10 alive
            end
          end
        end
        populate()
      ''');

      ls.doString(r'''
        collectgarbage("collect")
        count = 0
        for k, v in pairs(weak) do
          count = count + 1
        end
      ''');

      ls.getGlobal('count');
      // Only the first 10 entries should survive (their values are in kept).
      expect(ls.toInteger(-1), equals(10));
    });

    test('multiple weak tables in same GC cycle', () {
      final ls = LuaState.newState();
      ls.openLibs();

      ls.doString(r'''
        collectgarbage("stop")
        wk = {}
        setmetatable(wk, {__mode = "k"})
        wv = {}
        setmetatable(wv, {__mode = "v"})

        kept_key = {id = "key"}
        kept_val = {id = "val"}

        local function populate()
          for i = 1, 20 do
            local k = {kid = i}
            local v = {vid = i}
            wk[k] = i
            wv[i] = v
          end
          -- Add one entry with strong references to each table.
          wk[kept_key] = 999
          wv[100] = kept_val
        end
        populate()
      ''');

      ls.doString(r'''
        collectgarbage("collect")
        wk_count = 0
        for k, v in pairs(wk) do wk_count = wk_count + 1 end
        wv_count = 0
        for k, v in pairs(wv) do wv_count = wv_count + 1 end
        wk_kept = wk[kept_key]
        wv_kept = wv[100] and wv[100].id
      ''');

      ls.getGlobal('wk_count');
      expect(ls.toInteger(-1), equals(1));
      ls.pop(1);

      ls.getGlobal('wv_count');
      expect(ls.toInteger(-1), equals(1));
      ls.pop(1);

      ls.getGlobal('wk_kept');
      expect(ls.toInteger(-1), equals(999));
      ls.pop(1);

      ls.getGlobal('wv_kept');
      expect(ls.toStr(-1), equals('val'));
    });

    test('weak table with __gc finalizer: finalized when unreachable', () {
      final ls = LuaState.newState();
      ls.openLibs();

      ls.doString(r'''
        collectgarbage("stop")
        finalized = false
        local function make_weak_with_gc()
          local weak = {}
          setmetatable(weak, {
            __mode = "v",
            __gc = function() finalized = true end
          })
          weak[1] = {data = "test"}
        end
        make_weak_with_gc()
      ''');

      ls.doString(r'''
        collectgarbage("collect")
      ''');

      ls.getGlobal('finalized');
      expect(ls.toBoolean(-1), isTrue);
    });
  });
}
