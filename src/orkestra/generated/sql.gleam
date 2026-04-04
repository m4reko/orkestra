// THIS FILE IS GENERATED. DO NOT EDIT.
// Regenerate with `gleam run -m sqlgen`

import gleam/dynamic/decode
import gleam/result
import orkestra/error.{type Error}
import sqlight

pub type QueryResult(t) =
  Result(List(t), Error)

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
