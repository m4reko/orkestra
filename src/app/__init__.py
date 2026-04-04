from pathlib import Path

from flask import Flask

from app.db import init_app
from app.routes import index_bp, members_bp


def create_app(config: dict[str, object] | None = None) -> Flask:
    app = Flask(__name__)

    if config:
        app.config.from_mapping(config)

    Path(app.instance_path).mkdir(parents=True, exist_ok=True)

    init_app(app)
    app.register_blueprint(index_bp)
    app.register_blueprint(members_bp)

    return app
