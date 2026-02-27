const int int64MinValue = -9223372036854775808;
const int int64MaxValue = 9223372036854775807;

// Removed: rShiftMask was 60 bits (wrong). logicalRShift now computes
// the correct per-shift mask inline.
