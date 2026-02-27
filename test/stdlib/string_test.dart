import 'package:lua_dardo_plus/lua.dart';
import 'package:test/test.dart';


bool testString(){
  try{
    LuaState state = LuaState.newState();
    state.openLibs();
    state.loadString(r'''
--[[
multi-line comments
multi-line comments
]]

a = [[abc
123]]
b = [==[
abc
123]==]
print(a)
print(b)
str = 'a string with "quotes" and \n new line\r\n'
print(str)
print(string.gsub("hello world", "(%w+)", "%1 %1"))
print(string.len("abc"))
print(string.byte("abcABC", 1, 6))
print(string.char(97, 98, 99))
print(string.upper("acde"))
print(string.find("8Abc%a23", "%a"))
print(string.find("8Abc%a23", "(%a)"))
print(string.find("8Abc%a23", "(%a)", 4))
print(string.find("8Abc%a23", "%a", 1, true))
print(string.find("8Abca23", "Ab"))
print(string.match("abc123ABC456", "ABC"))
''');
    state.pCall(0, 0, 1);
  }catch(e,s){
    print('$e\n$s');
    return false;
  }
  return true;
}

void main() {
  test('string.reverse reverses a multi-char string', () {
    LuaState ls = LuaState.newState();
    ls.openLibs();
    ls.loadString(r'return string.reverse("hello")');
    ls.call(0, 1);
    expect(ls.toStr(-1), equals('olleh'));
  });

  test('string.reverse handles single char', () {
    LuaState ls = LuaState.newState();
    ls.openLibs();
    ls.loadString(r'return string.reverse("a")');
    ls.call(0, 1);
    expect(ls.toStr(-1), equals('a'));
  });

  test('string.reverse handles empty string', () {
    LuaState ls = LuaState.newState();
    ls.openLibs();
    ls.loadString(r'return string.reverse("")');
    ls.call(0, 1);
    expect(ls.toStr(-1), equals(''));
  });

  test('string.find end pos: pattern length != match length', () {
    LuaState ls = LuaState.newState();
    ls.openLibs();
    ls.loadString(r'return string.find("ab12cd", "%d%d")');
    ls.call(0, 2);
    expect(ls.toInteger(-2), equals(3));
    expect(ls.toInteger(-1), equals(4));
  });

  test('string.find returns correct end position with pattern', () {
    LuaState ls = LuaState.newState();
    ls.openLibs();
    ls.loadString(r'return string.find("abc123def", "%d+")');
    ls.call(0, 2);
    expect(ls.toInteger(-2), equals(4));
    expect(ls.toInteger(-1), equals(6));
  });

  test('string.find returns correct end position with plain search', () {
    LuaState ls = LuaState.newState();
    ls.openLibs();
    ls.loadString(r'return string.find("hello world", "world", 1, true)');
    ls.call(0, 2);
    expect(ls.toInteger(-2), equals(7));
    expect(ls.toInteger(-1), equals(11));
  });

  test('string.format %e', () {
    LuaState ls = LuaState.newState();
    ls.openLibs();
    ls.loadString(r'return string.format("%e", 314.0)');
    ls.call(0, 1);
    expect(ls.toStr(-1), contains('14'));
  });

  test('string.format %g', () {
    LuaState ls = LuaState.newState();
    ls.openLibs();
    ls.loadString(r'return string.format("%g", 3.14)');
    ls.call(0, 1);
    expect(ls.toStr(-1), equals('3.14'));
  });

  test('string.format %E', () {
    LuaState ls = LuaState.newState();
    ls.openLibs();
    ls.loadString(r'return string.format("%E", 314.0)');
    ls.call(0, 1);
    expect(ls.toStr(-1), contains('14'));
  });

  test('string.format %G', () {
    LuaState ls = LuaState.newState();
    ls.openLibs();
    ls.loadString(r'return string.format("%G", 3.14)');
    ls.call(0, 1);
    expect(ls.toStr(-1), equals('3.14'));
  });

  test('string.gmatch basic iteration', () {
    LuaState ls = LuaState.newState();
    ls.openLibs();
    ls.loadString(r'''
      local result = {}
      for w in string.gmatch("hello world foo", "%a+") do
        result[#result + 1] = w
      end
      return result[1], result[2], result[3]
    ''');
    ls.call(0, 3);
    expect(ls.toStr(-3), equals('hello'));
    expect(ls.toStr(-2), equals('world'));
    expect(ls.toStr(-1), equals('foo'));
  });

  test('string.gmatch with captures', () {
    LuaState ls = LuaState.newState();
    ls.openLibs();
    ls.loadString(r'''
      local keys = {}
      local vals = {}
      for k, v in string.gmatch("a=1, b=2, c=3", "(%a)=(%d)") do
        keys[#keys + 1] = k
        vals[#vals + 1] = v
      end
      return keys[1], vals[1], keys[2], vals[2], keys[3], vals[3]
    ''');
    ls.call(0, 6);
    expect(ls.toStr(-6), equals('a'));
    expect(ls.toStr(-5), equals('1'));
    expect(ls.toStr(-4), equals('b'));
    expect(ls.toStr(-3), equals('2'));
    expect(ls.toStr(-2), equals('c'));
    expect(ls.toStr(-1), equals('3'));
  });

  test('string.gmatch capture text appears before match', () {
    LuaState ls = LuaState.newState();
    ls.openLibs();
    ls.loadString(r'''
      local result = {}
      for w in string.gmatch("1a1", "a(%d)") do
        result[#result + 1] = w
      end
      return #result, result[1]
    ''');
    ls.call(0, 2);
    expect(ls.toInteger(-2), equals(1));
    expect(ls.toStr(-1), equals('1'));
  });

  test('string.gmatch no infinite loop on empty match', () {
    LuaState ls = LuaState.newState();
    ls.openLibs();
    ls.loadString(r'''
      local count = 0
      for w in string.gmatch("abc", ".-") do
        count = count + 1
        if count > 10 then break end
      end
      return count
    ''');
    ls.call(0, 1);
    expect(ls.toInteger(-1), lessThan(11));
  });

  test('string.gsub with capture back-references', () {
    LuaState ls = LuaState.newState();
    ls.openLibs();
    ls.loadString(r'return string.gsub("hello", "(h)", "%1%1")');
    ls.call(0, 2);
    expect(ls.toStr(-2), equals('hhello'));
  });

  test('string.gsub with multiple capture back-references', () {
    LuaState ls = LuaState.newState();
    ls.openLibs();
    ls.loadString(r'return string.gsub("abc", "(a)(b)", "%2%1")');
    ls.call(0, 2);
    expect(ls.toStr(-2), equals('bac'));
  });

  test('string.gsub %0 refers to whole match', () {
    LuaState ls = LuaState.newState();
    ls.openLibs();
    ls.loadString(r'return string.gsub("hello", "(%w+)", "[%0]")');
    ls.call(0, 2);
    expect(ls.toStr(-2), equals('[hello]'));
  });

  test('hex float literal with negative exponent', () {
    LuaState ls = LuaState.newState();
    ls.openLibs();
    ls.loadString(r'return 0x1p-3');
    ls.call(0, 1);
    expect(ls.toNumber(-1), equals(0.125));
  });

  test('float literal with negative exponent', () {
    LuaState ls = LuaState.newState();
    ls.openLibs();
    ls.loadString(r'return 1e-2');
    ls.call(0, 1);
    expect(ls.toNumber(-1), equals(0.01));
  });

  test('hex float with positive exponent', () {
    LuaState ls = LuaState.newState();
    ls.openLibs();
    ls.loadString(r'return 0x1p4');
    ls.call(0, 1);
    expect(ls.toNumber(-1), equals(16.0));
  });

  test('lua table standard library test', () {
    expect(testString(), true);
  });
}
