/// Wraps a raw Lua error value so it can be thrown as a Dart exception
/// without losing the original type (table, number, etc.).
class LuaError {
  final Object? value;
  LuaError(this.value);

  @override
  String toString() => value?.toString() ?? 'nil';
}
