import gleam/int
import gleam/time/calendar
import gleam/time/duration
import gleam/time/timestamp

pub fn today_string() -> String {
  let #(date, _time) =
    timestamp.system_time()
    |> timestamp.to_calendar(duration.seconds(0))
  let year = int.to_string(date.year)
  let month = pad_zero(calendar.month_to_int(date.month))
  let day = pad_zero(date.day)
  year <> "-" <> month <> "-" <> day
}

pub fn pad_zero(n: Int) -> String {
  case n < 10 {
    True -> "0" <> int.to_string(n)
    False -> int.to_string(n)
  }
}
