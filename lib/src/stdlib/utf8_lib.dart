import '../api/lua_state.dart';
import '../api/lua_type.dart';

/// Standard Lua 5.3 UTF-8 library.
///
/// Works at the Unicode code-point level, consistent with this VM's Dart-string
/// representation (where string positions are code-unit indices).
///
/// Functions:
///   utf8.char(...)         – encode code points to a Dart string
///   utf8.codepoint(s,i,j)  – decode code points from string
///   utf8.codes(s)          – iterator over (position, codepoint)
///   utf8.len(s,i,j)        – count Unicode characters
///   utf8.offset(s,n,i)     – code-unit offset of n-th character
///   utf8.charpattern       – Lua pattern (informational)
class Utf8Lib {
  static const int _maxUnicode = 0x10FFFF;

  // Surrogate pair range constants
  static const int _surrogateHighStart = 0xD800;
  static const int _surrogateHighEnd = 0xDBFF;
  static const int _surrogateLowStart = 0xDC00;
  static const int _surrogateLowEnd = 0xDFFF;

  static const Map<String, DartFunction?> _utf8Lib = {
    "char": _utfChar,
    "codepoint": _utfCodepoint,
    "codes": _utfCodes,
    "len": _utfLen,
    "offset": _utfOffset,
    "charpattern": null, // set in openUtf8Lib
  };

  static int openUtf8Lib(LuaState ls) {
    ls.newLib(_utf8Lib);
    // charpattern: Lua pattern matching one UTF-8 byte sequence.
    // Build via char codes to avoid Dart escape lint issues.
    ls.pushString(String.fromCharCodes([
      0x5B, // '['
      0x00, // \0
      0x2D, // '-'
      0x7F, // \x7F
      0xC2, // \xC2
      0x2D, // '-'
      0xFD, // \xFD
      0x5D, // ']'
      0x5B, // '['
      0x80, // \x80
      0x2D, // '-'
      0xBF, // \xBF
      0x5D, // ']'
      0x2A, // '*'
    ]));
    ls.setField(-2, "charpattern");
    return 1;
  }

  // ---------------------------------------------------------------------------
  // Helpers: iterate over (code unit index, code point) in a Dart string
  // ---------------------------------------------------------------------------

  /// Encodes a single Unicode code point into a Dart string.
  /// For BMP characters (<= 0xFFFF), returns a single code unit.
  /// For supplementary characters (> 0xFFFF), returns a surrogate pair.
  static String _encodeCodepoint(int code) {
    if (code <= 0xFFFF) {
      return String.fromCharCode(code);
    } else {
      // Supplementary plane: encode as surrogate pair
      int adjusted = code - 0x10000;
      int high = _surrogateHighStart | (adjusted >> 10);
      int low = _surrogateLowStart | (adjusted & 0x3FF);
      return String.fromCharCodes([high, low]);
    }
  }

  /// Returns the Unicode code point at 0-based code-unit index [i] in [s],
  /// and the number of code units it occupies (1 or 2).
  /// Returns null if [i] is out of bounds.
  static (int, int)? _codePointAt(String s, int i) {
    if (i >= s.length) return null;
    int cu = s.codeUnitAt(i);
    if (cu >= _surrogateHighStart && cu <= _surrogateHighEnd) {
      // High surrogate — read the following low surrogate
      if (i + 1 >= s.length) return null; // truncated surrogate
      int cu2 = s.codeUnitAt(i + 1);
      if (cu2 < _surrogateLowStart || cu2 > _surrogateLowEnd) return null;
      int cp = ((cu - _surrogateHighStart) << 10) +
          (cu2 - _surrogateLowStart) +
          0x10000;
      return (cp, 2);
    }
    if (cu >= _surrogateLowStart && cu <= _surrogateLowEnd) {
      // Lone low surrogate — invalid
      return null;
    }
    // BMP character (including 0x00-0xFF raw bytes stored as Latin-1)
    return (cu, 1);
  }

  /// Returns true if the code unit at [i] in [s] is a trail surrogate
  /// (i.e., a continuation of a surrogate pair starting at [i-1]).
  static bool _isTrailSurrogate(String s, int i) {
    if (i < 0 || i >= s.length) return false;
    int cu = s.codeUnitAt(i);
    return cu >= _surrogateLowStart && cu <= _surrogateLowEnd;
  }

  /// Translates a relative position (1-based, negative means back from end).
  static int _posRelat(int pos, int len) {
    if (pos >= 0) return pos;
    if (-pos > len) return 0;
    return len + pos + 1;
  }

  // ---------------------------------------------------------------------------
  // utf8.char(···)
  // ---------------------------------------------------------------------------

  /// Receives zero or more integers (Unicode code points), converts each to
  /// its Dart string representation, and concatenates the results.
  ///
  /// Note: In standard Lua this produces a UTF-8 byte string. In this VM,
  /// strings are stored as Dart strings (decoded Unicode), so we produce
  /// a Dart string directly.
  static int _utfChar(LuaState ls) {
    int n = ls.getTop();
    if (n == 0) {
      ls.pushString("");
    } else {
      final buf = StringBuffer();
      for (int i = 1; i <= n; i++) {
        int code = ls.checkInteger(i)!;
        ls.argCheck(code >= 0 && code <= _maxUnicode, i, "value out of range");
        buf.write(_encodeCodepoint(code));
      }
      ls.pushString(buf.toString());
    }
    return 1;
  }

  // ---------------------------------------------------------------------------
  // utf8.codepoint(s [, i [, j]])
  // ---------------------------------------------------------------------------

  /// Returns the code points (as integers) of all Unicode characters in [s]
  /// that start between code-unit positions [i] and [j] (both inclusive).
  /// Default [i] is 1; default [j] is [i].
  static int _utfCodepoint(LuaState ls) {
    String s = ls.checkString(1)!;
    int len = s.length;
    int posi = _posRelat(ls.optInteger(2, 1)!, len);
    int pose = _posRelat(ls.optInteger(3, posi)!, len);

    ls.argCheck(posi >= 1, 2, "out of range");
    ls.argCheck(pose <= len, 3, "out of range");

    if (posi > pose) return 0;

    int n = pose - posi + 1;
    ls.checkStack2(n, "string slice too long");

    int idx = posi - 1;
    int end = pose - 1;
    int count = 0;

    while (idx <= end) {
      final decoded = _codePointAt(s, idx);
      if (decoded == null) {
        return ls.error2("invalid UTF-8 code");
      }
      ls.pushInteger(decoded.$1);
      count++;
      idx += decoded.$2;
    }
    return count;
  }

  // ---------------------------------------------------------------------------
  // utf8.codes(s)
  // ---------------------------------------------------------------------------

  /// Returns an iterator so that the construction
  ///   `for position, codepoint in utf8.codes(s) do ... end`
  /// iterates over all Unicode characters in string [s].
  static int _utfCodes(LuaState ls) {
    ls.checkString(1);
    ls.pushDartFunction(_utfIterAux);
    ls.pushValue(1);
    ls.pushInteger(0);
    return 3;
  }

  /// Iterator auxiliary: receives (string, previous_position) on the stack.
  /// Returns (next_position, codepoint) or 0 when done.
  static int _utfIterAux(LuaState ls) {
    String s = ls.checkString(1)!;
    int len = s.length;
    int n = ls.checkInteger(2)! - 1; // 0-based code-unit position

    if (n < 0) {
      n = 0;
    } else if (n < len) {
      n++;
      // Skip trail surrogate if we landed on one (move to next char start)
      while (n < len && _isTrailSurrogate(s, n)) {
        n++;
      }
    }

    if (n >= len) return 0;

    final decoded = _codePointAt(s, n);
    if (decoded == null || n + decoded.$2 > len) {
      return ls.error2("invalid UTF-8 code");
    }
    ls.pushInteger(n + 1); // 1-based position
    ls.pushInteger(decoded.$1); // code point
    return 2;
  }

  // ---------------------------------------------------------------------------
  // utf8.len(s [, i [, j]])
  // ---------------------------------------------------------------------------

  /// Returns the number of Unicode characters in string [s] that start within
  /// the code-unit range [[i], [j]]. Default [i] is 1; default [j] is -1 (#s).
  /// If an invalid surrogate is encountered, returns nil plus its position.
  static int _utfLen(LuaState ls) {
    String s = ls.checkString(1)!;
    int len = s.length;
    int posi = _posRelat(ls.optInteger(2, 1)!, len);
    int posj = _posRelat(ls.optInteger(3, -1)!, len);

    ls.argCheck(
        1 <= posi && posi - 1 <= len, 2, "initial position out of string");
    ls.argCheck(posj - 1 < len, 3, "final position out of string");

    int idx = posi - 1;
    int end = posj - 1;
    int charCount = 0;

    while (idx <= end) {
      final decoded = _codePointAt(s, idx);
      if (decoded == null) {
        ls.pushNil();
        ls.pushInteger(idx + 1);
        return 2;
      }
      idx += decoded.$2;
      charCount++;
    }

    ls.pushInteger(charCount);
    return 1;
  }

  // ---------------------------------------------------------------------------
  // utf8.offset(s, n [, i])
  // ---------------------------------------------------------------------------

  /// Returns the code-unit position where the [n]-th Unicode character of [s]
  /// (counting from position [i]) starts. A negative [n] counts backward.
  /// The default for [i] is 1 if [n] is positive, and `#s + 1` if [n] is
  /// negative. When [n] is 0, finds the start of the character containing [i].
  static int _utfOffset(LuaState ls) {
    String s = ls.checkString(1)!;
    int len = s.length;
    int n = ls.checkInteger(2)!;

    int defaultPosi = (n >= 0) ? 1 : len + 1;
    int posi = _posRelat(ls.optInteger(3, defaultPosi)!, len);

    ls.argCheck(1 <= posi && posi - 1 <= len, 3, "position out of range");

    int idx = posi - 1;

    if (n == 0) {
      // Find start of current character: if at a trail surrogate, go back
      if (idx > 0 && idx <= len && _isTrailSurrogate(s, idx)) {
        idx--;
      }
    } else if (n < 0) {
      while (n < 0 && idx > 0) {
        // Move to the beginning of the previous character
        idx--;
        while (idx > 0 && _isTrailSurrogate(s, idx)) {
          idx--;
        }
        n++;
      }
    } else {
      n--; // 1st character is already at idx
      while (n > 0 && idx < len) {
        // Advance by the width of the current character
        final cp = _codePointAt(s, idx);
        if (cp == null) break;
        idx += cp.$2;
        n--;
      }
    }

    if (n == 0) {
      ls.pushInteger(idx + 1);
    } else {
      ls.pushNil();
    }
    return 1;
  }
}
