import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/time/calendar
import gleam/time/duration
import gleam/time/timestamp
import lustre/element
import orkestra/lib/response
import orkestra/models/instrument
import orkestra/models/person
import orkestra/models/section
import orkestra/pages/layout
import orkestra/pages/members as member_pages
import orkestra/web.{type Context}
import wisp.{type Request, type Response}

pub fn list(req: Request, ctx: Context) -> Response {
  let query = wisp.get_query(req)

  let status = get_param(query, "status")
  let section_filter = get_param(query, "section")
  let search = get_param(query, "search")

  let assert Ok(members) =
    person.list_members(ctx.db, status, section_filter, search)
  let assert Ok(sections) = section.list_all(ctx.db)

  let status_str = option_to_string(status)
  let section_str = option_to_string(section_filter)
  let search_str = option_to_string(search)

  let fragment = member_pages.member_table(members)
  let page =
    member_pages.list_page(
      members,
      sections,
      status_str,
      section_str,
      search_str,
    )
    |> layout.wrap("Medlemmar — UBS", _)

  response.html(req, page, fragment)
}

pub fn new(_req: Request, ctx: Context) -> Response {
  let assert Ok(sections) = section.list_all(ctx.db)
  let assert Ok(instruments) = instrument.list_all(ctx.db)
  let today = today_string()

  let page =
    member_pages.add_page(sections, instruments, today)
    |> layout.wrap("Lägg till person — UBS", _)

  wisp.html_response(element.to_document_string(page), 200)
}

pub fn create(req: Request, ctx: Context) -> Response {
  use form <- wisp.require_form(req)

  let get = fn(key) { get_form_value(form.values, key) }
  let first_name = get("first_name")
  let last_name = get("last_name")
  let email = get("email")
  let phone = get("phone")
  let street_address = get("street_address")
  let postal_code = get("postal_code")
  let city = get("city")
  let metadata = get("metadata")

  let section_id = case get("section_id") {
    "" -> None
    s ->
      case int.parse(s) {
        Ok(id) -> Some(id)
        Error(_) -> None
      }
  }

  let instrument_ids =
    list.filter_map(form.values, fn(pair) {
      case pair {
        #("instrument", v) -> int.parse(v)
        _ -> Error(Nil)
      }
    })

  let membership_start = case get("active_member") {
    "true" ->
      case get("membership_start") {
        "" -> None
        date -> Some(date)
      }
    _ -> None
  }

  let assert Ok(_id) =
    person.create_person(
      ctx.db,
      first_name,
      last_name,
      email,
      phone,
      street_address,
      postal_code,
      city,
      section_id,
      metadata,
      instrument_ids,
      membership_start,
    )

  wisp.redirect(to: "/members")
}

fn get_form_value(values: List(#(String, String)), key: String) -> String {
  case list.key_find(values, key) {
    Ok(v) -> v
    Error(_) -> ""
  }
}

fn get_param(query: List(#(String, String)), key: String) -> Option(String) {
  case list.key_find(query, key) {
    Ok("") -> None
    Ok(value) -> Some(value)
    Error(_) -> None
  }
}

fn option_to_string(opt: Option(String)) -> String {
  case opt {
    Some(s) -> s
    None -> ""
  }
}

fn today_string() -> String {
  let #(date, _time) =
    timestamp.system_time()
    |> timestamp.to_calendar(duration.seconds(0))
  let year = int.to_string(date.year)
  let month = pad_zero(calendar.month_to_int(date.month))
  let day = pad_zero(date.day)
  year <> "-" <> month <> "-" <> day
}

fn pad_zero(n: Int) -> String {
  case n < 10 {
    True -> "0" <> int.to_string(n)
    False -> int.to_string(n)
  }
}
