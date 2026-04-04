from flask.testing import FlaskClient


def test_member_list_returns_200(client: FlaskClient) -> None:
    response = client.get("/members")
    assert response.status_code == 200


def test_member_list_shows_all_members(client: FlaskClient) -> None:
    response = client.get("/members")
    html = response.data.decode()
    assert "Anna" in html
    assert "Björn" in html
    assert "Cecilia" in html
    assert "David" in html


def test_filter_current_members(client: FlaskClient) -> None:
    response = client.get("/members?status=current")
    html = response.data.decode()
    assert "Anna" in html
    assert "David" in html
    assert "Björn" not in html
    assert "Cecilia" not in html


def test_filter_former_members(client: FlaskClient) -> None:
    response = client.get("/members?status=former")
    html = response.data.decode()
    assert "Björn" in html
    assert "Anna" not in html
    assert "Cecilia" not in html


def test_filter_non_members(client: FlaskClient) -> None:
    response = client.get("/members?status=non-member")
    html = response.data.decode()
    assert "Cecilia" in html
    assert "Anna" not in html
    assert "Björn" not in html


def test_filter_by_section(client: FlaskClient) -> None:
    # Get the Flöjt section ID (1 from seed data)
    response = client.get("/members?section=1")
    html = response.data.decode()
    assert "Anna" in html
    assert "Björn" not in html
    assert "David" not in html


def test_search_by_name(client: FlaskClient) -> None:
    response = client.get("/members?search=anders")
    html = response.data.decode()
    assert "Anna" in html
    assert "Björn" not in html


def test_combined_filters(client: FlaskClient) -> None:
    response = client.get("/members?status=current&search=dahl")
    html = response.data.decode()
    assert "David" in html
    assert "Anna" not in html


def test_htmx_request_returns_partial(client: FlaskClient) -> None:
    response = client.get("/members", headers={"HX-Request": "true"})
    html = response.data.decode()
    assert "<html" not in html
    assert "Anna" in html


def test_full_request_returns_complete_page(client: FlaskClient) -> None:
    response = client.get("/members")
    html = response.data.decode()
    assert "<!DOCTYPE html>" in html
    assert "<html" in html
