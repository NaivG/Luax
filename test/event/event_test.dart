import 'package:luax/lua.dart';
import 'package:test/test.dart';

void main() {
  group('Event system', () {
    // ------------------------------------------------------------------
    // Dart-side listeners
    // ------------------------------------------------------------------

    test('Dart listener fires on Dart emit', () {
      final ls = LuaState.newState();
      ls.openLibs();

      final received = <List<dynamic>>[];
      ls.on('test', (args) => received.add(args));

      ls.emit('test', [1, 'hello', true]);
      expect(
          received,
          equals([
            [1, 'hello', true]
          ]));
    });

    test('Dart listener fires on Lua emit', () {
      final ls = LuaState.newState();
      ls.openLibs();

      final received = <List<dynamic>>[];
      ls.on('greet', (args) => received.add(args));

      ls.doString(r'event.emit("greet", 42, "world")');
      expect(
          received,
          equals([
            [42, 'world']
          ]));
    });

    test('multiple Dart listeners fire in registration order', () {
      final ls = LuaState.newState();
      ls.openLibs();

      final order = <int>[];
      ls.on('x', (_) => order.add(1));
      ls.on('x', (_) => order.add(2));
      ls.on('x', (_) => order.add(3));

      ls.emit('x');
      expect(order, equals([1, 2, 3]));
    });

    // ------------------------------------------------------------------
    // Lua-side listeners
    // ------------------------------------------------------------------

    test('Lua listener fires on Lua emit', () {
      final ls = LuaState.newState();
      ls.openLibs();

      ls.doString(r'''
        _result = nil
        event.on("ping", function(msg)
          _result = msg
        end)
        event.emit("ping", "pong")
      ''');

      ls.getGlobal('_result');
      expect(ls.toStr(-1), equals('pong'));
    });

    test('Lua listener fires on Dart emit', () {
      final ls = LuaState.newState();
      ls.openLibs();

      ls.doString(r'''
        _result = nil
        event.on("data", function(a, b)
          _result = a + b
        end)
      ''');

      ls.emit('data', [10, 20]);

      ls.getGlobal('_result');
      expect(ls.toInteger(-1), equals(30));
    });

    test('multiple Lua listeners fire in registration order', () {
      final ls = LuaState.newState();
      ls.openLibs();

      ls.doString(r'''
        _order = {}
        event.on("seq", function() _order[#_order + 1] = "a" end)
        event.on("seq", function() _order[#_order + 1] = "b" end)
        event.on("seq", function() _order[#_order + 1] = "c" end)
        event.emit("seq")
      ''');

      ls.getGlobal('_order');
      // Read the table values
      final order = <String>[];
      for (int i = 1; i <= 3; i++) {
        ls.rawGetI(-1, i);
        order.add(ls.toStr(-1)!);
        ls.pop(1);
      }
      expect(order, equals(['a', 'b', 'c']));
    });

    // ------------------------------------------------------------------
    // Cross-side: Dart + Lua listeners on same event
    // ------------------------------------------------------------------

    test('Dart and Lua listeners both fire on Dart emit', () {
      final ls = LuaState.newState();
      ls.openLibs();

      final dartReceived = <dynamic>[];
      ls.on('mix', (args) => dartReceived.addAll(args));

      ls.doString(r'''
        _lua_received = nil
        event.on("mix", function(v)
          _lua_received = v
        end)
      ''');

      ls.emit('mix', ['hello']);

      expect(dartReceived, equals(['hello']));
      ls.getGlobal('_lua_received');
      expect(ls.toStr(-1), equals('hello'));
    });

    test('Dart and Lua listeners both fire on Lua emit', () {
      final ls = LuaState.newState();
      ls.openLibs();

      final dartReceived = <dynamic>[];
      ls.on('mix', (args) => dartReceived.addAll(args));

      ls.doString(r'''
        _lua_received = nil
        event.on("mix", function(v)
          _lua_received = v
        end)
        event.emit("mix", 99)
      ''');

      expect(dartReceived, equals([99]));
      ls.getGlobal('_lua_received');
      expect(ls.toInteger(-1), equals(99));
    });

    // ------------------------------------------------------------------
    // once()
    // ------------------------------------------------------------------

    test('Dart once() listener fires only once', () {
      final ls = LuaState.newState();
      ls.openLibs();

      var count = 0;
      ls.once('once_test', (_) => count++);

      ls.emit('once_test');
      ls.emit('once_test');
      ls.emit('once_test');
      expect(count, equals(1));
    });

    test('Lua once() listener fires only once', () {
      final ls = LuaState.newState();
      ls.openLibs();

      ls.doString(r'''
        _count = 0
        event.once("once_lua", function()
          _count = _count + 1
        end)
        event.emit("once_lua")
        event.emit("once_lua")
        event.emit("once_lua")
      ''');

      ls.getGlobal('_count');
      expect(ls.toInteger(-1), equals(1));
    });

    // ------------------------------------------------------------------
    // off()
    // ------------------------------------------------------------------

    test('Dart off() removes listener by callback reference', () {
      final ls = LuaState.newState();
      ls.openLibs();

      var count = 0;
      void handler(List<dynamic> _) => count++;

      ls.on('off_test', handler);
      ls.emit('off_test');
      expect(count, equals(1));

      ls.off('off_test', callback: handler);
      ls.emit('off_test');
      expect(count, equals(1)); // no change
    });

    test('Dart off() removes listener by id', () {
      final ls = LuaState.newState();
      ls.openLibs();

      var count = 0;
      final id = ls.on('off_id', (_) => count++);

      ls.emit('off_id');
      expect(count, equals(1));

      ls.offById(id);
      ls.emit('off_id');
      expect(count, equals(1)); // no change
    });

    test('Lua off() removes listener by id', () {
      final ls = LuaState.newState();
      ls.openLibs();

      ls.doString(r'''
        _count = 0
        local id = event.on("off_lua", function() _count = _count + 1 end)
        event.emit("off_lua")
        event.off("off_lua", id)
        event.emit("off_lua")
      ''');

      ls.getGlobal('_count');
      expect(ls.toInteger(-1), equals(1));
    });

    test('Lua off() removes listener by function reference', () {
      final ls = LuaState.newState();
      ls.openLibs();

      ls.doString(r'''
        _count = 0
        local function handler()
          _count = _count + 1
        end
        event.on("off_fn", handler)
        event.emit("off_fn")
        event.off("off_fn", handler)
        event.emit("off_fn")
      ''');

      ls.getGlobal('_count');
      expect(ls.toInteger(-1), equals(1));
    });

    test('Dart off() removes async listener by callback reference', () async {
      final ls = LuaState.newState();
      ls.openLibs();

      var count = 0;
      Future<void> handler(List<dynamic> _) async => count++;

      ls.onAsync('off_async', handler);
      await ls.emitAsync('off_async');
      expect(count, equals(1));

      ls.off('off_async', asyncCallback: handler);
      await ls.emitAsync('off_async');
      expect(count, equals(1)); // no change
    });

    test('Dart off() with asyncCallback does not affect sync listeners',
        () async {
      final ls = LuaState.newState();
      ls.openLibs();

      var syncCount = 0;
      var asyncCount = 0;
      void syncHandler(List<dynamic> _) => syncCount++;
      Future<void> asyncHandler(List<dynamic> _) async => asyncCount++;

      ls.on('mixed', syncHandler);
      ls.onAsync('mixed', asyncHandler);

      await ls.emitAsync('mixed');
      expect(syncCount, equals(1));
      expect(asyncCount, equals(1));

      // Removing async handler should not affect sync handler.
      ls.off('mixed', asyncCallback: asyncHandler);
      await ls.emitAsync('mixed');
      expect(syncCount, equals(2));
      expect(asyncCount, equals(1)); // async not called
    });

    // ------------------------------------------------------------------
    // removeAllListeners
    // ------------------------------------------------------------------

    test('removeAllListeners clears all listeners for an event', () {
      final ls = LuaState.newState();
      ls.openLibs();

      var count = 0;
      ls.on('clear', (_) => count++);
      ls.on('clear', (_) => count++);

      ls.emit('clear');
      expect(count, equals(2));

      ls.removeAllListeners('clear');
      ls.emit('clear');
      expect(count, equals(2)); // no change
    });

    test('removeAllListeners() with no arg clears everything', () {
      final ls = LuaState.newState();
      ls.openLibs();

      var a = 0, b = 0;
      ls.on('a', (_) => a++);
      ls.on('b', (_) => b++);

      ls.emit('a');
      ls.emit('b');
      expect(a, equals(1));
      expect(b, equals(1));

      ls.removeAllListeners();
      ls.emit('a');
      ls.emit('b');
      expect(a, equals(1));
      expect(b, equals(1));
    });

    test('Lua has no removeAllListeners', () {
      final ls = LuaState.newState();
      ls.openLibs();

      ls.doString(r'assert(event.removeAllListeners == nil)');
    });

    // Regression: register, fire, off-by-fn, fire, off-by-id, fire, once
    // must keep working across many cycles.  This was previously paired
    // with a full removeAllListeners() call; that call is no longer
    // reachable from Lua, but the cycle exercises the fn-map state.
    test('on/off/once still work across repeated cycles', () {
      final ls = LuaState.newState();
      ls.openLibs();

      expect(
        ls.doString(r'''
          -- Cycle 1: register, fire, off by fn, fire, off by id, fire.
          _count = 0
          local fn = function() _count = _count + 1 end
          local id = event.on("foo", fn)
          event.emit("foo")
          event.off("foo", fn)
          event.emit("foo")
          event.off("foo", id)
          event.emit("foo")

          -- Cycle 2: once.
          _once_count = 0
          event.once("bar", function() _once_count = _once_count + 1 end)
          event.emit("bar")
          event.emit("bar")

          -- Cycle 3: multiple on/off on same event.
          _cycle3 = 0
          local a = function() _cycle3 = _cycle3 + 1 end
          local b = function() _cycle3 = _cycle3 + 1 end
          event.on("baz", a)
          event.on("baz", b)
          event.emit("baz")
          event.off("baz", a)
          event.emit("baz")
          event.off("baz", b)
          event.emit("baz")
        '''),
        isTrue,
        reason: 'on/off/once must not crash across repeated cycles '
            '(regression: fn-map state must remain consistent).',
      );

      ls.getGlobal('_count');
      expect(ls.toInteger(-1), equals(1));
      ls.pop(1);
      ls.getGlobal('_once_count');
      expect(ls.toInteger(-1), equals(1));
      ls.pop(1);
      ls.getGlobal('_cycle3');
      expect(ls.toInteger(-1), equals(3));
    });

    // ------------------------------------------------------------------
    // Sandbox: Lua cannot remove Dart-side listeners
    // ------------------------------------------------------------------

    test('Lua cannot remove a Dart listener by guessing id 1', () {
      final ls = LuaState.newState();
      ls.openLibs();

      var fired = 0;
      // Dart registers first; id will be 1.
      ls.on('guess', (_) => fired++);

      // Lua tries to remove Dart's listener by id 1.
      ls.doString(r'event.off("guess", 1)');

      ls.emit('guess');
      expect(fired, equals(1),
          reason: 'Dart listener must survive Lua\'s id-based removal '
              'attempt because Dart is not the Lua sandbox\'s owner.');
    });

    test('Lua cannot remove a Dart listener by id even after Lua registers',
        () {
      final ls = LuaState.newState();
      ls.openLibs();

      var dartFired = 0;
      // Dart registers first → id 1.
      ls.on('mixed_id', (_) => dartFired++);

      // Lua registers → id 2.
      ls.doString(r'''
        local _ = event.on("mixed_id", function() end)
      ''');

      // Lua tries to remove the Dart listener by id 1.
      ls.doString(r'event.off("mixed_id", 1)');

      ls.emit('mixed_id');
      expect(dartFired, equals(1));
    });

    test('Lua can still remove its own listener by id', () {
      final ls = LuaState.newState();
      ls.openLibs();

      var dartFired = 0;
      ls.on('keep', (_) => dartFired++);

      ls.doString(r'''
        _lua_count = 0
        local id = event.on("keep", function() _lua_count = _lua_count + 1 end)
        event.emit("keep")       -- dartFired=1, _lua_count=1
        event.off("keep", id)    -- remove Lua's own listener
        event.emit("keep")       -- dartFired=2, _lua_count unchanged
      ''');

      expect(dartFired, equals(2));
      ls.getGlobal('_lua_count');
      expect(ls.toInteger(-1), equals(1));
    });

    test('Lua off(name, fn) cannot reach Dart listeners via fn-map', () {
      // The fn-map is only populated for Lua-registered functions, so a
      // Lua call of `event.off(name, fn)` for a function it did not
      // register can only no-op.  This test exercises that the fn-map
      // path never touches Dart entries.
      final ls = LuaState.newState();
      ls.openLibs();

      var fired = 0;
      ls.on('fnmap', (_) => fired++);

      ls.doString(r'''
        local function never_registered() end
        event.off("fnmap", never_registered)
        event.emit("fnmap")
      ''');

      expect(fired, equals(1));
    });

    // ------------------------------------------------------------------
    // Cross-coroutine: shared EventBus
    // ------------------------------------------------------------------

    test('coroutine event.on is visible to parent emit', () {
      // Coroutines share the registry and therefore must share the
      // EventBus too — otherwise a listener registered in a coroutine
      // would never fire on the parent's emit.
      final ls = LuaState.newState();
      ls.openLibs();

      ls.doString(r'''
        local co = coroutine.create(function()
          event.on("from_co", function() _fired = true end)
        end)
        coroutine.resume(co)

        -- Parent emits — should fire the coroutine's listener because
        -- the EventBus is shared.
        _fired = false
        event.emit("from_co")
      ''');

      ls.getGlobal('_fired');
      expect(ls.toBoolean(-1), isTrue);
    });

    test('parent emit fires coroutine-registered listener across yields',
        () {
      final ls = LuaState.newState();
      ls.openLibs();

      ls.doString(r'''
        _count = 0
        local co = coroutine.create(function()
          event.on("across_yield", function() _count = _count + 1 end)
          coroutine.yield()
          event.emit("across_yield")  -- coroutine can also emit
          coroutine.yield()
        end)
        coroutine.resume(co)  -- registers, yields
        event.emit("across_yield")  -- parent's emit (count → 1)
        coroutine.resume(co)  -- emits inside coroutine (count → 2), yields
        event.emit("across_yield")  -- parent's emit (count → 3)
      ''');

      ls.getGlobal('_count');
      expect(ls.toInteger(-1), equals(3));
    });

    test('coroutine off by id does not remove listener from a different '
        'thread that happens to have the same id (defense in depth)', () {
      // Each thread has its own id, and listeners are tagged with the
      // registering thread's id (ownerId).  So even with a shared bus,
      // thread A's `event.off(name, id)` cannot remove thread B's
      // listener by guessing id.
      final ls = LuaState.newState();
      ls.openLibs();

      ls.doString(r'''
        _count = 0
        local co = coroutine.create(function()
          local id = event.on("shared_bus", function() _count = _count + 1 end)
          _co_id = id
        end)
        coroutine.resume(co)
        -- Co registered a listener.  Now from the parent thread,
        -- try event.off("shared_bus", _co_id).  The parent thread's id
        -- differs from the coroutine's, so this must be a no-op.
        event.off("shared_bus", _co_id)
        event.emit("shared_bus")
      ''');

      ls.getGlobal('_count');
      expect(ls.toInteger(-1), equals(1),
          reason: 'Coroutine listener must survive parent thread\'s id-based '
              'removal attempt because ownerId does not match.');
    });

    test('coroutine off by fn can remove its own listener on the shared bus',
        () {
      // The fn-map lookup finds the ref by function identity, which is
      // independent of which thread registered it.  Cross-thread off by
      // fn is therefore allowed.
      final ls = LuaState.newState();
      ls.openLibs();

      ls.doString(r'''
        _count = 0
        local co_listener = function() _count = _count + 1 end
        local co = coroutine.create(function()
          event.on("by_fn", co_listener)
        end)
        coroutine.resume(co)
        -- Remove from the parent thread by function reference.
        event.off("by_fn", co_listener)
        event.emit("by_fn")
      ''');

      ls.getGlobal('_count');
      expect(ls.toInteger(-1), equals(0));
    });

    test('Dart-side emit fires listeners registered from coroutines', () {
      // Sanity check on the Dart-facing side of the shared bus.
      final ls = LuaState.newState();
      ls.openLibs();

      ls.doString(r'''
        local co = coroutine.create(function()
          event.on("dart_emit", function(v) _got = v end)
        end)
        coroutine.resume(co)
      ''');

      ls.emit('dart_emit', [42]);

      ls.getGlobal('_got');
      expect(ls.toInteger(-1), equals(42));
    });

    // ------------------------------------------------------------------
    // Async
    // ------------------------------------------------------------------

    test('emitAsync fires async Dart listeners', () async {
      final ls = LuaState.newState();
      ls.openLibs();

      final received = <String>[];
      ls.onAsync('async_test', (args) async {
        await Future.delayed(Duration(milliseconds: 10));
        received.add(args[0] as String);
      });

      await ls.emitAsync('async_test', ['hello']);
      expect(received, equals(['hello']));
    });

    test('emitAsync fires Lua listeners', () async {
      final ls = LuaState.newState();
      ls.openLibs();

      ls.doString(r'''
        _result = nil
        event.on("async_lua", function(v)
          _result = v
        end)
      ''');

      await ls.emitAsync('async_lua', [42]);

      ls.getGlobal('_result');
      expect(ls.toInteger(-1), equals(42));
    });

    // ------------------------------------------------------------------
    // Error handling
    // ------------------------------------------------------------------

    test('Dart listener error does not stop other listeners', () {
      final ls = LuaState.newState();
      ls.openLibs();

      var afterError = 0;
      ls.on('err', (_) => throw Exception('boom'));
      ls.on('err', (_) => afterError++);

      ls.emit('err');
      expect(afterError, equals(1));
    });

    test('Lua listener error does not stop other listeners', () {
      final ls = LuaState.newState();
      ls.openLibs();

      ls.doString(r'''
        _count = 0
        event.on("err_lua", function() error("boom") end)
        event.on("err_lua", function() _count = _count + 1 end)
        event.emit("err_lua")
      ''');

      ls.getGlobal('_count');
      expect(ls.toInteger(-1), equals(1));
    });

    // ------------------------------------------------------------------
    // Argument types
    // ------------------------------------------------------------------

    test('various argument types are passed correctly Dart → Lua', () {
      final ls = LuaState.newState();
      ls.openLibs();

      ls.doString(r'''
        _got_int = nil
        _got_float = nil
        _got_str = nil
        _got_bool = nil
        _got_nil = nil
        event.on("types", function(a, b, c, d, e)
          _got_int = a
          _got_float = b
          _got_str = c
          _got_bool = d
          _got_nil = e
        end)
      ''');

      ls.emit('types', [42, 3.14, 'hello', true, null]);

      ls.getGlobal('_got_int');
      expect(ls.toInteger(-1), equals(42));
      ls.pop(1);

      ls.getGlobal('_got_float');
      expect(ls.toNumber(-1), closeTo(3.14, 0.001));
      ls.pop(1);

      ls.getGlobal('_got_str');
      expect(ls.toStr(-1), equals('hello'));
      ls.pop(1);

      ls.getGlobal('_got_bool');
      expect(ls.toBoolean(-1), isTrue);
      ls.pop(1);

      ls.getGlobal('_got_nil');
      expect(ls.isNil(-1), isTrue);
    });

    test('various argument types are passed correctly Lua → Dart', () {
      final ls = LuaState.newState();
      ls.openLibs();

      final received = <List<dynamic>>[];
      ls.on('types2', (args) => received.add(args));

      ls.doString(r'event.emit("types2", 42, 3.14, "hello", true, nil)');

      expect(received.length, equals(1));
      expect(received[0][0], equals(42));
      expect(received[0][1], closeTo(3.14, 0.001));
      expect(received[0][2], equals('hello'));
      expect(received[0][3], equals(true));
      expect(received[0][4], isNull);
    });

    // ------------------------------------------------------------------
    // Edge cases
    // ------------------------------------------------------------------

    test('emit with no listeners does nothing', () {
      final ls = LuaState.newState();
      ls.openLibs();
      // Should not throw
      ls.emit('no_listeners', [1, 2, 3]);
    });

    test('emit with no args works', () {
      final ls = LuaState.newState();
      ls.openLibs();

      var fired = false;
      ls.on('no_args', (_) => fired = true);
      ls.emit('no_args');
      expect(fired, isTrue);
    });

    test('event module is available after openLibs', () {
      final ls = LuaState.newState();
      ls.openLibs();

      ls.doString(r'assert(type(event) == "table")');
      ls.doString(r'assert(type(event.on) == "function")');
      ls.doString(r'assert(type(event.off) == "function")');
      ls.doString(r'assert(type(event.emit) == "function")');
      ls.doString(r'assert(type(event.once) == "function")');
      ls.doString(r'assert(type(event.emitAsync) == "function")');
    });

    test('event.on returns an integer id', () {
      final ls = LuaState.newState();
      ls.openLibs();

      ls.doString(r'''
        local id = event.on("test", function() end)
        assert(type(id) == "number")
        assert(math.type(id) == "integer")
      ''');
    });
  });
}
