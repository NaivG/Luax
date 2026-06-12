/// GC tuning constants, matching Lua 5.3 defaults.
class GcConstants {
  /// Default pause: start a new cycle when memory reaches 200% of
  /// the amount that survived the previous cycle.
  static const int defaultPause = 200;

  /// Default step multiplier: GC works at 2× the allocation rate.
  static const int defaultStepMul = 200;

  /// How many VM instructions between GC debt checks.
  static const int instructionInterval = 64;

  /// Minimum estimated bytes for any GC object (prevents zero-size objects
  /// from stalling the debt-based pacing).
  static const int minObjectSize = 32;

  /// Minimum work units per incremental step.
  /// Ensures each step does meaningful work even with tiny allocations.
  static const int minStepWork = 1024;
}
