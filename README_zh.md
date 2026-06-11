# LuaDardo Plus

![LuaDardo Plus Hero](assets/images/hero.png)

纯 Dart 实现的 Lua 5.3 虚拟机 — 持续维护、性能优化、功能完整。

[English](README.md) | [简体中文](README_zh.md)

## 关于本项目

LuaDardo Plus 是 [LuaDardo](https://github.com/arcticfox1919/LuaDardo)（纯 Dart 编写的 Lua 5.3 虚拟机）的维护分支链。

| 阶段 | 维护者 | 主要内容 |
|------|--------|---------|
| [LuaDardo](https://github.com/arcticfox1919/LuaDardo) | arcticfox1919 | 原始 Lua 5.3 VM 实现 |
| [LuaDardo Plus](https://github.com/ImL1s/LuaDardo) | ImL1s | Bug 修复（#13, #24, #33, #34, #36）、Web 支持、异步函数、协程 |
| [Telosnex 分支](https://github.com/Telosnex/LuaDardo) | Telosnex / jpohhhh | goto/label、40+ bug 修复、大幅性能优化、解析器重构、Lua 5.3 模式匹配器 |
| LuaDardo（本仓库） | NaivG | 持续维护与开发 |

## 特性

- **100% Dart** — 无原生依赖，支持所有 Dart 平台（包括 Web）
- **goto/label** — 完整的 Lua 5.2+ 作用域规则，正确处理 upvalue 关闭
- **Lua 5.3 模式匹配** — 从参考 C 实现移植，支持 `%b`（平衡匹配）和 `%f`（前沿模式）
- **二进制数据** — `string.pack`、`string.unpack`、`string.packsize`、`string.dump`
- **异步互操作** — 在 Lua 和 Dart 之间调用异步函数
- **公开的解析器与 AST** — `lua_parser.dart` 用于静态分析工具
- **Web 平台** — 通过平台抽象层完整支持浏览器运行
- **性能提升** — 解析器快 ~47%，VM 栈快 ~22%，sprintf 快 5 倍

## 安装

```yaml
dependencies:
  lua_dardo_plus:
    git: https://github.com/NaivG/LuaDardo.git
```

```bash
dart pub get
```

## 快速开始

```dart
import 'package:lua_dardo_plus/lua.dart';

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

### 异步 Dart 函数

从 Lua 调用异步 Dart 代码 — 适用于 HTTP 请求、文件 I/O、数据库查询等场景。

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

  // 从 Dart 调用
  state.getGlobal('fetchData');
  state.pushString('https://api.example.com');
  await state.callAsync(1, 1);
  print(state.toStr(-1));  // Response from https://api.example.com
}
```

**异步 API 参考：**

| 方法 | 说明 |
|------|------|
| `registerAsync(name, func)` | 注册异步函数为 Lua 全局变量 |
| `pushDartFunctionAsync(func)` | 将异步函数推入栈 |
| `pushDartClosureAsync(func, n)` | 将带 `n` 个 upvalue 的异步闭包推入栈 |
| `callAsync(nArgs, nResults)` | 异步调用函数 |
| `pCallAsync(nArgs, nResults, err)` | 带错误处理的受保护异步调用 |
| `doStringAsync(code)` | 异步执行 Lua 字符串 |
| `doFileAsync(path)` | 异步执行 Lua 文件 |

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
import 'package:lua_dardo_plus/lua_parser.dart';

void main() {
  final parser = Parser('print("hello")', 'example.lua');
  final block = parser.parse();
  // 检查 AST：block.stats、表达式等
}
```

还提供了调试工具用于在运行时检查 Lua 栈：

```dart
import 'package:lua_dardo_plus/debug.dart';

state.printStack();  // 打印栈内容，包含类型和值
```

## 性能

相比上游 LuaDardo Plus v0.3.0 的显著性能提升：

| 组件 | 提升幅度 | 说明 |
|------|---------|------|
| 解析器（端到端） | ~47% | 词法分析器 + 语句解析器调优 |
| 语句解析器 | ~12% | record + 预分配列表 |
| VM 栈 | ~22% | 固定容量数组实现 |
| `sprintf` | 5 倍 | 针对 Lua 格式化的优化分支 |
| `string.format` | 3.7 倍 | 简单格式符绕过 sprintf |
| 操作码分发 | 减少开销 | 消除字符串类型的分发方式 |

## Flutter 集成

关于如何将 LuaDardo Plus 集成到带有 Riverpod 状态管理的 Flutter 应用中，请参阅 [Flutter Lua 示例](https://github.com/ImL1s/flutter_lua_example)。

### 架构

![集成架构图](assets/images/architecture_zh.png)

### 双向通信流程

![通信流程图](assets/images/flow_zh.png)

## Web 平台支持

LuaDardo Plus 通过平台抽象层处理 `dart:io` 依赖，支持在浏览器中运行：

```dart
import 'package:lua_dardo_plus/lua.dart';
import 'package:lua_dardo_plus/src/platform/platform.dart';

void main() {
  // 自定义 print 输出（在 Web 上很有用）
  PlatformServices.instance.printCallback = (s) => print(s);

  final state = LuaState.newState();
  state.openLibs();
  state.doString('print("Hello from Lua on the web!")');
}
```

**Web 限制：** `os.execute()`、`os.exit()`、`os.remove()`、`os.rename()`、`os.getenv()` 会抛出 `UnsupportedError`。时间函数（`os.time`、`os.clock`、`os.date`、`os.difftime`）正常工作。Web 平台不支持文件加载（`doFile`、`loadFile`）。

## 从 lua_dardo 迁移

更新依赖和导入：

```yaml
# pubspec.yaml
dependencies:
  lua_dardo_plus:
    git: https://github.com/NaivG/LuaDardo.git
```

```dart
// 之前
import 'package:lua_dardo/lua.dart';

// 之后
import 'package:lua_dardo_plus/lua.dart';
```

可用的额外导入：

```dart
import 'package:lua_dardo_plus/lua_parser.dart';  // 解析器 & AST
import 'package:lua_dardo_plus/debug.dart';        // 调试工具
```

## 许可证

Apache-2.0（与原始 LuaDardo 相同）

## 致谢

| 贡献者 | 角色 |
|--------|------|
| [arcticfox1919](https://github.com/arcticfox1919) | LuaDardo 原作者 |
| [ImL1s](https://github.com/ImL1s) | LuaDardo Plus 分支 — bug 修复、Web 支持、异步、协程 |
| [Telosnex / jpohhhh](https://github.com/Telosnex) | goto/label、性能优化、解析器重构、40+ bug 修复 |
| [NaivG](https://github.com/NaivG) | 当前维护者 |
