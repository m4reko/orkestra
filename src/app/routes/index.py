from flask import Blueprint, redirect
from werkzeug.wrappers import Response

index_bp = Blueprint("index", __name__)


@index_bp.get("/")
def index() -> Response:
    return redirect("/members")
