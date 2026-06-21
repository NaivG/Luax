# Luax

![Luax Hero](assets/images/hero.png)

纯 Dart 实现的 Lua 5.3 虚拟机 — 持续维护、性能优化、功能完整。

[English](README.md) | 简体中文

## 关于

Luax 是一个纯 Dart 的 Lua 5.3 虚拟机，最初源自
[LuaDardo Plus](https://github.com/ImL1s/LuaDardo)（该版本是
[LuaDardo](https://github.com/arcticfox1919/LuaDardo) 的一个分支），现在
作为一个独立项目进行维护。但你仍然可以将 Luax 作为 LuaDardo 的一个分支
来使用。

完整文档 — 指南、API 参考与架构深入解读 — 请访问
[Luax 文档站](https://luax.naivg.top/)。

## 特性

- **100% Dart** — 无原生依赖，支持所有 Dart 平台（包括 Web）
- **垃圾回收** — 增量式三色标记-清除回收器，带有 `__gc` 终结器、弱表（`__mode`）以及完整的 `collectgarbage()` API
- **异步 / await** — 在 Lua 中通过 `await` 关键字调用 Dart 异步函数，或通过 `coroutine.resumeAsync` 在协程中挂起
- **事件系统** — 双向 EventEmitter，桥接 Dart 与 Lua 回调
- **公开的解析器与 AST** — `lua_parser.dart` 用于静态分析工具
- **Lua 5.3 模式匹配** — 支持 `%b` 与 `%f` 模式，并完整移植参考 C 实现
- **二进制数据** — `string.pack`、`string.unpack`、`string.packsize`、`string.dump`
- **Flutter插件包** — 附带 [`flutter_luax`](https://github.com/NaivG/flutter_luax) 包以支持 Flutter Widget 绑定

完整列表与详细说明请参阅[功能指南](https://luax.naivg.top/guide/)。

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
      print("Hello from Luax!", i)
    end
  ''');
}
```

输出：

```
Hello from Luax!	1
Hello from Luax!	2
Hello from Luax!	3
Hello from Luax!	4
Hello from Luax!	5
```

## 文档

完整文档位于 **[luax.naivg.top](https://luax.naivg.top/)**：

- [快速开始](https://luax.naivg.top/guide/getting-started) — 安装、第一个程序、从 Dart 调用 Lua
- [指南](https://luax.naivg.top/guide/) — Dart↔Lua 互操作、async/await、事件系统、协程、GC、Web、Flutter
- [API 参考](https://luax.naivg.top/api/lua/) — 由 `///` dartdoc 注释自动生成
- [标准库](https://luax.naivg.top/guide/reference/standard-library) — `string`、`math`、`table`、`os`、`coroutine`、`utf8` 等
- [从 `lua_dardo` 迁移](https://luax.naivg.top/guide/migration/from-luadardo) — 替换注意事项

## 许可证

Apache-2.0（与原始 LuaDardo 相同），详见 [LICENSE](LICENSE)。

## 致谢

| 贡献者 | 角色 |
|--------|------|
| [arcticfox1919](https://github.com/arcticfox1919) | LuaDardo 原作者 |
| [ImL1s](https://github.com/ImL1s) | LuaDardo Plus 分支 — bug 修复、Web 支持、异步、协程 |
| [Telosnex / jpohhhh](https://github.com/Telosnex) | goto/label、性能优化、解析器重构、40+ bug 修复 |
| [NaivG](https://github.com/NaivG) | 本仓库维护者 |
