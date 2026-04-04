from flask import Flask

from app.routes import index_bp


def create_app() -> Flask:
    app = Flask(__name__)
    app.register_blueprint(index_bp)
    return app
