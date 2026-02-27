//see: https://stackoverflow.com/a/60358200/85472
const int int64MinValue = -9007199254740991;
const int int64MaxValue = 9007199254740991; //for dart web is 2^53-1:

// Removed: rShiftMask was wrong. logicalRShift now computes
// the correct per-shift mask inline.
