import gleam/int
import gleam/list
import gleam/option.{None, Some}
import lustre/element
import orkestra/lib/date
import orkestra/lib/form
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

  let status = form.get_param(query, "status")
  let section_filter = form.get_param(query, "section")
  let search = form.get_param(query, "search")

  let assert Ok(members) =
    person.list_members(ctx.db, status, section_filter, search)
  let assert Ok(sections) = section.list_all(ctx.db)

  let status_str = form.option_to_string(status)
  let section_str = form.option_to_string(section_filter)
  let search_str = form.option_to_string(search)

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
  let today = date.today_string()

  let page =
    member_pages.add_page(sections, instruments, today)
    |> layout.wrap("Lägg till person — UBS", _)

  wisp.html_response(element.to_document_string(page), 200)
}

pub fn create(req: Request, ctx: Context) -> Response {
  use form_data <- wisp.require_form(req)

  let get = fn(key) { form.get_form_value(form_data.values, key) }
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
    list.filter_map(form_data.values, fn(pair) {
      case pair {
        #("instrument", v) -> int.parse(v)
        _ -> Error(Nil)
      }
    })

  let membership_start = case get("active_member") {
    "true" ->
      case get("membership_start") {
        "" -> None
        start_date -> Some(start_date)
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
