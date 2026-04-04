import gleam/dynamic/decode
import gleam/result
import orchestra/error.{type Error}
import sqlight

pub type Section {
  Section(id: Int, name: String)
}

fn section_decoder() -> decode.Decoder(Section) {
  use id <- decode.field(0, decode.int)
  use name <- decode.field(1, decode.string)
  decode.success(Section(id:, name:))
}

pub fn list_all(db: sqlight.Connection) -> Result(List(Section), Error) {
  sqlight.query(
    "SELECT id, name FROM section ORDER BY name",
    db,
    [],
    section_decoder(),
  )
  |> result.map_error(error.DatabaseError)
}
