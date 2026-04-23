import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import sqlight

pub fn build(
  status: Option(String),
  section: Option(String),
  search: Option(String),
) -> #(String, List(sqlight.Value)) {
  let clauses: List(String) = []
  let params: List(sqlight.Value) = []

  let #(clauses, params) = case status {
    Some("non-member") -> #(
      list.append(clauses, [" AND ms.status IS NULL"]),
      params,
    )
    Some(s) -> #(
      list.append(clauses, [" AND ms.status = ?"]),
      list.append(params, [sqlight.text(s)]),
    )
    None -> #(clauses, params)
  }

  let #(clauses, params) = case section {
    Some(s) -> #(
      list.append(clauses, [" AND p.section_id = ?"]),
      list.append(params, [sqlight.text(s)]),
    )
    None -> #(clauses, params)
  }

  let #(clauses, params) = case search {
    Some(s) -> #(
      list.append(clauses, [
        " AND (p.first_name || ' ' || p.last_name) LIKE ?",
      ]),
      list.append(params, [sqlight.text("%" <> s <> "%")]),
    )
    None -> #(clauses, params)
  }

  #(string.join(clauses, ""), params)
}
