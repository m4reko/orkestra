// THIS FILE IS GENERATED. DO NOT EDIT.
// Regenerate with `gleam run -m sqlgen`

import gleam/dynamic/decode
import gleam/result
import orkestra/error.{type Error}
import sqlight

pub type QueryResult(t) =
  Result(List(t), Error)

pub fn list_instruments(
  db: sqlight.Connection,
  args arguments: List(sqlight.Value),
  decoder decoder: decode.Decoder(a),
) -> QueryResult(a) {
  let query =
    "SELECT i.id, i.name, s.name
FROM instrument i
JOIN section s ON i.section_id = s.id
ORDER BY s.name, i.name
"
  sqlight.query(query, db, arguments, decoder)
  |> result.map_error(error.DatabaseError)
}

pub fn list_sections(
  db: sqlight.Connection,
  args arguments: List(sqlight.Value),
  decoder decoder: decode.Decoder(a),
) -> QueryResult(a) {
  let query =
    "SELECT id, name FROM section ORDER BY name
"
  sqlight.query(query, db, arguments, decoder)
  |> result.map_error(error.DatabaseError)
}

pub fn create_person(
  db: sqlight.Connection,
  args arguments: List(sqlight.Value),
  decoder decoder: decode.Decoder(a),
) -> QueryResult(a) {
  let query =
    "INSERT INTO person (first_name, last_name, email, phone, street_address, postal_code, city, section_id, metadata, created_at, updated_at)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
RETURNING id
"
  sqlight.query(query, db, arguments, decoder)
  |> result.map_error(error.DatabaseError)
}
