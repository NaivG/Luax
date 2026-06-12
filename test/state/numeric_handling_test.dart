import 'package:luax/lua.dart';
import 'package:luax/src/state/comparison.dart';
import 'package:luax/src/state/lua_state_impl.dart';
import 'package:luax/src/state/lua_value.dart';
import 'package:test/test.dart';

void main() {
  group('LuaValue numeric handling', () {
    test('typeOf treats ints and doubles as numbers', () {
      expect(LuaValue.typeOf(1), equals(LuaType.luaNumber));
      expect(LuaValue.typeOf(1.5), equals(LuaType.luaNumber));
    });

    test('typeName treats ints and doubles as numbers', () {
      expect(LuaValue.typeName(1), equals('number'));
      expect(LuaValue.typeName(1.5), equals('number'));
    });

    test('toFloat converts ints and doubles', () {
      expect(LuaValue.toFloat(1), equals(1.0));
      expect(LuaValue.toFloat(1.5), equals(1.5));
    });
  });

  group('Comparison numeric handling', () {
    late LuaStateImpl ls;

    setUp(() {
      ls = LuaState.newState() as LuaStateImpl;
    });

    test('eq allows mixed int and double values', () {
      expect(Comparison.eq(1, 1.0, ls), isTrue);
      expect(Comparison.eq(1.0, 1, ls), isTrue);
      expect(Comparison.eq(1, 2.0, ls), isFalse);
    });

    test('lt allows mixed int and double values', () {
      expect(Comparison.lt(1, 1.5, ls), isTrue);
      expect(Comparison.lt(1.5, 2, ls), isTrue);
      expect(Comparison.lt(2, 1.5, ls), isFalse);
    });

    test('le allows mixed int and double values', () {
      expect(Comparison.le(1, 1.0, ls), isTrue);
      expect(Comparison.le(1.5, 2, ls), isTrue);
      expect(Comparison.le(2.5, 2, ls), isFalse);
    });
  });

  group('LuaState numeric conversions', () {
    late LuaState ls;

    setUp(() {
      ls = LuaState.newState();
    });

    test('toNumberX converts integers and doubles', () {
      ls.pushInteger(42);
      expect(ls.toNumberX(-1), equals(42.0));
      ls.pop(1);

      ls.pushNumber(2.5);
      expect(ls.toNumberX(-1), equals(2.5));
    });

    test('toStr converts integers and doubles', () {
      ls.pushInteger(42);
      expect(ls.toStr(-1), equals('42'));
      ls.pop(1);

      ls.pushNumber(2.5);
      expect(ls.toStr(-1), equals('2.5'));
    });
  });
}
