import 'package:lua_dardo_plus/lua.dart';
import 'package:test/test.dart';

void main() {
  group('goto/label', () {
    test('forward goto skips code', () {
      LuaState state = LuaState.newState();
      state.openLibs();

      state.loadString(r'''
        local x = 1
        goto skip
        x = 2
        ::skip::
        return x
      ''');
      state.pCall(0, 1, 0);
      expect(state.toInteger(-1), equals(1));
    });

    test('backward goto creates a loop', () {
      LuaState state = LuaState.newState();
      state.openLibs();

      state.loadString(r'''
        local i = 0
        ::loop::
        i = i + 1
        if i < 5 then
          goto loop
        end
        return i
      ''');
      state.pCall(0, 1, 0);
      expect(state.toInteger(-1), equals(5));
    });

    test('goto out of do-end block', () {
      LuaState state = LuaState.newState();
      state.openLibs();

      state.loadString(r'''
        local x = 0
        do
          x = 1
          goto done
          x = 2
        end
        ::done::
        return x
      ''');
      state.pCall(0, 1, 0);
      expect(state.toInteger(-1), equals(1));
    });

    test('goto out of nested blocks', () {
      LuaState state = LuaState.newState();
      state.openLibs();

      state.loadString(r'''
        local result = 0
        do
          do
            result = 42
            goto done
          end
          result = 99
        end
        ::done::
        return result
      ''');
      state.pCall(0, 1, 0);
      expect(state.toInteger(-1), equals(42));
    });

    test('multiple labels', () {
      LuaState state = LuaState.newState();
      state.openLibs();

      state.loadString(r'''
        local x = 0
        goto first
        ::second::
        x = x + 10
        goto done
        ::first::
        x = x + 1
        goto second
        ::done::
        return x
      ''');
      state.pCall(0, 1, 0);
      expect(state.toInteger(-1), equals(11));
    });

    test('goto inside if-then', () {
      LuaState state = LuaState.newState();
      state.openLibs();

      state.loadString(r'''
        local x = 0
        if true then
          goto skip
        end
        x = 99
        ::skip::
        return x
      ''');
      state.pCall(0, 1, 0);
      expect(state.toInteger(-1), equals(0));
    });

    test('backward goto with accumulator (manual loop)', () {
      LuaState state = LuaState.newState();
      state.openLibs();

      state.loadString(r'''
        local sum = 0
        local i = 1
        ::loop::
        if i > 10 then goto done end
        sum = sum + i
        i = i + 1
        goto loop
        ::done::
        return sum
      ''');
      state.pCall(0, 1, 0);
      expect(state.toInteger(-1), equals(55));
    });

    test('goto in function body', () {
      LuaState state = LuaState.newState();
      state.openLibs();

      state.loadString(r'''
        function f(n)
          if n <= 0 then goto done end
          do return n end
          ::done::
          return 0
        end
        return f(5) + f(0)
      ''');
      state.pCall(0, 1, 0);
      expect(state.toInteger(-1), equals(5));
    });

    test('label in same scope as goto (different blocks OK)', () {
      LuaState state = LuaState.newState();
      state.openLibs();

      // Labels in separate do-end blocks at the same scope level
      // should not conflict
      state.loadString(r'''
        local x = 0
        do
          goto a
          ::a::
        end
        do
          goto a
          ::a::
        end
        return 1
      ''');
      state.pCall(0, 1, 0);
      expect(state.toInteger(-1), equals(1));
    });

    test('error: unresolved goto', () {
      LuaState state = LuaState.newState();
      state.openLibs();

      // goto to a label that doesn't exist should error at compile time
      expect(
        () => state.loadString(r'''
          goto nonexistent
        '''),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('nonexistent'),
        )),
      );
    });

    test('error: goto jumps over local variable', () {
      LuaState state = LuaState.newState();
      state.openLibs();

      expect(
        () => state.loadString(r'''
          goto skip
          local x = 1
          ::skip::
        '''),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('local variable'),
        )),
      );
    });

    test('goto with do-end does not jump over locals in outer scope', () {
      // goto into a position where no new locals were added
      // at the target scope should be fine
      LuaState state = LuaState.newState();
      state.openLibs();

      state.loadString(r'''
        local x = 1
        do
          goto skip
        end
        ::skip::
        return x
      ''');
      state.pCall(0, 1, 0);
      expect(state.toInteger(-1), equals(1));
    });

    test('forward goto over do-end block with locals inside is OK', () {
      // Locals inside a do-end block are freed when the block exits,
      // so jumping over the entire block is fine.
      LuaState state = LuaState.newState();
      state.openLibs();

      state.loadString(r'''
        local x = 1
        goto skip
        do
          local y = 2
        end
        ::skip::
        return x
      ''');
      state.pCall(0, 1, 0);
      expect(state.toInteger(-1), equals(1));
    });

    test('complex: state machine with goto', () {
      LuaState state = LuaState.newState();
      state.openLibs();

      state.loadString(r'''
        local result = ""
        local state = "start"

        ::start::
        if state == "start" then
          result = result .. "A"
          state = "middle"
          goto middle
        end

        ::middle::
        if state == "middle" then
          result = result .. "B"
          state = "finish"
          goto finish
        end

        ::finish::
        if state == "finish" then
          result = result .. "C"
        end

        return result
      ''');
      state.pCall(0, 1, 0);
      expect(state.toStr(-1), equals("ABC"));
    });
  });
}
