import gleam/dynamic/decode
import orkestra/error.{type Error}
import orkestra/generated/sql
import sqlight

pub type Instrument {
  Instrument(id: Int, name: String, section_name: String)
}

fn instrument_decoder() -> decode.Decoder(Instrument) {
  use id <- decode.field(0, decode.int)
  use name <- decode.field(1, decode.string)
  use section_name <- decode.field(2, decode.string)
  decode.success(Instrument(id:, name:, section_name:))
}

pub fn list_all(db: sqlight.Connection) -> Result(List(Instrument), Error) {
  sql.list_instruments(db, args: [], decoder: instrument_decoder())
}
