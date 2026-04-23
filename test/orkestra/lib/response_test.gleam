import gleam/http/request
import orkestra/lib/response

pub fn is_htmx_request_true_when_hx_request_header_is_true_test() {
  let req = request.new() |> request.set_header("hx-request", "true")
  assert response.is_htmx_request(req) == True
}

pub fn is_htmx_request_false_when_header_absent_test() {
  let req = request.new()
  assert response.is_htmx_request(req) == False
}

pub fn is_htmx_request_false_when_header_value_is_not_true_test() {
  let req = request.new() |> request.set_header("hx-request", "false")
  assert response.is_htmx_request(req) == False
}
