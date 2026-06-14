import 'dart:async';
import 'package:luax/lua.dart';
import 'package:test/test.dart';

void main() {
  group('Async Dart Function Tests', () {
    late LuaState lua;

    setUp(() {
      lua = LuaState.newState();
      lua.openLibs();
    });

    group('registerAsync()', () {
      test('should register async function and call via callAsync', () async {
        // Register an async Dart function
        lua.registerAsync('asyncAdd', (LuaState ls) async {
          final a = ls.toInteger(1);
          final b = ls.toInteger(2);
          // Simulate async operation
          await Future.delayed(Duration(milliseconds: 10));
          ls.pushInteger(a + b);
          return 1;
        });

        // Call from Dart using callAsync
        lua.getGlobal('asyncAdd');
        lua.pushInteger(10);
        lua.pushInteger(20);

        await lua.callAsync(2, 1);

        expect(lua.toInteger(-1), equals(30));
      });

      test('should handle async function returning multiple values', () async {
        lua.registerAsync('asyncMulti', (LuaState ls) async {
          await Future.delayed(Duration(milliseconds: 5));
          ls.pushString('hello');
          ls.pushInteger(42);
          ls.pushBoolean(true);
          return 3;
        });

        lua.getGlobal('asyncMulti');
        await lua.callAsync(0, 3);

        expect(lua.toBoolean(-1), isTrue);
        lua.pop(1);
        expect(lua.toInteger(-1), equals(42));
        lua.pop(1);
        expect(lua.toStr(-1), equals('hello'));
      });
    });

    group('pushDartFunctionAsync()', () {
      test('should push and call async function via callAsync', () async {
        lua.pushDartFunctionAsync((LuaState ls) async {
          await Future.delayed(Duration(milliseconds: 5));
          ls.pushString('async result');
          return 1;
        });
        lua.setGlobal('myAsyncFunc');

        lua.getGlobal('myAsyncFunc');
        await lua.callAsync(0, 1);

        expect(lua.toStr(-1), equals('async result'));
      });
    });

    group('pushDartClosureAsync()', () {
      test('should push async closure with upvalues', () async {
        // Push upvalue
        lua.pushInteger(100);

        // Push async closure with 1 upvalue
        lua.pushDartClosureAsync((LuaState ls) async {
          // Get upvalue
          final upvalue = ls.toInteger(luaUpvalueIndex(1));
          await Future.delayed(Duration(milliseconds: 5));
          ls.pushInteger(upvalue * 2);
          return 1;
        }, 1);
        lua.setGlobal('asyncClosure');

        lua.getGlobal('asyncClosure');
        await lua.callAsync(0, 1);

        expect(lua.toInteger(-1), equals(200));
      });
    });

    group('pCallAsync()', () {
      test('should handle successful async call', () async {
        lua.registerAsync('asyncOk', (LuaState ls) async {
          await Future.delayed(Duration(milliseconds: 5));
          ls.pushString('success');
          return 1;
        });

        lua.getGlobal('asyncOk');
        final status = await lua.pCallAsync(0, 1, 0);

        expect(status, equals(ThreadStatus.luaOk));
        expect(lua.toStr(-1), equals('success'));
      });

      test('should catch errors in async function', () async {
        lua.registerAsync('asyncError', (LuaState ls) async {
          await Future.delayed(Duration(milliseconds: 5));
          throw Exception('Async error!');
        });

        lua.getGlobal('asyncError');
        final status = await lua.pCallAsync(0, 0, 0);

        expect(status, equals(ThreadStatus.luaErrRun));
      });
    });

    group('doStringAsync()', () {
      test('should execute Lua code via pCallAsync', () async {
        // doStringAsync allows the top-level Lua function to be executed asynchronously
        // This is useful when Dart needs to await Lua code execution
        final success = await lua.doStringAsync('''
          x = 10
          y = 20
          result = x + y
        ''');

        expect(success, isTrue);
        lua.getGlobal('result');
        expect(lua.toNumber(-1), equals(30));
      });

      test('should return false on syntax error', () async {
        final success = await lua.doStringAsync('invalid lua code @@@@');
        expect(success, isFalse);
      });

      test('should return false on runtime error', () async {
        final success = await lua.doStringAsync('''
          error("test error")
        ''');
        expect(success, isFalse);
      });
    });

    group('doFileAsync()', () {
      test('should return false for non-existent file', () async {
        final success = await lua.doFileAsync('/non/existent/file.lua');
        expect(success, isFalse);
      });
    });

    group('Mixed sync/async calls from Dart', () {
      test('should call sync functions with callAsync', () async {
        lua.register('syncFunc', (LuaState ls) {
          ls.pushInteger(42);
          return 1;
        });

        lua.getGlobal('syncFunc');
        await lua.callAsync(0, 1);

        expect(lua.toInteger(-1), equals(42));
      });

      test('should work with Lua functions via callAsync', () async {
        lua.doString('''
          function luaFunc(x)
            return x * 2
          end
        ''');

        lua.getGlobal('luaFunc');
        lua.pushInteger(21);
        await lua.callAsync(1, 1);

        expect(lua.toInteger(-1), equals(42));
      });

      test('should handle Lua function returning multiple values', () async {
        lua.doString('''
          function multiReturn()
            return 1, 2, 3
          end
        ''');

        lua.getGlobal('multiReturn');
        await lua.callAsync(0, 3);

        expect(lua.toInteger(-1), equals(3));
        lua.pop(1);
        expect(lua.toInteger(-1), equals(2));
        lua.pop(1);
        expect(lua.toInteger(-1), equals(1));
      });
    });

    group('Async error handling', () {
      test('should propagate errors properly', () async {
        lua.registerAsync('failAsync', (LuaState ls) async {
          await Future.delayed(Duration(milliseconds: 5));
          throw StateError('async failure');
        });

        lua.getGlobal('failAsync');
        final status = await lua.pCallAsync(0, 0, 0);

        expect(status, equals(ThreadStatus.luaErrRun));
        // Error message should be on stack
        expect(lua.isString(-1), isTrue);
      });

      test('should handle errors thrown synchronously in async function',
          () async {
        lua.registerAsync('syncThrow', (LuaState ls) async {
          throw ArgumentError('sync throw in async');
        });

        lua.getGlobal('syncThrow');
        final status = await lua.pCallAsync(0, 0, 0);

        expect(status, equals(ThreadStatus.luaErrRun));
      });
    });

    group('Sequential async operations', () {
      test('should handle multiple sequential async calls from Dart', () async {
        var callCount = 0;

        lua.registerAsync('asyncIncrement', (LuaState ls) async {
          await Future.delayed(Duration(milliseconds: 5));
          callCount++;
          ls.pushInteger(callCount);
          return 1;
        });

        // First call
        lua.getGlobal('asyncIncrement');
        await lua.callAsync(0, 1);
        expect(lua.toInteger(-1), equals(1));
        lua.pop(1);

        // Second call
        lua.getGlobal('asyncIncrement');
        await lua.callAsync(0, 1);
        expect(lua.toInteger(-1), equals(2));
        lua.pop(1);

        // Third call
        lua.getGlobal('asyncIncrement');
        await lua.callAsync(0, 1);
        expect(lua.toInteger(-1), equals(3));
        lua.pop(1);

        expect(callCount, equals(3));
      });
    });

    group('Async with upvalues', () {
      test('should access multiple upvalues in async closure', () async {
        // Push upvalues
        lua.pushInteger(10);
        lua.pushString('hello');
        lua.pushBoolean(true);

        // Push async closure with 3 upvalues
        lua.pushDartClosureAsync((LuaState ls) async {
          await Future.delayed(Duration(milliseconds: 5));

          final num = ls.toInteger(luaUpvalueIndex(1));
          final str = ls.toStr(luaUpvalueIndex(2));
          final bool_ = ls.toBoolean(luaUpvalueIndex(3));

          ls.pushString('$num-$str-$bool_');
          return 1;
        }, 3);

        await lua.callAsync(0, 1);

        expect(lua.toStr(-1), equals('10-hello-true'));
      });
    });

    // =========================================================================
    //  Async calls FROM WITHIN Lua code  (regression: used to crash with
    //  "Null check operator used on a null value" because the synchronous
    //  VM instruction loop could not await async Dart closures)
    // =========================================================================

    group('Async calls from within Lua code', () {
      test('Lua code directly calling async Dart function via doStringAsync',
          () async {
        lua.registerAsync('asyncAdd', (LuaState ls) async {
          final a = ls.toInteger(1);
          final b = ls.toInteger(2);
          await Future.delayed(Duration(milliseconds: 10));
          ls.pushInteger(a + b);
          return 1;
        });

        final success = await lua.doStringAsync('''
          result = await asyncAdd(10, 20)
        ''');

        expect(success, isTrue);
        lua.getGlobal('result');
        expect(lua.toInteger(-1), equals(30));
      });

      test('Lua function wrapping async call via pCallAsync', () async {
        lua.registerAsync('fetchData', (LuaState ls) async {
          await Future.delayed(Duration(milliseconds: 10));
          ls.pushString('hello from async');
          return 1;
        });

        lua.doString('''
          function myHandler()
            return await fetchData()
          end
        ''');

        lua.getGlobal('myHandler');
        final status = await lua.pCallAsync(0, 1, 0);
        expect(status, equals(ThreadStatus.luaOk));
        expect(lua.toStr(-1), equals('hello from async'));
      });

      test('Lua handler with multiple sequential async calls', () async {
        var callCount = 0;
        lua.registerAsync('asyncIncrement', (LuaState ls) async {
          await Future.delayed(Duration(milliseconds: 5));
          callCount++;
          ls.pushInteger(callCount);
          return 1;
        });

        lua.doString('''
          function doThree()
            local a = await asyncIncrement()
            local b = await asyncIncrement()
            local c = await asyncIncrement()
            return a + b + c
          end
        ''');

        lua.getGlobal('doThree');
        final status = await lua.pCallAsync(0, 1, 0);
        expect(status, equals(ThreadStatus.luaOk));
        // 1 + 2 + 3 = 6
        expect(lua.toInteger(-1), equals(6));
        expect(callCount, equals(3));
      });

      test('Lua handler with conditional async calls', () async {
        lua.registerAsync('asyncDouble', (LuaState ls) async {
          await Future.delayed(Duration(milliseconds: 5));
          ls.pushInteger(ls.toInteger(1) * 2);
          return 1;
        });

        lua.doString('''
          function conditional(x)
            if x > 0 then
              return await asyncDouble(x)
            else
              return -1
            end
          end
        ''');

        // Positive path — triggers async call
        lua.getGlobal('conditional');
        lua.pushInteger(21);
        var status = await lua.pCallAsync(1, 1, 0);
        expect(status, equals(ThreadStatus.luaOk));
        expect(lua.toInteger(-1), equals(42));
        lua.pop(1);

        // Negative path — no async call
        lua.getGlobal('conditional');
        lua.pushInteger(-5);
        status = await lua.pCallAsync(1, 1, 0);
        expect(status, equals(ThreadStatus.luaOk));
        expect(lua.toInteger(-1), equals(-1));
      });

      test('async error propagates through Lua code via pCallAsync', () async {
        lua.registerAsync('asyncBoom', (LuaState ls) async {
          await Future.delayed(Duration(milliseconds: 5));
          throw StateError('async boom');
        });

        lua.doString('''
          function willFail()
            return await asyncBoom()
          end
        ''');

        lua.getGlobal('willFail');
        final status = await lua.pCallAsync(0, 1, 0);
        expect(status, equals(ThreadStatus.luaErrRun));
        // Error message should mention the StateError
        expect(lua.isString(-1), isTrue);
      });

      test('nested Lua function calling async Dart function', () async {
        lua.registerAsync('asyncGreet', (LuaState ls) async {
          await Future.delayed(Duration(milliseconds: 5));
          ls.pushString('Hello, ${ls.toStr(1)}!');
          return 1;
        });

        lua.doString('''
          function inner(name)
            return await asyncGreet(name)
          end
          function outer(name)
            return inner(name)
          end
        ''');

        lua.getGlobal('outer');
        lua.pushString('World');
        final status = await lua.pCallAsync(1, 1, 0);
        expect(status, equals(ThreadStatus.luaOk));
        expect(lua.toStr(-1), equals('Hello, World!'));
      });

      test('sync call() returns error tuple for async closures', () async {
        // With the new semantics, direct sync calls to an async closure
        // surface as the (nil, "attempt to call async function `name`
        // without await or in non-async context") tuple instead of throwing.
        lua.registerAsync('asyncOnly', (LuaState ls) async {
          ls.pushInteger(1);
          return 1;
        });

        lua.getGlobal('asyncOnly');
        // The sync call() path pushes the error tuple onto the stack; the
        // caller (here, an explicit test driver) reads both return values.
        lua.call(0, 2);
        expect(lua.isNil(-2), isTrue,
            reason: 'first return value should be nil');
        final err = lua.toStr(-1);
        expect(
            err,
            equals(
                "attempt to call async function `asyncOnly` without await or in non-async context"));
      });

      test('sync call() honours nResults for async closures', () {
        // nResults=1: pushes exactly 1 value (nil); the error string is
        // truncated because only one result slot was requested.
        lua.registerAsync('asyncOnly', (LuaState ls) async {
          ls.pushInteger(1);
          return 1;
        });

        lua.getGlobal('asyncOnly');
        final topBefore = lua.getTop();
        lua.call(0, 1);
        expect(lua.getTop() - topBefore, equals(0),
            reason:
                'call pops func (-1) and pushes 1 result (+1); net change 0');
        expect(lua.isNil(-1), isTrue,
            reason: 'single result should be nil (error truncated)');
        lua.pop(1);

        // nResults=0: nothing pushed (statement call); the function is
        // popped by call() so the stack shrinks by 1.
        lua.getGlobal('asyncOnly');
        final topBefore2 = lua.getTop();
        lua.call(0, 0);
        expect(lua.getTop() - topBefore2, equals(-1),
            reason: 'call pops func (-1) and pushes nothing; net change -1');
      });
    });

    // =========================================================================
    //  Direct (un-awaited) call from Lua: returns (nil, error) tuple
    // =========================================================================
    group('Direct async call returns error tuple', () {
      test('doStringAsync: direct call captures nil + error string', () async {
        lua.registerAsync('asyncAdd', (LuaState ls) async {
          ls.pushInteger(ls.toInteger(1) + ls.toInteger(2));
          return 1;
        });

        final ok = await lua.doStringAsync('''
          local r, err = asyncAdd(1, 2)
          HAS_ERR = err
          HAS_R   = r
        ''');
        expect(ok, isTrue);

        lua.getGlobal('HAS_R');
        expect(lua.isNil(-1), isTrue);
        lua.pop(1);

        lua.getGlobal('HAS_ERR');
        expect(
            lua.toStr(-1),
            equals(
                'attempt to call async function `asyncAdd` without await or in non-async context'));
      });

      test('single-result call: error string is truncated, only nil is kept',
          () async {
        lua.registerAsync('asyncMul', (LuaState ls) async {
          ls.pushInteger(ls.toInteger(1) * ls.toInteger(2));
          return 1;
        });

        final ok = await lua.doStringAsync('''
          local r = asyncMul(2, 3)
          ONLY_R = r
        ''');
        expect(ok, isTrue);

        lua.getGlobal('ONLY_R');
        expect(lua.isNil(-1), isTrue,
            reason: 'single-result call discards everything past nil');
      });

      test('statement call: error is discarded (matches Lua semantics)',
          () async {
        lua.registerAsync('asyncNoop', (LuaState ls) async {
          ls.pushInteger(7);
          return 1;
        });

        // Calling as a statement does not crash; the error tuple is dropped.
        final ok = await lua.doStringAsync('asyncNoop()');
        expect(ok, isTrue);
      });
    });

    // =========================================================================
    //  `await` keyword
    // =========================================================================
    group('await keyword', () {
      test('basic await', () async {
        lua.registerAsync('asyncAdd', (LuaState ls) async {
          ls.pushInteger(ls.toInteger(1) + ls.toInteger(2));
          return 1;
        });
        final ok = await lua.doStringAsync('X = await asyncAdd(7, 8)');
        expect(ok, isTrue);
        lua.getGlobal('X');
        expect(lua.toInteger(-1), equals(15));
      });

      test('await with multiple return values', () async {
        lua.registerAsync('asyncPair', (LuaState ls) async {
          ls.pushInteger(10);
          ls.pushInteger(20);
          return 2;
        });
        final ok = await lua.doStringAsync('A, B = await asyncPair()');
        expect(ok, isTrue);
        lua.getGlobal('A');
        expect(lua.toInteger(-1), equals(10));
        lua.pop(1);
        lua.getGlobal('B');
        expect(lua.toInteger(-1), equals(20));
      });

      test('nested await expressions', () async {
        lua.registerAsync('asyncAdd', (LuaState ls) async {
          ls.pushInteger(ls.toInteger(1) + ls.toInteger(2));
          return 1;
        });
        final ok = await lua
            .doStringAsync('X = await asyncAdd(await asyncAdd(1, 2), 3)');
        expect(ok, isTrue);
        lua.getGlobal('X');
        expect(lua.toInteger(-1), equals(6));
      });

      test('await on a sync host function is a no-op', () async {
        lua.register('syncAdd', (LuaState ls) {
          ls.pushInteger(ls.toInteger(1) + ls.toInteger(2));
          return 1;
        });
        final ok = await lua.doStringAsync('X = await syncAdd(3, 4)');
        expect(ok, isTrue);
        lua.getGlobal('X');
        expect(lua.toInteger(-1), equals(7));
      });

      test('await as a statement', () async {
        lua.registerAsync('asyncSideEffect', (LuaState ls) async {
          // No return values
          return 0;
        });
        final ok = await lua.doStringAsync('await asyncSideEffect()');
        expect(ok, isTrue);
      });

      test('await on method call (table field)', () async {
        lua.registerAsync('get', (LuaState ls) async {
          ls.pushInteger(42);
          return 1;
        });
        lua.doString('obj = { method = get }');
        final ok = await lua.doStringAsync('X = await obj.method()');
        expect(ok, isTrue);
        lua.getGlobal('X');
        expect(lua.toInteger(-1), equals(42));
      });
    });

    // =========================================================================
    //  Coroutine resume after await-call (regression: ACALL in resume guard)
    // =========================================================================
    group('coroutine resume after await-call', () {
      test('resumeAsync places resume args after yield inside awaited function',
          () async {
        // Regression: resume/resumeAsync checked the previous instruction's
        // opcode against "CALL" and "TAILCALL" but missed "ACALL". When a
        // coroutine yields inside a Lua function called via `await` (which
        // emits ACALL), the outer frame's unwinding must also recognise ACALL
        // to correctly place resume arguments into the result registers.
        lua.registerAsync('asyncDouble', (LuaState ls) async {
          await Future.delayed(Duration(milliseconds: 1));
          ls.pushInteger(ls.toInteger(1) * 2);
          return 1;
        });

        final code = '''
          local function inner(x)
            local r = asyncDouble(x)
            local v = coroutine.yield(r)
            return v
          end
          local co = coroutine.create(function()
            return inner(21)
          end)
          local ok1, val1 = await coroutine.resumeAsync(co)
          local ok2, val2 = await coroutine.resumeAsync(co, 100)
          return ok1, val1, ok2, val2
        ''';
        final loadOk = lua.loadString(code);
        expect(loadOk, equals(ThreadStatus.luaOk));
        final status = await lua.pCallAsync(0, 4, 0);
        expect(status, equals(ThreadStatus.luaOk));
        expect(lua.toBoolean(-4), isTrue,
            reason: 'first resume should succeed');
        expect(lua.toInteger(-3), equals(42),
            reason: 'yielded value should be asyncDouble(21) = 42');
        expect(lua.toBoolean(-2), isTrue,
            reason: 'second resume should succeed');
        expect(lua.toInteger(-1), equals(100),
            reason: 'resume arg should flow through yield into return value');
      });

      test('resumeAsync with await keyword and yield in nested call', () async {
        // Same scenario but using the `await` keyword explicitly inside the
        // coroutine body (ACALL at the body level rather than transparent
        // async dispatch).
        lua.registerAsync('asyncInc', (LuaState ls) async {
          await Future.delayed(Duration(milliseconds: 1));
          ls.pushInteger(ls.toInteger(1) + 1);
          return 1;
        });

        final code = '''
          local function worker(n)
            local r = await asyncInc(n)
            local v = coroutine.yield(r)
            return v + r
          end
          local co = coroutine.create(function()
            return worker(9)
          end)
          local ok1, val1 = await coroutine.resumeAsync(co)
          local ok2, val2 = await coroutine.resumeAsync(co, 50)
          return ok1, val1, ok2, val2
        ''';
        final loadOk = lua.loadString(code);
        expect(loadOk, equals(ThreadStatus.luaOk));
        final status = await lua.pCallAsync(0, 4, 0);
        expect(status, equals(ThreadStatus.luaOk));
        expect(lua.toBoolean(-4), isTrue);
        expect(lua.toInteger(-3), equals(10),
            reason: 'yielded value should be asyncInc(9) = 10');
        expect(lua.toBoolean(-2), isTrue);
        expect(lua.toInteger(-1), equals(60),
            reason: 'resume arg (50) + asyncInc result (10) = 60');
      });
    });
  });
}
