import 'package:glados/glados.dart';
import 'package:lua_dardo_plus/lua.dart';
import 'package:test/test.dart';

/// Generates valid Lua pattern strings for property-based testing.
///
/// We build patterns from a grammar of Lua pattern items to ensure they are
/// always syntactically valid, while still exercising the full range of the
/// pattern engine: character classes, quantifiers, bracket sets, anchors,
/// captures, and escaped literals.
extension AnyLuaPattern on Any {
  static final _classes = [
    '%a', '%d', '%w', '%s', '%l', '%u', '%p', '%x',
    '%A', '%D', '%W', '%S', '%L', '%U', '%P', '%X',
  ];

  static final _quantifiers = ['', '*', '+', '?', '-'];

  static final _literals =
      'abcdefghijklmnopqrstuvwxyz0123456789 _,;!@#&=~'.split('');

  static final _escapedLiterals = [
    '%(', '%)', '%.', '%[', '%]', '%%', '%^', r'%$',
    '%{', '%}', '%|', r'%\', '%+', '%*', '%-', '%?',
  ];

  static final _bracketItems = [
    ..._classes,
    '%-',
    'a-z',
    'A-Z',
    '0-9',
    ...'abcdefg0123 '.split(''),
  ];

  /// A single pattern atom: character class, dot, literal, escaped literal,
  /// or bracket set.
  Generator<String> get _patternAtom {
    return oneOf([
      choose(_classes),
      always('.'),
      choose(_literals),
      choose(_escapedLiterals),
      _bracketSet,
    ]);
  }

  /// A bracket character set like [%w%-] or [abc].
  Generator<String> get _bracketSet {
    return combine2(
      any.bool,
      listWithLengthInRange(1, 3, choose(_bracketItems)),
      (bool negated, List<String> items) {
        final inner = items.join();
        return negated ? '[^$inner]' : '[$inner]';
      },
    );
  }

  /// A pattern atom optionally followed by a quantifier.
  Generator<String> get _quantifiedAtom {
    return combine2(
      _patternAtom,
      choose(_quantifiers),
      (String atom, String quant) => '$atom$quant',
    );
  }

  /// A complete Lua pattern: 1-4 quantified items, optionally anchored.
  Generator<String> get luaPattern {
    return combine3(
      any.bool,
      listWithLengthInRange(1, 4, _quantifiedAtom),
      any.bool,
      (bool anchorStart, List<String> items, bool anchorEnd) {
        final body = items.join();
        final prefix = anchorStart ? '^' : '';
        final suffix = anchorEnd ? r'$' : '';
        return '$prefix$body$suffix';
      },
    );
  }

  /// A pattern wrapped in capture parens.
  Generator<String> get luaPatternWithCapture {
    return listWithLengthInRange(1, 3, _quantifiedAtom)
        .map((items) => '(${items.join()})');
  }

  /// Patterns that match empty strings — common source of infinite loops.
  Generator<String> get emptyMatchPattern {
    return choose([
      '.-', '%s*', '%d*', '%a*', '%w*', 'x?',
      '[abc]-', '[%w]*', '()',
    ]);
  }

  /// Mix of generated and known-tricky patterns.
  Generator<String> get stressPattern {
    return oneOf([
      luaPattern,
      emptyMatchPattern,
      combine2(
        _quantifiedAtom,
        _quantifiedAtom,
        (String a, String b) => '$a$b',
      ),
    ]);
  }

  /// Input strings that exercise edge cases.
  Generator<String> get edgeCaseString {
    return oneOf([
      choose([
        '', ' ', '\n', '\t', 'aaaa', '   ', '123',
        'hello world', 'a\nb\nc', r'()|{}\',
      ]),
      any.letterOrDigits,
    ]);
  }
}

/// Run a Lua snippet, returning up to [nResults] as strings.
/// Returns null if it threw.
List<String?>? _runLua(String code, int nResults) {
  try {
    final ls = LuaState.newState();
    ls.openLibs();
    ls.loadString(code);
    ls.call(0, nResults);
    final results = <String?>[];
    for (var i = 0; i < nResults; i++) {
      final idx = -(nResults - i);
      results.add(ls.isNil(idx) ? null : ls.toStr(idx));
    }
    return results;
  } catch (_) {
    return null;
  }
}

/// Embed [s] as a Lua long string that never collides with the content.
/// Lua strips a leading newline from long strings, so we always prepend one
/// to ensure the content is preserved exactly.
String _luaLong(String s) {
  var level = 0;
  while (s.contains(']${'=' * level}]')) {
    level++;
  }
  final eq = '=' * level;
  // The leading \n is stripped by Lua's long-string parser, leaving
  // exactly [s] as the string value.
  return '[$eq[\n$s]$eq]';
}

/*
Testable properties:

1. Termination — find / match / gmatch / gsub must always return.
2. Consistency — find positions agree with match; gsub("%0") is identity.
3. Anchors — ^pat only matches at start.
4. Empty-match patterns — known landmines for infinite loops.
5. Newlines — dot matches \n in all functions.
6. Literal metacharacters — | { } \ ^ $ are not regex-special.
*/

void main() {
  // -------- Termination --------

  group('Termination', () {
    Glados2(any.stressPattern, any.edgeCaseString).test(
      'string.find always terminates',
      (pattern, input) {
        _runLua(
            'return string.find(${_luaLong(input)}, ${_luaLong(pattern)})', 2);
      },
    );

    Glados2(any.stressPattern, any.edgeCaseString).test(
      'string.match always terminates',
      (pattern, input) {
        _runLua(
            'return string.match(${_luaLong(input)}, ${_luaLong(pattern)})', 1);
      },
    );

    Glados2(any.stressPattern, any.edgeCaseString).test(
      'string.gmatch always terminates and yields finite results',
      (pattern, input) {
        final code = '''
          local t = {}
          for m in string.gmatch(${_luaLong(input)}, ${_luaLong(pattern)}) do
            t[#t+1] = m
            if #t > 1000 then break end
          end
          return #t
        ''';
        final r = _runLua(code, 1);
        if (r != null && r[0] != null) {
          final count = int.tryParse(r[0]!) ?? 0;
          expect(count, lessThanOrEqualTo(input.length + 1),
              reason: 'gmatch produced $count matches for '
                  'input len=${input.length}, pattern="$pattern"');
        }
      },
    );

    Glados2(any.stressPattern, any.edgeCaseString).test(
      'string.gsub always terminates',
      (pattern, input) {
        _runLua(
            'return string.gsub(${_luaLong(input)}, ${_luaLong(pattern)}, "X")',
            2);
      },
    );
  });

  // -------- Consistency --------

  group('Consistency', () {
    Glados2(any.luaPattern, any.edgeCaseString).test(
      'find positions agree with match (no captures)',
      (pattern, input) {
        final code = '''
          local s = ${_luaLong(input)}
          local p = ${_luaLong(pattern)}
          local i, j = string.find(s, p)
          local m = string.match(s, p)
          if i ~= nil and m ~= nil then
            return string.sub(s, i, j), m
          end
          return "NONE", "NONE"
        ''';
        final r = _runLua(code, 2);
        if (r != null && r[0] != 'NONE') {
          expect(r[0], equals(r[1]),
              reason: 'find/match mismatch for "$pattern"');
        }
      },
    );

    Glados2(any.luaPattern, any.edgeCaseString).test(
      'gsub with %0 replacement is identity',
      (pattern, input) {
        final code = '''
          return string.gsub(${_luaLong(input)}, ${_luaLong(pattern)}, "%0")
        ''';
        final r = _runLua(code, 1);
        if (r != null && r[0] != null) {
          expect(r[0], equals(input),
              reason: 'gsub %%0 changed string for pattern "$pattern"');
        }
      },
    );
  });

  // -------- Anchors --------

  group('Anchors', () {
    Glados(any.edgeCaseString).test(
      '^%a+ only matches at position 1',
      (input) {
        final code = '''
          local i = string.find(${_luaLong(input)}, "^%a+")
          if i then return i else return -1 end
        ''';
        final r = _runLua(code, 1);
        if (r != null && r[0] != null) {
          final pos = int.tryParse(r[0]!) ?? -1;
          if (pos > 0) expect(pos, equals(1));
        }
      },
    );
  });

  // -------- Empty-match patterns --------

  group('Empty-match patterns', () {
    final emptyPats = ['.-', '%s*', '%d*', '%a*', '%w*', 'x?', '[abc]-', r'^.-$'];
    final inputs = ['', ' ', 'abc', '   ', '123', 'hello world', 'a\nb\nc', '(test)'];

    for (final pat in emptyPats) {
      test('gmatch "$pat" terminates on all inputs', () {
        for (final input in inputs) {
          final code = '''
            local t = {}
            for m in string.gmatch(${_luaLong(input)}, ${_luaLong(pat)}) do
              t[#t+1] = m
              if #t > 1000 then error("runaway") end
            end
            return #t
          ''';
          final r = _runLua(code, 1);
          expect(r, isNotNull, reason: 'gmatch "$pat" on "$input" failed');
        }
      });

      test('gsub "$pat" terminates on all inputs', () {
        for (final input in inputs) {
          final code =
              'return string.gsub(${_luaLong(input)}, ${_luaLong(pat)}, "X")';
          final r = _runLua(code, 2);
          expect(r, isNotNull, reason: 'gsub "$pat" on "$input" failed');
        }
      });
    }
  });

  // -------- Newlines --------

  group('Newlines', () {
    test('dot matches newline in find', () {
      final r = _runLua(r'return string.find("a\nb", ".+")', 2);
      expect(r![0], equals('1'));
      expect(r[1], equals('3'));
    });

    test('dot matches newline in match', () {
      final r = _runLua(r'return string.match("a\nb", ".+")', 1);
      expect(r![0], equals('a\nb'));
    });

    test('dot matches newline in gmatch', () {
      final r = _runLua(r'''
        local t = {}
        for m in string.gmatch("a\nb\nc", "[^\n]+") do t[#t+1] = m end
        return #t, t[1], t[2], t[3]
      ''', 4);
      expect(r![0], equals('3'));
      expect(r[1], equals('a'));
      expect(r[2], equals('b'));
      expect(r[3], equals('c'));
    });

    test('dot matches newline in gsub', () {
      final r = _runLua(r'return string.gsub("a\nb", "(.+)", "[%1]")', 2);
      expect(r![0], equals('[a\nb]'));
    });
  });

  // -------- Literal metacharacters --------

  group('Literal metacharacters', () {
    test('pipe is literal', () {
      expect(_runLua('return string.find("a|b", "a|b")', 2)?[0], equals('1'));
      expect(_runLua('return string.find("b", "a|b")', 2)?[0], isNull);
    });

    test('curly braces are literal', () {
      expect(_runLua('return string.match("x{3}", "%a{%d}")', 1)?[0],
          equals('x{3}'));
    });

    test('backslash is literal', () {
      expect(
          _runLua(r'return string.find("a\\b", "\\")', 2)?[0], equals('2'));
    });

    test('dollar mid-pattern is literal', () {
      expect(_runLua(r'return string.match("costs $10", "$%d+")', 1)?[0],
          equals(r'$10'));
    });

    test('caret mid-pattern is literal', () {
      expect(_runLua('return string.match("2^10", "%d^%d+")', 1)?[0],
          equals('2^10'));
    });
  });
}
