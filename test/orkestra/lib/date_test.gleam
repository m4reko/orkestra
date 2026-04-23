import orkestra/lib/date

pub fn pad_zero_pads_single_digit_zero_test() {
  assert date.pad_zero(0) == "00"
}

pub fn pad_zero_pads_single_digit_seven_test() {
  assert date.pad_zero(7) == "07"
}

pub fn pad_zero_leaves_ten_unchanged_test() {
  assert date.pad_zero(10) == "10"
}

pub fn pad_zero_leaves_two_digit_value_unchanged_test() {
  assert date.pad_zero(42) == "42"
}
