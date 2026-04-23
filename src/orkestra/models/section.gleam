import gleam/dynamic/decode
import orkestra/error.{type Error}
import orkestra/generated/sql
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
  sql.list_sections(db, [], section_decoder())
}
