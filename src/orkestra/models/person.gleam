import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/time/timestamp
import orkestra/error.{type Error}
import orkestra/generated/sql
import sqlight

pub type MemberRow {
  MemberRow(
    id: Int,
    first_name: String,
    last_name: String,
    section_name: Option(String),
    instruments: Option(String),
    membership_status: String,
  )
}

fn member_row_decoder() -> decode.Decoder(MemberRow) {
  use id <- decode.field(0, decode.int)
  use first_name <- decode.field(1, decode.string)
  use last_name <- decode.field(2, decode.string)
  use section_name <- decode.field(3, decode.optional(decode.string))
  use instruments <- decode.field(4, decode.optional(decode.string))
  use membership_status <- decode.field(5, decode.string)
  decode.success(MemberRow(
    id:,
    first_name:,
    last_name:,
    section_name:,
    instruments:,
    membership_status:,
  ))
}

pub fn list_members(
  db: sqlight.Connection,
  status: Option(String),
  section: Option(String),
  search: Option(String),
) -> Result(List(MemberRow), Error) {
  let base =
    "WITH member_status AS (
      SELECT
        person_id,
        CASE
          WHEN MAX(CASE WHEN end_date IS NULL THEN 1 ELSE 0 END) = 1
          THEN 'current'
          ELSE 'former'
        END AS status
      FROM membership_period
      GROUP BY person_id
    )
    SELECT
      p.id,
      p.first_name,
      p.last_name,
      s.name AS section_name,
      GROUP_CONCAT(i.name, ', ') AS instruments,
      COALESCE(ms.status, 'non-member') AS membership_status
    FROM person p
    LEFT JOIN section s ON p.section_id = s.id
    LEFT JOIN person_instrument pi ON p.id = pi.person_id
    LEFT JOIN instrument i ON pi.instrument_id = i.id
    LEFT JOIN member_status ms ON p.id = ms.person_id
    WHERE 1=1"

  let #(where_clauses, params) = build_filters(status, section, search)

  let sql =
    base <> where_clauses <> " GROUP BY p.id ORDER BY p.last_name, p.first_name"

  sqlight.query(sql, db, params, member_row_decoder())
  |> result.map_error(error.DatabaseError)
}

fn build_filters(
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

pub fn create_person(
  db: sqlight.Connection,
  first_name: String,
  last_name: String,
  email: String,
  phone: String,
  street_address: String,
  postal_code: String,
  city: String,
  section_id: Option(Int),
  metadata: String,
  instrument_ids: List(Int),
) -> Result(Int, Error) {
  let #(now, _nanoseconds) =
    timestamp.system_time() |> timestamp.to_unix_seconds_and_nanoseconds

  let section_param = case section_id {
    Some(id) -> sqlight.int(id)
    None -> sqlight.null()
  }

  let id_decoder = decode.at([0], decode.int)

  use _ <- result.try(
    sqlight.exec("BEGIN", db) |> result.map_error(error.DatabaseError),
  )

  let person_result =
    sql.create_person(
      db,
      args: [
        sqlight.text(first_name),
        sqlight.text(last_name),
        sqlight.text(email),
        sqlight.text(phone),
        sqlight.text(street_address),
        sqlight.text(postal_code),
        sqlight.text(city),
        section_param,
        sqlight.text(metadata),
        sqlight.int(now),
        sqlight.int(now),
      ],
      decoder: id_decoder,
    )

  case person_result {
    Ok([person_id]) -> {
      let instruments_result =
        insert_person_instruments(db, person_id, instrument_ids)
      case instruments_result {
        Ok(Nil) -> {
          let assert Ok(Nil) =
            sqlight.exec("COMMIT", db)
            |> result.map_error(error.DatabaseError)
          Ok(person_id)
        }
        Error(e) -> {
          let _ = sqlight.exec("ROLLBACK", db)
          Error(e)
        }
      }
    }
    Ok(_) -> {
      let _ = sqlight.exec("ROLLBACK", db)
      Error(
        error.DatabaseError(sqlight.SqlightError(
          sqlight.Notfound,
          "Expected one row from RETURNING",
          -1,
        )),
      )
    }
    Error(e) -> {
      let _ = sqlight.exec("ROLLBACK", db)
      Error(e)
    }
  }
}

fn insert_person_instruments(
  db: sqlight.Connection,
  person_id: Int,
  instrument_ids: List(Int),
) -> Result(Nil, Error) {
  case instrument_ids {
    [] -> Ok(Nil)
    [id, ..rest] -> {
      let sql =
        "INSERT INTO person_instrument (person_id, instrument_id) VALUES ("
        <> int.to_string(person_id)
        <> ", "
        <> int.to_string(id)
        <> ")"
      case sqlight.exec(sql, db) |> result.map_error(error.DatabaseError) {
        Ok(Nil) -> insert_person_instruments(db, person_id, rest)
        Error(e) -> Error(e)
      }
    }
  }
}
