import 'dart:async';

import 'package:luax/lua.dart';
import 'package:test/test.dart';

void main() {
  group('Coroutine Tests', () {
    late LuaState ls;

    setUp(() {
      ls = LuaState.newState();
      ls.openLibs();
    });

    test('coroutine.create returns a thread', () {
      final code = '''
        local co = coroutine.create(function() end)
        return type(co)
      ''';
      ls.loadString(code);
      ls.pCall(0, 1, 0);
      expect(ls.toStr(-1), equals('thread'));
    });

    test('coroutine.status returns correct status', () {
      final code = '''
        local co = coroutine.create(function() end)
        return coroutine.status(co)
      ''';
      ls.loadString(code);
      ls.pCall(0, 1, 0);
      expect(ls.toStr(-1), equals('suspended'));
    });

    test('coroutine.resume starts coroutine', () {
      final code = '''
        local result = 0
        local co = coroutine.create(function()
          result = 42
        end)
        coroutine.resume(co)
        return result
      ''';
      ls.loadString(code);
      ls.pCall(0, 1, 0);
      expect(ls.toInteger(-1), equals(42));
    });

    test('coroutine.resume returns true on success', () {
      final code = '''
        local co = coroutine.create(function() end)
        local ok = coroutine.resume(co)
        return ok
      ''';
      ls.loadString(code);
      ls.pCall(0, 1, 0);
      expect(ls.toBoolean(-1), isTrue);
    });

    test('coroutine with arguments', () {
      final code = '''
        local co = coroutine.create(function(a, b)
          return a + b
        end)
        local ok, result = coroutine.resume(co, 10, 20)
        return result
      ''';
      ls.loadString(code);
      ls.pCall(0, 1, 0);
      expect(ls.toInteger(-1), equals(30));
    });

    test('coroutine.yield basic', () {
      final code = '''
        local co = coroutine.create(function()
          coroutine.yield(1)
          coroutine.yield(2)
          return 3
        end)
        local ok1, v1 = coroutine.resume(co)
        local ok2, v2 = coroutine.resume(co)
        local ok3, v3 = coroutine.resume(co)
        return v1, v2, v3
      ''';
      ls.loadString(code);
      ls.pCall(0, 3, 0);
      expect(ls.toInteger(-3), equals(1));
      expect(ls.toInteger(-2), equals(2));
      expect(ls.toInteger(-1), equals(3));
    });

    test('coroutine.status after completion', () {
      final code = '''
        local co = coroutine.create(function() end)
        coroutine.resume(co)
        return coroutine.status(co)
      ''';
      ls.loadString(code);
      ls.pCall(0, 1, 0);
      expect(ls.toStr(-1), equals('dead'));
    });

    test('coroutine.running returns current thread', () {
      final code = '''
        local co = coroutine.running()
        return type(co)
      ''';
      ls.loadString(code);
      ls.pCall(0, 1, 0);
      expect(ls.toStr(-1), equals('thread'));
    });

    test('coroutine.wrap creates resumable function', () {
      final code = '''
        local f = coroutine.wrap(function()
          coroutine.yield(100)
          return 200
        end)
        local v1 = f()
        local v2 = f()
        return v1, v2
      ''';
      ls.loadString(code);
      ls.pCall(0, 2, 0);
      expect(ls.toInteger(-2), equals(100));
      expect(ls.toInteger(-1), equals(200));
    });

    test('cannot resume dead coroutine', () {
      final code = '''
        local co = coroutine.create(function() end)
        coroutine.resume(co)  -- finishes
        local ok, msg = coroutine.resume(co)  -- try again
        return ok, msg
      ''';
      ls.loadString(code);
      ls.pCall(0, 2, 0);
      expect(ls.toBoolean(-2), isFalse);
      expect(ls.toStr(-1), contains('dead'));
    });

    test(
        'coroutine body can call host async function without await via resumeAsync',
        () async {
      // Inside a coroutine, direct calls to host async functions are
      // transparent: the coroutine suspension point (coroutine.resumeAsync)
      // acts as the `await` keyword.
      ls.registerAsync('asyncGreet', (LuaState ls) async {
        await Future.delayed(Duration(milliseconds: 5));
        ls.pushString('Hello, ${ls.toStr(1)}!');
        return 1;
      });

      final code = '''
        local co = coroutine.create(function(name)
          -- Direct call (no `await`) — would be an error tuple on the main
          -- thread, but inside a coroutine body it is awaited transparently.
          return asyncGreet(name)
        end)
        local ok, msg = await coroutine.resumeAsync(co, 'World')
        return ok, msg
      ''';
      final loadOk = ls.loadString(code);
      expect(loadOk, equals(ThreadStatus.luaOk));
      final status = await ls.pCallAsync(0, 2, 0);
      expect(status, equals(ThreadStatus.luaOk));
      expect(ls.toBoolean(-2), isTrue);
      expect(ls.toStr(-1), equals('Hello, World!'));
    });

    test('coroutine.resumeAsync returns yielded values', () async {
      // The async counterpart of coroutine.resume must still surface
      // coroutine.yield's values to the caller.
      final code = '''
        local co = coroutine.create(function()
          coroutine.yield(1, 2, 3)
          coroutine.yield(4, 5, 6)
        end)
        local ok1, a, b, c = await coroutine.resumeAsync(co)
        local ok2, d, e, f = await coroutine.resumeAsync(co)
        return a + b + c, d + e + f
      ''';
      final loadOk = ls.loadString(code);
      expect(loadOk, equals(ThreadStatus.luaOk));
      final status = await ls.pCallAsync(0, 2, 0);
      expect(status, equals(ThreadStatus.luaOk));
      expect(ls.toInteger(-2), equals(6));
      expect(ls.toInteger(-1), equals(15));
    });

    test('coroutine.resumeAsync propagates errors as (false, msg)', () async {
      final code = '''
        local co = coroutine.create(function()
          error('boom')
        end)
        local ok, msg = await coroutine.resumeAsync(co)
        return ok, msg
      ''';
      final loadOk = ls.loadString(code);
      expect(loadOk, equals(ThreadStatus.luaOk));
      final status = await ls.pCallAsync(0, 2, 0);
      expect(status, equals(ThreadStatus.luaOk));
      expect(ls.toBoolean(-2), isFalse);
      expect(ls.toStr(-1), contains('boom'));
    });
  });
}
