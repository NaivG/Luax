import 'dart:async';

import 'package:luax/lua.dart';

/// Demonstrates the new `await` semantics for host-registered async
/// functions and the coroutine.resumeAsync bridge.
///
/// Run with: `dart run example/await_example.dart`
void main() async {
  final lua = LuaState.newState();
  lua.openLibs();

  // Register a fake async HTTP-like function under a flat name so the
  // script can call it directly. The name is captured so the runtime can
  // format error message.
  lua.registerAsync('httpGet', (LuaState ls) async {
    final url = ls.toStr(1);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    ls.pushString('{"url": "$url"}');
    return 1;
  });

  // 1. Direct call without `await` returns the (nil, error) tuple so the
  //    script can branch on the error.
  print('--- direct call (no await) ---');
  final ok1 = await lua.doStringAsync('''
    local resp, err = httpGet("https://example.com")
    print("resp =", resp)
    print("err  =", err)
  ''');
  if (!ok1) print('  (script 1 failed)');

  // 2. `await httpGet(...)` suspends the VM and returns the actual result.
  print('\n--- await httpGet ---');
  final ok2 = await lua.doStringAsync('''
    local resp = await httpGet("https://example.com/await")
    print("resp =", resp)
  ''');
  if (!ok2) print('  (script 2 failed)');

  // 3. Inside a coroutine body, direct calls to host async functions are
  //    transparent: `coroutine.resumeAsync` provides the suspension point.
  print('\n--- coroutine body calls async directly ---');
  final ok3 = await lua.doStringAsync('''
    local co = coroutine.create(function()
      local data = httpGet("https://example.com/coroutine")
      print("data =", data)
    end)
    local ok, err = await coroutine.resumeAsync(co)
    if not ok then print("error:", err) end
  ''');
  if (!ok3) print('  (script 3 failed)');
}
