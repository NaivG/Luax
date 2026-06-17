# Luax

![Luax Hero](assets/images/hero.png)

纯 Dart 实现的 Lua 5.3 虚拟机 — 持续维护、性能优化、功能完整。

[English](README.md) | 简体中文

## 关于

Luax是一个纯Dart的Lua 5.3虚拟机，最初源自[LuaDardo Plus](https://github.com/ImL1s/LuaDardo)（该版本是[LuaDardo](https://github.com/arcticfox1919/LuaDardo)的一个分支），现在作为一个独立项目进行维护。但你仍然可以将Luax作为LuaDardo的一个分支来使用。

## 特性

- **100% Dart** — 无原生依赖，支持所有 Dart 平台（包括 Web）
- **垃圾回收** — 增量式三色标记-清除回收器，带有`__gc`终结器、弱表（`__mode`）以及完整的`collectgarbage()` API
- **goto/label** — 完整的 Lua 5.2+ 作用域规则，正确处理 upvalue 关闭
- **Lua 5.3 模式匹配** — 从参考 C 实现移植，支持 `%b`（平衡匹配）和 `%f`（前沿模式）
- **二进制数据** — `string.pack`、`string.unpack`、`string.packsize`、`string.dump`
- **异步互操作** — 在 Lua 和 Dart 之间调用异步函数
- **事件系统** — 双向 EventEmitter，桥接 Dart 与 Lua 回调
- **公开的解析器与 AST** — `lua_parser.dart` 用于静态分析工具
- **Web 平台** — 通过平台抽象层完整支持浏览器运行
- **性能提升** — 解析器快 ~47%，VM 栈快 ~22%，sprintf 快 5 倍

## 安装

```yaml
dependencies:
  luax:
    git: https://github.com/NaivG/Luax.git
```

```bash
dart pub get
```

## 快速开始

```dart
import 'package:luax/lua.dart';

void main() {
  final state = LuaState.newState();
  state.openLibs();
  state.doString(r'''
    for i = 1, 5 do
      print("Hello from Lua!", i)
    end
  ''');
}
```

## 使用方式

API 设计参照 [Lua C API](https://www.lua.org/manual/5.3/manual.html#luaL_newstate)。如果你使用过 C 语言中的 `lua_State`，Dart API 会非常熟悉。

### Dart 调用 Lua

从 Dart 读取 Lua 变量：

```lua
-- config.lua
width = 1920
height = 1080
title = "My App"
```

```dart
final ls = LuaState.newState();
ls.openLibs();
ls.doFile("config.lua");

ls.getGlobal("width");
print("width = ${ls.toInteger(-1)}");  // 1920
ls.pop(1);

ls.getGlobal("title");
print("title = ${ls.toStr(-1)}");  // My App
ls.pop(1);
```

调用带参数和返回值的 Lua 函数：

```lua
-- math_utils.lua
function add(a, b)
    return a + b
end
```

```dart
ls.doFile("math_utils.lua");
ls.getGlobal("add");
ls.pushInteger(3);
ls.pushInteger(4);
ls.pCall(2, 1, 0);
print("3 + 4 = ${ls.toInteger(-1)}");  // 7
```

读取 Lua table：

```lua
-- config.lua
player = { name = "Hero", hp = 100, level = 5 }
```

```dart
ls.getGlobal("player");
ls.getField(-1, "name");
print(ls.toStr(-1));  // Hero
ls.pop(1);
ls.getField(-1, "hp");
print(ls.toInteger(-1));  // 100
ls.pop(2);  // 弹出 hp + table
```

### Lua 调用 Dart

注册 Dart 函数供 Lua 脚本调用：

```dart
import 'dart:math';

int dartRandom(LuaState ls) {
  final max = ls.checkInteger(1);
  ls.pop(1);
  ls.pushInteger(Random().nextInt(max));
  return 1;  // 返回值数量
}

void main() {
  final state = LuaState.newState();
  state.openLibs();

  state.pushDartFunction(dartRandom);
  state.setGlobal('dartRandom');

  state.doString('''
    print("Random:", dartRandom(100))
  ''');
}
```

包装函数的签名为 `int Function(LuaState ls)`，返回值表示推入 Lua 栈的值数量。

### 异步函数调用

Luax 支持 Dart 与 Lua 之间的双向异步函数调用。

#### Dart 异步 API

从 Dart 异步调用函数（包括 Dart 函数和 Lua 函数）。

```dart
Future<int> fetchData(LuaState ls) async {
  final url = ls.checkString(1);

  // 模拟异步操作
  await Future.delayed(Duration(seconds: 1));

  ls.pushString('Response from $url');
  return 1;
}

void main() async {
  final state = LuaState.newState();
  state.openLibs();

  // 注册异步函数为全局变量
  state.registerAsync('fetchData', fetchData);

  // 使用 callAsync 从 Dart 调用
  state.getGlobal('fetchData');
  state.pushString('https://api.example.com');
  await state.callAsync(1, 1);
  print(state.toStr(-1));  // Response from https://api.example.com
}
```

#### Lua 调用异步函数

> [!important]
> `await` 关键字是 Luax **0.3.1 之后**版本中的自定义关键字，并非 Lua 语言的标准组成部分。
> 
> 如果您使用的是较旧版本的 Luax，只需使用与同步函数相同的语法即可。

当 Lua 代码调用异步注册的 Dart 函数时，必须使用 `await` 关键字或在协程内运行（通过 `coroutine.create` 和 `coroutine.resumeAsync`）。适用于 HTTP 请求、文件 I/O、数据库查询等由 Dart 驱动的异步操作场景。

```lua
-- `await` 是 Luax 中的保留关键字
local result = await fetchData("https://api.example.com")
print(result)

-- 嵌套 await
local a = await fetchData("url1")
local b = await fetchData("url2")

-- 协程
local co = coroutine.create(function()
  local a = fetchData("url1")
end)
coroutine.resumeAsync(co)
```

> **注意：** `await` 只能出现在函数调用表达式之前。将其用作变量名或其他标识符位置会导致语法错误。

如果在 Lua 中调用异步函数时未使用 `await` 或不在协程上下文中，调用将出错并返回 `(nil, error_string)` 元组：

```lua
local r, err = asyncFunc()
-- r   = nil
-- err = "attempt to call async function `asyncFunc` without await or in non-async context"
```

#### 异步 API 参考

| 方法 | 说明 |
|------|------|
| `registerAsync(name, func)` | 注册异步函数为 Lua 全局变量 |
| `pushDartFunctionAsync(func)` | 将异步函数推入栈 |
| `pushDartClosureAsync(func, n)` | 将带 `n` 个 upvalue 的异步闭包推入栈 |
| `callAsync(nArgs, nResults)` | 异步调用函数 |
| `pCallAsync(nArgs, nResults, err)` | 带错误处理的受保护异步调用 |
| `doStringAsync(code)` | 异步执行 Lua 字符串 |
| `doFileAsync(path)` | 异步执行 Lua 文件 |

### 事件系统

Luax 内置了一个双向 EventEmitter，允许 Dart 和 Lua 代码订阅和触发共享事件。

#### Dart 端

```dart
final state = LuaState.newState();
state.openLibs();

// 从 Dart 订阅事件
state.on('greet', (args) {
  print('来自 Dart 的问候！${args.first}');
});

// 从 Dart 触发 — 同时触发 Dart 和 Lua 的监听器
state.emit('greet', ['world']);

// 一次性监听器
state.once('login', (args) => print('用户已登录'));

// 异步监听器
state.onAsync('fetch', (args) async {
  await Future.delayed(Duration(seconds: 1));
  print('已获取 ${args.first}');
});
await state.emitAsync('fetch', ['data']);

// 按 id 取消订阅
final id = state.on('tick', (args) => print('tick'));
state.off('tick', listenerId: id);
```

#### Lua 端

```lua
-- 从 Lua 订阅事件
local id = event.on("greet", function(name)
  print("来自 Lua 的问候！", name)
end)

-- 从 Lua 触发 — 同时触发 Dart 和 Lua 的监听器
event.emit("greet", "world")

-- 一次性监听器
event.once("login", function()
  print("用户已登录")
end)

-- 取消订阅
event.off("greet", id)
```

#### Dart 事件 API 参考

| 方法 | 说明 |
|------|------|
| `on(event, callback)` | 注册 Dart 监听器，返回监听器 id |
| `onAsync(event, callback)` | 注册异步 Dart 监听器 |
| `once(event, callback)` | 注册一次性监听器，首次触发后自动移除 |
| `off(event, {callback, listenerId})` | 按回调引用或 id 移除监听器 |
| `emit(event, [args])` | 同步触发所有监听器 |
| `emitAsync(event, [args])` | 异步触发所有监听器 |
| `removeAllListeners([event])` | 移除指定事件或所有事件的全部监听器 |

#### Lua 事件 API 参考

| 函数 | 说明 |
|------|------|
| `event.on(name, fn)` | 注册 Lua 监听器，返回监听器 id |
| `event.once(name, fn)` | 注册一次性 Lua 监听器 |
| `event.off(name, fn_or_id)` | 按函数引用或 id 移除监听器 |
| `event.emit(name, ...)` | 同步触发所有监听器 |
| `event.emitAsync(name, ...)` | 异步触发所有监听器 |

#### 安全性

在事件系统的设计之初，就已将安全沙箱机制纳入考量。Lua 端不允许执行任何可能对宿主系统构成风险的操作。

通过 `off` 函数移除监听器时，Lua 端只能移除由其自身注册的监听器。而 `removeAllListeners` 仅在 Dart 端可用。这是为了防止 Lua 端意外移除监听器，从而导致 Dart 端崩溃。

`emit` 和 `emitAsync` 函数可调用所有已注册的监听器。综合考虑下这种设计是可接受的。

## 语言特性

### goto / label

完整支持 Lua 5.2+ 的 `goto` 和 `::label::` 语法，包括正确的 upvalue 关闭和同名标签遮蔽：

```lua
for i = 1, 10 do
  for j = 1, 10 do
    if i * j > 50 then
      goto done
    end
    print(i, j)
  end
end
::done::
print("Finished!")
```

### 协程

完整的 Lua 协程库：

```lua
local co = coroutine.create(function(a, b)
  local sum = a + b
  local extra = coroutine.yield(sum)
  return sum + extra
end)

local ok, result = coroutine.resume(co, 10, 20)
print(result)            -- 30（yield 的值）
local ok2, result2 = coroutine.resume(co, 5)
print(result2)           -- 35（最终结果）
```

### Lua 5.3 模式匹配

模式匹配器从参考 Lua 5.3 C 实现移植，支持 `%b`（平衡匹配）和 `%f`（前沿模式）：

```lua
-- 平衡括号匹配
print(string.match("(hello (world))", "%b()"))  -- (hello (world))

-- 前沿模式（词边界）
for w in string.gmatch("hello world", "%f[%a]%a+") do
  print(w)  -- "hello", "world"
end
```

### 二进制数据打包

`string.pack`、`string.unpack` 和 `string.packsize` 用于二进制数据操作：

```lua
local packed = string.pack(">i4i4", 100, 200)
local a, b = string.unpack(">i4i4", packed)
print(a, b)  -- 100  200
```

### 函数序列化

`string.dump` 将编译后的 Lua 函数序列化为二进制 chunk 格式：

```lua
local f = load("return 1 + 2")
local bytes = string.dump(f)
local f2 = load(bytes)
print(f2())  -- 3
```

## 解析器与静态分析

解析器和 AST 作为独立库公开，用于构建静态分析工具：

```dart
import 'package:luax/lua_parser.dart';

void main() {
  final parser = Parser('print("hello")', 'example.lua');
  final block = parser.parse();
  // 检查 AST：block.stats、表达式等
}
```

还提供了调试工具用于在运行时检查 Lua 栈：

```dart
import 'package:luax/debug.dart';

state.printStack();  // 打印栈内容，包含类型和值
```

## 垃圾回收

Luax 内置了一个与 Lua 5.3 语义兼容的增量三色标记-清除垃圾收集器。该收集器与 Dart 自身的垃圾收集器协同工作——Dart 负责回收底层内存，而 Luax 收集器则负责追踪 Lua 层面的可达性、运行 `__gc` 终结器，并提供内存统计功能。

```lua
-- 为表添加一个终结器
local t = setmetatable({}, {__gc = function()
  print("finalized!")
end})
t = nil
collectgarbage("collect")  -- → 毙掉了!

-- 弱引用
local cache = setmetatable({}, {__mode = "v"})
cache[1] = {data = "ephemeral"}
cache[1] = nil
collectgarbage("collect")
-- 即使表本身仍然活跃，缓存值现在也已可以被回收
```

**`collectgarbage` 选项:** `"collect"`, `"stop"`, `"restart"`, `"count"` (返回 KB), `"step"`, `"setpause"`, `"setstepmul"`, `"isrunning"`, `"info"` (返回包含阶段、垃圾量和总量的结构化表格).

## 性能

相比上游 LuaDardo Plus v0.3.0 的显著性能提升：

| 组件 | 提升幅度 | 说明 |
|------|---------|------|
| 解析器（端到端） | ~47% | 词法分析器 + 语句解析器调优 |
| 语句解析器 | ~12% | record + 预分配列表 |
| VM 栈 | ~22% | 固定容量数组实现 |
| GC 三色 | 基于整数 | 减少每个对象的内存开销 |
| GC 热路径 | 缓存 `__gc` / `__mode` | 消除重复的哈希查找 |
| `sprintf` | 5 倍 | 针对 Lua 格式化的优化分支 |
| `string.format` | 3.7 倍 | 简单格式符绕过 sprintf |
| 操作码分发 | 减少开销 | 消除字符串类型的分发方式 |

## Flutter 集成

Luax 提供了一个 Flutter Widget 绑定包 [`flutter_luax`](https://github.com/NaivG/flutter_luax)，允许 Lua 脚本直接构造 `Scaffold`、`AppBar`、`Container`、`ElevatedButton`、`ListView`等组件。

该包同时内置了 `LuaxScriptLoader`，可以从 URL 或 Flutter 资源包中
加载 `.lua` 脚本，适合需要在不发版的情况下热更新 UI 的场景。

```yaml
dependencies:
  luax:
    git: https://github.com/NaivG/Luax.git
  flutter_luax:
    git: https://github.com/NaivG/flutter_luax.git
```

完整的 Widget 列表和使用示例请参阅 [flutter_luax README](https://github.com/NaivG/flutter_luax/README.md)。

一个使用 Riverpod 状态管理的完整集成示例也可以在
[flutter_lua_example](https://github.com/ImL1s/flutter_lua_example) 查看。

### 架构

![集成架构图](assets/images/architecture_zh.png)

### 双向通信流程

![通信流程图](assets/images/flow_zh.png)

## Web 平台支持

Luax 通过平台抽象层处理 `dart:io` 依赖，支持在浏览器中运行：

```dart
import 'package:luax/lua.dart';
import 'package:luax/src/platform/platform.dart';

void main() {
  // 自定义 print 输出（在 Web 上很有用）
  PlatformServices.instance.printCallback = (s) => print(s);

  final state = LuaState.newState();
  state.openLibs();
  state.doString('print("Hello from Lua on the web!")');
}
```

**Web 限制：** `os.execute()`、`os.exit()`、`os.remove()`、`os.rename()`、`os.getenv()` 会抛出 `UnsupportedError`。时间函数（`os.time`、`os.clock`、`os.date`、`os.difftime`）正常工作。Web 平台不支持文件加载（`doFile`、`loadFile`）。

## 从 lua_dardo/lua_dardo_plus 迁移

更新依赖和导入：

```yaml
# pubspec.yaml
dependencies:
  luax:
    git: https://github.com/NaivG/Luax.git
```

```dart
// 之前
import 'package:lua_dardo/lua.dart';

// 之后
import 'package:luax/lua.dart';
```

可用的额外导入：

```dart
import 'package:luax/lua_parser.dart';  // 解析器 & AST
import 'package:luax/debug.dart';        // 调试工具
```

## 许可证

Apache-2.0（与原始 LuaDardo 相同），详见 [LICENSE](LICENSE)。

## 致谢

| 贡献者 | 角色 |
|--------|------|
| [arcticfox1919](https://github.com/arcticfox1919) | LuaDardo 原作者 |
| [ImL1s](https://github.com/ImL1s) | LuaDardo Plus 分支 — bug 修复、Web 支持、异步、协程 |
| [Telosnex / jpohhhh](https://github.com/Telosnex) | goto/label、性能优化、解析器重构、40+ bug 修复 |
| [NaivG](https://github.com/NaivG) | 本仓库维护者 |
