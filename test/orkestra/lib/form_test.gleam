import gleam/option.{None, Some}
import orkestra/lib/form

pub fn get_form_value_returns_value_when_present_test() {
  let values = [#("first_name", "Ada"), #("last_name", "Lovelace")]
  assert form.get_form_value(values, "first_name") == "Ada"
}

pub fn get_form_value_returns_empty_string_when_absent_test() {
  let values = [#("first_name", "Ada")]
  assert form.get_form_value(values, "email") == ""
}

pub fn get_param_returns_some_for_non_empty_value_test() {
  let query = [#("search", "ann")]
  assert form.get_param(query, "search") == Some("ann")
}

pub fn get_param_returns_none_for_empty_string_value_test() {
  let query = [#("search", "")]
  assert form.get_param(query, "search") == None
}

pub fn get_param_returns_none_for_missing_key_test() {
  let query = [#("status", "current")]
  assert form.get_param(query, "search") == None
}

pub fn option_to_string_unwraps_some_test() {
  assert form.option_to_string(Some("hello")) == "hello"
}

pub fn option_to_string_returns_empty_string_for_none_test() {
  assert form.option_to_string(None) == ""
}
