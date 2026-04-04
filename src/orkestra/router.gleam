import gleam/http.{Get, Post}
import orkestra/web.{type Context}
import orkestra/web/members
import wisp.{type Request, type Response}

pub fn handle_request(req: Request, ctx: Context) -> Response {
  use req, ctx <- web.middleware(req, ctx)

  case req.method, wisp.path_segments(req) {
    Get, [] -> wisp.redirect(to: "/members")
    Get, ["members"] -> members.list(req, ctx)
    Post, ["members"] -> members.create(req, ctx)
    _, ["members"] -> wisp.method_not_allowed([Get, Post])
    Get, ["members", "new"] -> members.new(req, ctx)
    _, ["members", "new"] -> wisp.method_not_allowed([Get])
    _, _ -> wisp.not_found()
  }
}
