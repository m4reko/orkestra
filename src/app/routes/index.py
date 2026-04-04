from flask import Blueprint

index_bp = Blueprint("index", __name__)


@index_bp.get("/")
def index() -> str:
    return "<h1>Uppsala Blåsarsymfoniker</h1>"
