import gleam/erlang/process
import mist
import orkestra/database
import orkestra/router
import orkestra/web.{Context}
import wisp
import wisp/wisp_mist

pub fn main() -> Nil {
  wisp.configure_logger()

  let secret_key_base = wisp.random_string(64)

  let assert Ok(priv_dir) = wisp.priv_directory("orkestra")
  let static_directory = priv_dir <> "/static"

  // Open DB and configure
  let assert Ok(db) = database.connect()
  let assert Ok(Nil) = database.configure(db)
  let assert Ok(Nil) = database.migrate(db)

  let ctx = Context(db:, static_directory:)

  let handler = router.handle_request(_, ctx)

  let assert Ok(_) =
    wisp_mist.handler(handler, secret_key_base)
    |> mist.new
    |> mist.port(8000)
    |> mist.bind("0.0.0.0")
    |> mist.start

  wisp.log_info("Server started on port 8000")
  process.sleep_forever()
}
