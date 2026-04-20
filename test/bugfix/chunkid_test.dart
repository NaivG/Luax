import 'package:lua_dardo_plus/lua.dart';
import 'package:lua_dardo_plus/src/state/lua_stack.dart';
import 'package:test/test.dart';

/// Verifies that runtime error messages don't embed the entire script source
/// as the chunk id, matching reference Lua 5.3's `luaO_chunkid` behavior.
void main() {
  group('chunkid truncation (luaO_chunkid port)', () {
    test('"=name" short form strips the = and keeps the name', () {
      expect(LuaStack.chunkid('=short'), 'short');
    });

    test('"=name" long form hard-truncates to bufflen - 1', () {
      final longName = '=${'x' * 200}';
      final id = LuaStack.chunkid(longName);
      // bufflen defaults to 60 -> output length 59
      expect(id.length, 59);
      expect(id, 'x' * 59);
    });

    test('"@path" short form strips the @', () {
      expect(LuaStack.chunkid('@foo/bar.lua'), 'foo/bar.lua');
    });

    test('"@path" long form uses "..." + tail', () {
      final path = '@${'a' * 100}/last.lua';
      final id = LuaStack.chunkid(path);
      expect(id.startsWith('...'), isTrue);
      expect(id.endsWith('/last.lua'), isTrue);
      // bufflen 60 -> output length 60 (3 for '...' + 57 tail chars)
      expect(id.length, 60);
    });

    test('raw source with newline clamps to first line and adds "..."', () {
      const source = 'local x = 1\nlocal y = 2\nprint(x+y)';
      final id = LuaStack.chunkid(source);
      expect(id, '[string "local x = 1..."]');
    });

    test('raw source long single line clamps to inner budget', () {
      final source = 'print(${'"hello" .. ' * 50}nil)';
      final id = LuaStack.chunkid(source);
      expect(id.startsWith('[string "'), isTrue);
      expect(id.endsWith('..."]'), isTrue);
      // inner budget = bufflen - 16 = 44; plus wrapping '[string ""]' (9)
      // and trailing '...' inserted before the closing quote (3) + '"]' (2)
      // = 14 characters of wrapping.
      expect(id.length, 44 + 14);
    });

    test('raw source short single line is kept verbatim', () {
      const source = 'print(1)';
      expect(LuaStack.chunkid(source), '[string "print(1)"]');
    });

    test('empty source returns "?"', () {
      expect(LuaStack.chunkid(''), '?');
    });
  });

  group('runtime error formatting', () {
    test('loadString: long source does not leak into error prefix', () {
      // Reproduce the original bug: a long script that triggers a runtime
      // error. Before the fix, the error message was prefixed with the
      // entire source. Now it should be `[string "<first line>..."]:<line>`.
      final ls = LuaState.newState();
      ls.openLibs();
      // Sentinel text that appears deep in the script; it must NOT make it
      // into the error prefix after truncation.
      const sentinel = 'SENTINEL_MUST_NOT_APPEAR_IN_ERROR_PREFIX';
      final source = '-- first line that will appear truncated in the id\n'
          '${'-- padding line with $sentinel here\n' * 20}'
          'local t = nil\n'
          'return t.x\n';
      final ok = ls.doString(source);
      expect(ok, isFalse, reason: 'doString should fail on runtime error');
      // `doString` pushes the error message onto the stack on failure.
      final msg = ls.toStr(-1) ?? '';
      expect(msg.contains(sentinel), isFalse,
          reason: 'error message should not embed full source: $msg');
      expect(msg.contains('[string "'), isTrue, reason: msg);
      expect(msg.contains('attempt to index'), isTrue, reason: msg);
      // The chunk id itself is bounded to ~60 chars; the full error message
      // (prefix + message) should stay comfortably under a couple hundred.
      expect(msg.length, lessThan(200),
          reason: 'error message unexpectedly long: $msg');
    });
  });
}
