import 'package:luax/lua.dart';
import 'package:test/test.dart';

/// Regression test: fn-map duplicate registration leaks refs.
///
/// When Lua registers the same function for the same event twice,
/// _refLuaFunction creates two separate registry refs (ref1, ref2)
/// but the fn-map table uses the function as key, so the second write
/// overwrites ref1 with ref2.  After event.off(name, fn):
///   - _lookupFnRef returns ref2 → only entry2 is removed from EventBus
///   - entry1 remains as a ghost listener, and ref1 is never unRef'd
void main() {
  test('duplicate on() with same fn does not leak ghost listener', () {
    final ls = LuaState.newState();
    ls.openLibs();

    // Define a named function so we can re-use the same reference.
    ls.doString(r'''
      _count = 0
      function _handler()
        _count = _count + 1
      end
      event.on("x", _handler)
      event.on("x", _handler)
    ''');

    // Both listeners should be registered — emit should fire twice.
    ls.doString(r'event.emit("x")');
    ls.getGlobal('_count');
    final countAfterEmit = ls.toInteger(-1);
    ls.pop(1);
    expect(countAfterEmit, equals(2),
        reason: 'two registrations should fire twice');

    // off by function should remove ALL registrations of that function.
    ls.doString(r'event.off("x", _handler)');

    // After off, emit should fire zero times (no ghost listeners).
    ls.doString(r'''
      _count = 0
      event.emit("x")
    ''');
    ls.getGlobal('_count');
    final countAfterOff = ls.toInteger(-1);
    ls.pop(1);
    expect(countAfterOff, equals(0),
        reason: 'off should remove all registrations; no ghost listeners');
  });

  test('duplicate once() with same fn does not leak', () {
    final ls = LuaState.newState();
    ls.openLibs();

    ls.doString(r'''
      _count = 0
      function _onceHandler()
        _count = _count + 1
      end
      event.once("z", _onceHandler)
      event.once("z", _onceHandler)
    ''');

    // First emit: both once-listeners should fire.
    ls.doString(r'event.emit("z")');
    ls.getGlobal('_count');
    expect(ls.toInteger(-1), equals(2));
    ls.pop(1);

    // Second emit: no listeners left.
    ls.doString(r'''
      _count = 0
      event.emit("z")
    ''');
    ls.getGlobal('_count');
    expect(ls.toInteger(-1), equals(0));
    ls.pop(1);
  });

  test('triple on() with same fn removes all on off()', () {
    final ls = LuaState.newState();
    ls.openLibs();

    ls.doString(r'''
      _count = 0
      function _tri()
        _count = _count + 1
      end
      event.on("t", _tri)
      event.on("t", _tri)
      event.on("t", _tri)
    ''');

    ls.doString(r'event.emit("t")');
    ls.getGlobal('_count');
    expect(ls.toInteger(-1), equals(3));
    ls.pop(1);

    ls.doString(r'event.off("t", _tri)');

    ls.doString(r'''
      _count = 0
      event.emit("t")
    ''');
    ls.getGlobal('_count');
    expect(ls.toInteger(-1), equals(0),
        reason: 'all three registrations should be removed');
    ls.pop(1);
  });
}
