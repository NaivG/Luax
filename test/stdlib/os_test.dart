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

  test('lua OS standard library test', () {
    expect(testOS(), true);
  });
}
