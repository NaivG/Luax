import 'package:luax/lua.dart';
import 'package:test/test.dart';

void main() {
  group('collectgarbage API', () {
    test('collectgarbage("count") returns a number', () {
      final ls = LuaState.newState();
      ls.openLibs();
      ls.doString(r'''
        result = collectgarbage("count")
      ''');
      ls.getGlobal('result');
      expect(ls.isNumber(-1), isTrue);
      expect(ls.toNumber(-1), greaterThan(0));
    });

    test('collectgarbage("collect") runs without error', () {
      final ls = LuaState.newState();
      ls.openLibs();
      expect(() => ls.doString(r'collectgarbage("collect")'), returnsNormally);
    });

    test('collectgarbage("isrunning") returns boolean', () {
      final ls = LuaState.newState();
      ls.openLibs();
      ls.doString(r'''
        result = collectgarbage("isrunning")
      ''');
      ls.getGlobal('result');
      expect(ls.type(-1), equals(LuaType.luaBoolean));
      expect(ls.toBoolean(-1), isTrue);
    });

    test('collectgarbage("stop") and collectgarbage("restart")', () {
      final ls = LuaState.newState();
      ls.openLibs();
      ls.doString(r'''
        collectgarbage("stop")
        stopped = collectgarbage("isrunning")
        collectgarbage("restart")
        running = collectgarbage("isrunning")
      ''');
      ls.getGlobal('stopped');
      expect(ls.toBoolean(-1), isFalse);
      ls.pop(1);
      ls.getGlobal('running');
      expect(ls.toBoolean(-1), isTrue);
    });

    test('collectgarbage("setpause") returns old value', () {
      final ls = LuaState.newState();
      ls.openLibs();
      ls.doString(r'''
        old = collectgarbage("setpause", 300)
        current = collectgarbage("setpause", 200)
      ''');
      ls.getGlobal('old');
      expect(ls.toInteger(-1), equals(200)); // default pause
      ls.pop(1);
      ls.getGlobal('current');
      expect(ls.toInteger(-1), equals(300)); // the value we just set
    });

    test('collectgarbage("setstepmul") returns old value', () {
      final ls = LuaState.newState();
      ls.openLibs();
      ls.doString(r'''
        old = collectgarbage("setstepmul", 400)
        current = collectgarbage("setstepmul", 200)
      ''');
      ls.getGlobal('old');
      expect(ls.toInteger(-1), equals(200)); // default step mul
      ls.pop(1);
      ls.getGlobal('current');
      expect(ls.toInteger(-1), equals(400));
    });

    test('collectgarbage("step") returns boolean', () {
      final ls = LuaState.newState();
      ls.openLibs();
      ls.doString(r'''
        result = collectgarbage("step", 100)
      ''');
      ls.getGlobal('result');
      expect(ls.type(-1), equals(LuaType.luaBoolean));
    });

    test('collectgarbage with invalid option errors', () {
      final ls = LuaState.newState();
      ls.openLibs();
      // doString returns false when Lua code errors (pCall catches it).
      final ok = ls.doString(r'collectgarbage("invalid_option")');
      expect(ok, isFalse);
    });

    test('collectgarbage default (no args) runs a full cycle', () {
      final ls = LuaState.newState();
      ls.openLibs();
      expect(() => ls.doString(r'collectgarbage()'), returnsNormally);
    });
  });

  group('GC object tracking', () {
    test('tables created during Lua execution are tracked', () {
      final ls = LuaState.newState();
      ls.openLibs();
      ls.doString(r'''
        collectgarbage("stop")
        before = collectgarbage("count")
        for i = 1, 100 do
          local t = {1, 2, 3, a = "hello", b = "world"}
        end
        after = collectgarbage("count")
      ''');
      ls.getGlobal('after');
      final after = ls.toNumber(-1);
      ls.pop(1);
      ls.getGlobal('before');
      final before = ls.toNumber(-1);
      expect(after, greaterThan(before));
    });

    test('full cycle reclaims unreachable tables', () {
      final ls = LuaState.newState();
      ls.openLibs();
      ls.doString(r'''
        collectgarbage("stop")
        -- Create tables inside a function scope (become unreachable after return)
        local function make_garbage()
          for i = 1, 50 do
            local t = {x = i, y = i * 2, z = {nested = true}}
          end
        end
        make_garbage()
        before = collectgarbage("count")
        collectgarbage("collect")
        after = collectgarbage("count")
      ''');
      ls.getGlobal('before');
      final before = ls.toNumber(-1);
      ls.pop(1);
      ls.getGlobal('after');
      final after = ls.toNumber(-1);
      // After collection, memory should be less (unreachable objects reclaimed).
      expect(after, lessThanOrEqualTo(before));
    });

    test('reachable tables are NOT collected', () {
      final ls = LuaState.newState();
      ls.openLibs();
      ls.doString(r'''
        collectgarbage("stop")
        kept = {1, 2, 3, name = "important"}
        collectgarbage("collect")
        -- The table should still be accessible.
        result = kept.name
      ''');
      ls.getGlobal('result');
      expect(ls.toStr(-1), equals('important'));
    });

    test('closures are tracked and collected', () {
      final ls = LuaState.newState();
      ls.openLibs();
      ls.doString(r'''
        collectgarbage("stop")
        local function make_closure()
          local upval = {1, 2, 3}
          return function() return upval end
        end
        -- Create and discard closures
        for i = 1, 50 do
          make_closure()
        end
        before = collectgarbage("count")
        collectgarbage("collect")
        after = collectgarbage("count")
      ''');
      ls.getGlobal('before');
      final before = ls.toNumber(-1);
      ls.pop(1);
      ls.getGlobal('after');
      final after = ls.toNumber(-1);
      expect(after, lessThanOrEqualTo(before));
    });
  });

  group('__gc metamethod (finalizers)', () {
    test('__gc is called when table becomes unreachable', () {
      final ls = LuaState.newState();
      ls.openLibs();
      ls.doString(r'''
        collectgarbage("stop")
        finalized = false
        local function create_with_finalizer()
          local t = {}
          setmetatable(t, {__gc = function()
            finalized = true
          end})
        end
        create_with_finalizer()
        collectgarbage("collect")
      ''');
      ls.getGlobal('finalized');
      expect(ls.toBoolean(-1), isTrue);
    });

    test('__gc receives the object as argument', () {
      final ls = LuaState.newState();
      ls.openLibs();
      ls.doString(r'''
        collectgarbage("stop")
        received_tag = nil
        local function create_tagged()
          local t = {tag = "hello"}
          setmetatable(t, {__gc = function(self)
            received_tag = self.tag
          end})
        end
        create_tagged()
        collectgarbage("collect")
      ''');
      ls.getGlobal('received_tag');
      expect(ls.toStr(-1), equals('hello'));
    });

    test('multiple __gc are called', () {
      final ls = LuaState.newState();
      ls.openLibs();
      ls.doString(r'''
        collectgarbage("stop")
        count = 0
        local function make()
          local t = {}
          setmetatable(t, {__gc = function() count = count + 1 end})
        end
        make()
        make()
        make()
        collectgarbage("collect")
      ''');
      ls.getGlobal('count');
      expect(ls.toInteger(-1), equals(3));
    });

    test('error in __gc does not crash VM', () {
      final ls = LuaState.newState();
      ls.openLibs();
      // This should not throw, even though __gc raises an error.
      expect(() => ls.doString(r'''
        collectgarbage("stop")
        local function make()
          local t = {}
          setmetatable(t, {__gc = function() error("boom") end})
        end
        make()
        collectgarbage("collect")
        survived = true
      '''), returnsNormally);
      ls.getGlobal('survived');
      expect(ls.toBoolean(-1), isTrue);
    });
  });

  group('GC stress', () {
    test('many cycles without crash', () {
      final ls = LuaState.newState();
      ls.openLibs();
      expect(() => ls.doString(r'''
        for cycle = 1, 100 do
          for i = 1, 50 do
            local t = {i, i*2, i*3}
          end
          collectgarbage("collect")
        end
        ok = true
      '''), returnsNormally);
      ls.getGlobal('ok');
      expect(ls.toBoolean(-1), isTrue);
    });

    test('GC during Lua execution (auto-trigger)', () {
      final ls = LuaState.newState();
      ls.openLibs();
      // Enable GC with aggressive settings so it triggers during execution.
      ls.doString(r'''
        collectgarbage("setpause", 100)
        collectgarbage("setstepmul", 500)
        collectgarbage("restart")
        -- Create enough objects to trigger GC multiple times.
        local big = {}
        for i = 1, 1000 do
          big[i] = {value = i, nested = {i * 2}}
        end
        -- Verify data integrity after GC.
        ok = true
        for i = 1, 1000 do
          if big[i].value ~= i or big[i].nested[1] ~= i * 2 then
            ok = false
            break
          end
        end
      ''');
      ls.getGlobal('ok');
      expect(ls.toBoolean(-1), isTrue);
    });
  });
}
