pub fn u1ToBoolStr(val: u1) []const u8 {
    return if (val == 1) "true" else "false";
}
