import sqlite3
import tempfile
import time
from collections.abc import Iterator
from pathlib import Path

import pytest
from flask import Flask
from flask.testing import FlaskClient
from yoyo import get_backend, read_migrations  # type: ignore[import-untyped]

from app import create_app

PERSON_INSERT = (
    "INSERT INTO person"
    " (id, first_name, last_name, section_id,"
    " created_at, updated_at)"
    " VALUES (?, ?, ?, ?, ?, ?)"
)

PI_INSERT = "INSERT INTO person_instrument (person_id, instrument_id) VALUES (?, ?)"

MP_INSERT = (
    "INSERT INTO membership_period (person_id, start_date, end_date) VALUES (?, ?, ?)"
)


def _lookup(
    conn: sqlite3.Connection,
    table: str,
    name: str,
) -> int:
    row = conn.execute(
        f"SELECT id FROM {table} WHERE name = ?",  # noqa: S608
        (name,),
    ).fetchone()
    if row is None:
        msg = f"{table} '{name}' not found"
        raise ValueError(msg)
    return row[0]  # type: ignore[no-any-return]


def _seed_test_data(db_path: str) -> None:
    """Insert test members across different statuses."""
    now = int(time.time())
    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA foreign_keys = ON")

    sec_flojt = _lookup(conn, "section", "Flöjt")
    sec_trumpet = _lookup(conn, "section", "Trumpet")
    sec_klarinett = _lookup(conn, "section", "Klarinett")
    sec_slagverk = _lookup(conn, "section", "Slagverk")

    i_tvarflojt = _lookup(conn, "instrument", "Tvärflöjt")
    i_trumpet = _lookup(conn, "instrument", "Trumpet")
    i_klarinett = _lookup(conn, "instrument", "Klarinett")
    i_slagverk = _lookup(conn, "instrument", "Slagverk")

    # Anna Andersson — Flöjt, current member
    conn.execute(
        PERSON_INSERT,
        (1, "Anna", "Andersson", sec_flojt, now, now),
    )
    conn.execute(PI_INSERT, (1, i_tvarflojt))
    conn.execute(MP_INSERT, (1, "2020-01-01", None))

    # Björn Björkman — Trumpet, former member
    conn.execute(
        PERSON_INSERT,
        (2, "Björn", "Björkman", sec_trumpet, now, now),
    )
    conn.execute(PI_INSERT, (2, i_trumpet))
    conn.execute(MP_INSERT, (2, "2018-01-01", "2023-06-30"))

    # Cecilia Carlsson — Klarinett, non-member (substitute)
    conn.execute(
        PERSON_INSERT,
        (3, "Cecilia", "Carlsson", sec_klarinett, now, now),
    )
    conn.execute(PI_INSERT, (3, i_klarinett))

    # David Dahl — Slagverk, current member
    conn.execute(
        PERSON_INSERT,
        (4, "David", "Dahl", sec_slagverk, now, now),
    )
    conn.execute(PI_INSERT, (4, i_slagverk))
    conn.execute(MP_INSERT, (4, "2021-09-01", None))

    conn.commit()
    conn.close()


@pytest.fixture
def app() -> Iterator[Flask]:
    """Create app with a temporary test database."""
    with tempfile.NamedTemporaryFile(
        suffix=".db",
        delete=False,
    ) as f:
        db_path = f.name

    backend = get_backend(f"sqlite:///{db_path}")
    migrations = read_migrations(
        str(Path(__file__).parent.parent / "migrations"),
    )
    with backend.lock():
        backend.apply_migrations(
            backend.to_apply(migrations),
        )

    _seed_test_data(db_path)

    test_app = create_app(
        {"TESTING": True, "DATABASE": db_path},
    )
    yield test_app

    Path(db_path).unlink(missing_ok=True)


@pytest.fixture
def client(app: Flask) -> FlaskClient:
    """Flask test client."""
    return app.test_client()
