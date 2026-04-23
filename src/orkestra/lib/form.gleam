import gleam/list
import gleam/option.{type Option, None, Some}

pub fn get_form_value(values: List(#(String, String)), key: String) -> String {
  case list.key_find(values, key) {
    Ok(v) -> v
    Error(_) -> ""
  }
}

pub fn get_param(query: List(#(String, String)), key: String) -> Option(String) {
  case list.key_find(query, key) {
    Ok("") -> None
    Ok(value) -> Some(value)
    Error(_) -> None
  }
}

pub fn option_to_string(opt: Option(String)) -> String {
  case opt {
    Some(s) -> s
    None -> ""
  }
}
