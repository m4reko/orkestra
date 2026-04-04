import gleam/dynamic/decode
import gleam/list
import gleam/result
import gleam/string
import simplifile
import sqlight
import wisp

const db_path = "./orkestra.db"

pub fn connect() -> Result(sqlight.Connection, sqlight.Error) {
  sqlight.open(db_path)
}

pub fn configure(db: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  sqlight.exec("PRAGMA journal_mode = WAL;", db)
  |> result.try(fn(_) { sqlight.exec("PRAGMA foreign_keys = ON;", db) })
  |> result.try(fn(_) { sqlight.exec("PRAGMA busy_timeout = 5000;", db) })
  |> result.try(fn(_) { sqlight.exec("PRAGMA synchronous = NORMAL;", db) })
}

pub fn migrate(db: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  use _ <- result.try(sqlight.exec(
    "CREATE TABLE IF NOT EXISTS _migrations (
      name TEXT PRIMARY KEY,
      applied_at INTEGER NOT NULL DEFAULT (unixepoch())
    );",
    db,
  ))

  let assert Ok(priv_dir) = wisp.priv_directory("orkestra")
  let migrations_dir = priv_dir <> "/migrations"

  case simplifile.read_directory(migrations_dir) {
    Error(_) -> Ok(Nil)
    Ok(files) -> {
      let sorted = list.sort(files, string.compare)
      apply_migrations(db, migrations_dir, sorted)
    }
  }
}

fn apply_migrations(
  db: sqlight.Connection,
  dir: String,
  files: List(String),
) -> Result(Nil, sqlight.Error) {
  case files {
    [] -> Ok(Nil)
    [file, ..rest] -> {
      case is_applied(db, file) {
        True -> apply_migrations(db, dir, rest)
        False -> {
          let assert Ok(sql) = simplifile.read(dir <> "/" <> file)
          use _ <- result.try(sqlight.exec(sql, db))
          use _ <- result.try(sqlight.exec(
            "INSERT INTO _migrations (name) VALUES ('" <> file <> "');",
            db,
          ))
          apply_migrations(db, dir, rest)
        }
      }
    }
  }
}

fn is_applied(db: sqlight.Connection, name: String) -> Bool {
  case
    sqlight.query(
      "SELECT 1 FROM _migrations WHERE name = ?",
      db,
      [sqlight.text(name)],
      decode.at([0], decode.int),
    )
  {
    Ok([_]) -> True
    _ -> False
  }
}
