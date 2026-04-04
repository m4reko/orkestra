import sqlite3

from flask import Flask, current_app, g

from app.config import AppConfig


def get_db() -> sqlite3.Connection:
    """Get a per-request database connection."""
    if "db" not in g:
        config = AppConfig.from_app(current_app)
        g.db = sqlite3.connect(config.database)
        g.db.row_factory = sqlite3.Row
        g.db.execute("PRAGMA journal_mode = WAL")
        g.db.execute("PRAGMA foreign_keys = ON")
        g.db.execute("PRAGMA busy_timeout = 5000")
        g.db.execute("PRAGMA synchronous = NORMAL")
    return g.db


def close_db(_exc: BaseException | None = None) -> None:
    """Close the database connection at the end of a request."""
    db: sqlite3.Connection | None = g.pop("db", None)
    if db is not None:
        db.close()


def init_app(app: Flask) -> None:
    """Register database teardown and set default config."""
    if "DATABASE" not in app.config:
        AppConfig.default(app).apply(app)

    app.teardown_appcontext(close_db)
