import 'package:luax/lua.dart';
import 'package:test/test.dart';

/// Helper: create a fresh Lua state with all standard libs opened,
/// execute [chunk], and return the first result as an integer.
int evalInt(LuaState ls, String chunk) {
  ls.loadString('return $chunk');
  ls.call(0, 1);
  final r = ls.toInteger(-1);
  ls.pop(1);
  return r;
}

/// Helper: create a fresh Lua state with all standard libs opened,
/// execute [chunk], and return the first result as a string.
String evalStr(LuaState ls, String chunk) {
  ls.loadString('return $chunk');
  ls.call(0, 1);
  final r = ls.toStr(-1)!;
  ls.pop(1);
  return r;
}

void main() {
  // -----------------------------------------------------------------------
  // utf8.char
  // -----------------------------------------------------------------------
  group('utf8.char', () {
    test('no arguments returns empty string', () {
      final ls = LuaState.newState();
      ls.openLibs();
      expect(evalStr(ls, "utf8.char()"), equals(''));
    });

    test('ASCII characters', () {
      final ls = LuaState.newState();
      ls.openLibs();
      expect(evalStr(ls, "utf8.char(65)"), equals('A'));
      expect(evalStr(ls, "utf8.char(97, 98, 99)"), equals('abc'));
    });

    test('U+7F (max single-byte UTF-8)', () {
      final ls = LuaState.newState();
      ls.openLibs();
      expect(evalStr(ls, 'utf8.char(0x7F)'), equals('\x7F'));
    });

    test('two-byte UTF-8 boundary (U+0080)', () {
      final ls = LuaState.newState();
      ls.openLibs();
      // utf8.char produces a Dart string — verify it round-trips
      final result = evalStr(ls, 'utf8.char(0x80)');
      expect(result.codeUnits, equals([0x80]));
      // Verify it decodes back correctly
      expect(evalInt(ls, 'utf8.codepoint(utf8.char(0x80))'), equals(0x80));
    });

    test('BMP character (U+4E16 = 世)', () {
      final ls = LuaState.newState();
      ls.openLibs();
      final result = evalStr(ls, 'utf8.char(0x4E16)');
      expect(result, equals('世'));
    });

    test('supplementary plane (U+10348)', () {
      final ls = LuaState.newState();
      ls.openLibs();
      final result = evalStr(ls, 'utf8.char(0x10348)');
      expect(result.runes.single, equals(0x10348));
    });

    test('max Unicode (U+10FFFF)', () {
      final ls = LuaState.newState();
      ls.openLibs();
      final result = evalStr(ls, 'utf8.char(0x10FFFF)');
      expect(result.runes.single, equals(0x10FFFF));
    });

    test('multiple code points concatenated', () {
      final ls = LuaState.newState();
      ls.openLibs();
      final r = evalStr(ls, 'utf8.char(65, 0x4E16)');
      expect(r, equals('A世'));
    });

    test('error on value out of range (negative)', () {
      final ls = LuaState.newState();
      ls.openLibs();
      ls.loadString('return utf8.char(-1)');
      expect(() => ls.call(0, 1), throwsA(anything));
    });

    test('error on value out of range (exceeds max)', () {
      final ls = LuaState.newState();
      ls.openLibs();
      ls.loadString('return utf8.char(0x110000)');
      expect(() => ls.call(0, 1), throwsA(anything));
    });
  });

  // -----------------------------------------------------------------------
  // utf8.codepoint
  // -----------------------------------------------------------------------
  group('utf8.codepoint', () {
    test('ASCII single character', () {
      final ls = LuaState.newState();
      ls.openLibs();
      expect(evalInt(ls, 'utf8.codepoint("A")'), equals(65));
    });

    test('Chinese character', () {
      final ls = LuaState.newState();
      ls.openLibs();
      expect(evalInt(ls, 'utf8.codepoint("世")'), equals(0x4E16));
    });

    test('multiple returns for range', () {
      final ls = LuaState.newState();
      ls.openLibs();
      ls.loadString('return utf8.codepoint("AB", 1, 2)');
      ls.call(0, 2);
      expect(ls.toInteger(-2), equals(65)); // first pushed
      expect(ls.toInteger(-1), equals(66));
      ls.pop(2);
    });

    test('default j is i', () {
      final ls = LuaState.newState();
      ls.openLibs();
      expect(evalInt(ls, 'utf8.codepoint("ABC", 2)'), equals(66));
    });

    test('empty interval returns nothing', () {
      final ls = LuaState.newState();
      ls.openLibs();
      ls.loadString('return utf8.codepoint("ABC", 3, 1)');
      ls.call(0, 0);
      expect(ls.getTop(), equals(0));
    });

    test('negative indices', () {
      final ls = LuaState.newState();
      ls.openLibs();
      expect(evalInt(ls, 'utf8.codepoint("ABC", -1)'), equals(67)); // C
      expect(evalInt(ls, 'utf8.codepoint("ABC", -2, -1)'), equals(66)); // B
    });

    test('two-byte UTF-8 boundary character (U+0080)', () {
      final ls = LuaState.newState();
      ls.openLibs();
      // Build string with utf8.char and decode back
      expect(evalInt(ls, 'utf8.codepoint(utf8.char(0x80))'), equals(0x80));
    });

    test('three-byte UTF-8 boundary (U+0800)', () {
      final ls = LuaState.newState();
      ls.openLibs();
      expect(evalInt(ls, 'utf8.codepoint(utf8.char(0x800))'), equals(0x800));
    });

    test('BMP character (世)', () {
      final ls = LuaState.newState();
      ls.openLibs();
      expect(evalInt(ls, 'utf8.codepoint("世")'), equals(0x4E16));
    });

    test('supplementary plane character round-trip', () {
      final ls = LuaState.newState();
      ls.openLibs();
      expect(
          evalInt(ls, 'utf8.codepoint(utf8.char(0x10348))'), equals(0x10348));
    });

    test('multi-byte string positions: each char starts at its position', () {
      final ls = LuaState.newState();
      ls.openLibs();
      // "AB世" → A(65) at 1, B(66) at 2, 世(0x4E16) at 3
      ls.loadString('return utf8.codepoint("AB世", 1, 3)');
      ls.call(0, 3);
      expect(ls.toInteger(-3), equals(65));
      expect(ls.toInteger(-2), equals(66));
      expect(ls.toInteger(-1), equals(0x4E16));
      ls.pop(3);
    });

    test('out of range position (zero)', () {
      final ls = LuaState.newState();
      ls.openLibs();
      ls.loadString('return utf8.codepoint("ABC", 0)');
      expect(() => ls.call(0, 1), throwsA(anything));
    });

    test('position past end', () {
      final ls = LuaState.newState();
      ls.openLibs();
      ls.loadString('return utf8.codepoint("ABC", 5)');
      expect(() => ls.call(0, 1), throwsA(anything));
    });
  });

  // -----------------------------------------------------------------------
  // utf8.len
  // -----------------------------------------------------------------------
  group('utf8.len', () {
    test('empty string has length 0', () {
      final ls = LuaState.newState();
      ls.openLibs();
      expect(evalInt(ls, 'utf8.len("")'), equals(0));
    });

    test('ASCII string', () {
      final ls = LuaState.newState();
      ls.openLibs();
      expect(evalInt(ls, 'utf8.len("hello")'), equals(5));
    });

    test('Chinese string', () {
      final ls = LuaState.newState();
      ls.openLibs();
      expect(evalInt(ls, 'utf8.len("你好")'), equals(2));
    });

    test('mixed ASCII and CJK', () {
      final ls = LuaState.newState();
      ls.openLibs();
      expect(evalInt(ls, 'utf8.len("Hi你好")'), equals(4));
    });

    test('supplementary plane character counts as 1', () {
      final ls = LuaState.newState();
      ls.openLibs();
      expect(
        evalInt(ls, 'utf8.len(utf8.char(0x10348))'),
        equals(1),
      );
    });

    test('explicit range', () {
      final ls = LuaState.newState();
      ls.openLibs();
      expect(evalInt(ls, 'utf8.len("ABC", 2, 2)'), equals(1));
    });

    test('range spanning multi-char', () {
      final ls = LuaState.newState();
      ls.openLibs();
      // "ABC" → range [1,2] → 2 characters
      expect(evalInt(ls, 'utf8.len("ABC", 1, 2)'), equals(2));
    });

    test('negative indices for range', () {
      final ls = LuaState.newState();
      ls.openLibs();
      expect(evalInt(ls, 'utf8.len("ABC", -2)'), equals(2));
    });

    test('out of range i', () {
      final ls = LuaState.newState();
      ls.openLibs();
      ls.loadString('return utf8.len("ABC", 10)');
      expect(() => ls.call(0, 1), throwsA(anything));
    });

    test('out of range j', () {
      final ls = LuaState.newState();
      ls.openLibs();
      ls.loadString('return utf8.len("ABC", 1, 10)');
      expect(() => ls.call(0, 1), throwsA(anything));
    });
  });

  // -----------------------------------------------------------------------
  // utf8.offset
  // -----------------------------------------------------------------------
  group('utf8.offset', () {
    test('first character is position 1', () {
      final ls = LuaState.newState();
      ls.openLibs();
      expect(evalInt(ls, 'utf8.offset("hello", 1)'), equals(1));
    });

    test('second character in ASCII', () {
      final ls = LuaState.newState();
      ls.openLibs();
      expect(evalInt(ls, 'utf8.offset("hello", 2)'), equals(2));
    });

    test('second character with CJK', () {
      final ls = LuaState.newState();
      ls.openLibs();
      // 你好: 你 at position 1, 好 at position 2 (both BMP, 1 code unit each)
      expect(evalInt(ls, 'utf8.offset("你好", 2)'), equals(2));
    });

    test('second character with supplementary plane', () {
      final ls = LuaState.newState();
      ls.openLibs();
      // "A𐍈B": A at 1, 𐍈 at 2 (takes 2 code units), B at 4
      final s = 'A\u{10348}B';
      expect(
        evalInt(ls, 'utf8.offset("$s", 2)'),
        equals(2),
      );
      expect(
        evalInt(ls, 'utf8.offset("$s", 3)'),
        equals(4),
      );
    });

    test('offset with explicit i parameter', () {
      final ls = LuaState.newState();
      ls.openLibs();
      expect(evalInt(ls, 'utf8.offset("hello", 1, 3)'), equals(3));
      expect(evalInt(ls, 'utf8.offset("hello", 2, 3)'), equals(4));
    });

    test('negative n goes backward', () {
      final ls = LuaState.newState();
      ls.openLibs();
      expect(evalInt(ls, 'utf8.offset("hello", -1)'), equals(5));
      expect(evalInt(ls, 'utf8.offset("hello", -2)'), equals(4));
    });

    test('negative n with multi-byte', () {
      final ls = LuaState.newState();
      ls.openLibs();
      // "你好": -1 → 好 at position 2, -2 → 你 at position 1
      expect(evalInt(ls, 'utf8.offset("你好", -1)'), equals(2));
      expect(evalInt(ls, 'utf8.offset("你好", -2)'), equals(1));
    });

    test('n = 0 finds beginning of current character (BMP)', () {
      final ls = LuaState.newState();
      ls.openLibs();
      // In "hello", n=0 at position 2 → char starts at 2
      expect(evalInt(ls, 'utf8.offset("hello", 0, 2)'), equals(2));
    });

    test('n = 0 finds beginning of current character (surrogate pair)', () {
      final ls = LuaState.newState();
      ls.openLibs();
      // "A𐍈B": 𐍈 starts at position 2. n=0 at position 3 (trail surrogate)
      // should return 2 (the start of 𐍈).
      final s = 'A\u{10348}B';
      expect(evalInt(ls, 'utf8.offset("$s", 0, 3)'), equals(2));
    });

    test('n beyond string returns nil', () {
      final ls = LuaState.newState();
      ls.openLibs();
      ls.loadString('return utf8.offset("hello", 10)');
      ls.call(0, 1);
      expect(ls.isNil(-1), isTrue);
      ls.pop(1);
    });

    test('negative n beyond beginning returns nil', () {
      final ls = LuaState.newState();
      ls.openLibs();
      ls.loadString('return utf8.offset("hello", -10)');
      ls.call(0, 1);
      expect(ls.isNil(-1), isTrue);
      ls.pop(1);
    });

    test('out of range position', () {
      final ls = LuaState.newState();
      ls.openLibs();
      ls.loadString('return utf8.offset("hello", 1, 10)');
      expect(() => ls.call(0, 1), throwsA(anything));
    });
  });

  // -----------------------------------------------------------------------
  // utf8.codes
  // -----------------------------------------------------------------------
  group('utf8.codes', () {
    test('iterate over ASCII string', () {
      final ls = LuaState.newState();
      ls.openLibs();
      ls.loadString(r'''
local t = {}
for p, c in utf8.codes("ABC") do
  t[#t+1] = c
end
return table.concat(t, ",")
''');
      ls.call(0, 1);
      expect(ls.toStr(-1), equals('65,66,67'));
      ls.pop(1);
    });

    test('iterate with positions', () {
      final ls = LuaState.newState();
      ls.openLibs();
      ls.loadString(r'''
local t = {}
for p, c in utf8.codes("AB") do
  t[#t+1] = p .. ":" .. c
end
return table.concat(t, ",")
''');
      ls.call(0, 1);
      expect(ls.toStr(-1), equals('1:65,2:66'));
      ls.pop(1);
    });

    test('iterate over multi-byte string', () {
      final ls = LuaState.newState();
      ls.openLibs();
      ls.loadString(r'''
local t = {}
for p, c in utf8.codes("你好") do
  t[#t+1] = p .. ":" .. c
end
return table.concat(t, ",")
''');
      ls.call(0, 1);
      expect(ls.toStr(-1), equals('1:20320,2:22909'));
      ls.pop(1);
    });

    test('iterate over supplementary plane character', () {
      final ls = LuaState.newState();
      ls.openLibs();
      // Build the string in Lua
      ls.loadString(r'''
local s = "A" .. utf8.char(0x10348) .. "B"
local t = {}
for p, c in utf8.codes(s) do
  t[#t+1] = p .. ":" .. c
end
return table.concat(t, ",")
''');
      ls.call(0, 1);
      expect(ls.toStr(-1), equals('1:65,2:66376,4:66'));
      ls.pop(1);
    });

    test('iterate over empty string returns nothing', () {
      final ls = LuaState.newState();
      ls.openLibs();
      ls.loadString(r'''
local count = 0
for p, c in utf8.codes("") do
  count = count + 1
end
return count
''');
      ls.call(0, 1);
      expect(ls.toInteger(-1), equals(0));
      ls.pop(1);
    });
  });

  // -----------------------------------------------------------------------
  // utf8.charpattern
  // -----------------------------------------------------------------------
  group('utf8.charpattern', () {
    test('charpattern is a string', () {
      final ls = LuaState.newState();
      ls.openLibs();
      ls.loadString('return type(utf8.charpattern)');
      ls.call(0, 1);
      expect(ls.toStr(-1), equals('string'));
      ls.pop(1);
    });

    test('charpattern is accessible as a constant', () {
      final ls = LuaState.newState();
      ls.openLibs();
      ls.loadString('return utf8.charpattern');
      ls.call(0, 1);
      final s = ls.toStr(-1)!;
      expect(s.isNotEmpty, isTrue);
      ls.pop(1);
    });
  });
}
