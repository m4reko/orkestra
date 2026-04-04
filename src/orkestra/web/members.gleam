import gleam/list
import gleam/option.{None, Some}
import orkestra/lib/response
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

fn get_param(
  query: List(#(String, String)),
  key: String,
) -> option.Option(String) {
  case list.key_find(query, key) {
    Ok("") -> None
    Ok(value) -> Some(value)
    Error(_) -> None
  }
}

fn option_to_string(opt: option.Option(String)) -> String {
  case opt {
    Some(s) -> s
    None -> ""
  }
}
