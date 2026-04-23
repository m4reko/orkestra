import gleam/http/request
import lustre/element.{type Element}
import wisp.{type Request, type Response}

pub fn html(req: Request, page: Element(a), fragment: Element(a)) -> Response {
  let body = case is_htmx_request(req) {
    True -> element.to_string(fragment)
    False -> element.to_document_string(page)
  }
  wisp.html_response(body, 200)
}

pub fn is_htmx_request(req: request.Request(a)) -> Bool {
  case request.get_header(req, "hx-request") {
    Ok("true") -> True
    _ -> False
  }
}
