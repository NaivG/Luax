import 'package:lua_dardo_plus/lua.dart';
import 'package:test/test.dart';


bool testOS(){
  try{
    LuaState state = LuaState.newState();
    state.openLibs();
    state.loadString(r'''
local start = os.clock()

local s = 0
for i = 1, 100000 do
      s = s + i;
end

print('sec:'..(os.clock()-start)) 
''');
    state.pCall(0, 0, 1);
  }catch(e,s){
    print('$e\n$s');
    return false;
  }
  return true;
}

void main() {
  test('os.clock returns a small number (not epoch seconds)', () {
    LuaState ls = LuaState.newState();
    ls.openLibs();
    ls.loadString(r'return os.clock()');
    ls.call(0, 1);
    var clock = ls.toNumber(-1);
    // Should be process CPU-ish time, not epoch (which would be > 1e9)
    expect(clock, lessThan(1000000));
  });

  test('os.date with format string %Y-%m-%d', () {
    LuaState ls = LuaState.newState();
    ls.openLibs();
    ls.loadString(r'return os.date("%Y-%m-%d")');
    ls.call(0, 1);
    var result = ls.toStr(-1)!;
    // Should be like "2026-02-27", not "%Y-%m-%d"
    expect(result, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
  });

  test('os.date with format %H:%M:%S', () {
    LuaState ls = LuaState.newState();
    ls.openLibs();
    ls.loadString(r'return os.date("%H:%M:%S")');
    ls.call(0, 1);
    var result = ls.toStr(-1)!;
    expect(result, matches(RegExp(r'^\d{2}:\d{2}:\d{2}$')));
  });

  test('os.date with %A weekday name', () {
    LuaState ls = LuaState.newState();
    ls.openLibs();
    ls.loadString(r'return os.date("%A")');
    ls.call(0, 1);
    var result = ls.toStr(-1)!;
    expect(result, isNot(equals('%A')));
  });

  test('lua OS standard library test', () {
    expect(testOS(), true);
  });
}
