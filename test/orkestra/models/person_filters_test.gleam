import gleam/option.{None, Some}
import orkestra/models/person_filters
import sqlight

pub fn no_filters_returns_empty_clauses_and_params_test() {
  let #(clauses, params) = person_filters.build(None, None, None)
  assert clauses == ""
  assert params == []
}

pub fn status_non_member_produces_null_check_without_param_test() {
  let #(clauses, params) = person_filters.build(Some("non-member"), None, None)
  assert clauses == " AND ms.status IS NULL"
  assert params == []
}

pub fn status_other_produces_equality_clause_with_param_test() {
  let #(clauses, params) = person_filters.build(Some("current"), None, None)
  assert clauses == " AND ms.status = ?"
  assert params == [sqlight.text("current")]
}

pub fn section_filter_produces_equality_clause_with_param_test() {
  let #(clauses, params) = person_filters.build(None, Some("3"), None)
  assert clauses == " AND p.section_id = ?"
  assert params == [sqlight.text("3")]
}

pub fn search_filter_wraps_value_in_percent_signs_test() {
  let #(clauses, params) = person_filters.build(None, None, Some("ann"))
  assert clauses == " AND (p.first_name || ' ' || p.last_name) LIKE ?"
  assert params == [sqlight.text("%ann%")]
}

pub fn combined_filters_preserve_clause_and_param_order_test() {
  let #(clauses, params) =
    person_filters.build(Some("current"), Some("3"), Some("ann"))
  assert clauses
    == " AND ms.status = ?"
    <> " AND p.section_id = ?"
    <> " AND (p.first_name || ' ' || p.last_name) LIKE ?"
  assert params
    == [
      sqlight.text("current"),
      sqlight.text("3"),
      sqlight.text("%ann%"),
    ]
}
