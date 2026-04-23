import orkestra/lib/response
import wisp/testing

pub fn is_htmx_request_true_when_hx_request_header_is_true_test() {
  let req = testing.get("/", [#("hx-request", "true")])
  assert response.is_htmx_request(req) == True
}

pub fn is_htmx_request_false_when_header_absent_test() {
  let req = testing.get("/", [])
  assert response.is_htmx_request(req) == False
}

pub fn is_htmx_request_false_when_header_value_is_not_true_test() {
  let req = testing.get("/", [#("hx-request", "false")])
  assert response.is_htmx_request(req) == False
}
