from flask.testing import FlaskClient


def test_index_redirects_to_members(client: FlaskClient) -> None:
    response = client.get("/")
    assert response.status_code == 302
    assert response.headers["Location"] == "/members"
