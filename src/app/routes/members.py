import sqlite3

from flask import Blueprint, request

from app.db import get_db
from app.render import render

members_bp = Blueprint("members", __name__)


def _build_member_query(
    status: str | None,
    section: str | None,
    search: str | None,
) -> tuple[str, list[object]]:
    """Build the member list query with dynamic filters."""
    params: list[object] = []

    sql = """
        WITH member_status AS (
            SELECT
                person_id,
                CASE
                    WHEN MAX(CASE WHEN end_date IS NULL THEN 1 ELSE 0 END) = 1
                    THEN 'current'
                    ELSE 'former'
                END AS status
            FROM membership_period
            GROUP BY person_id
        )
        SELECT
            p.id,
            p.first_name,
            p.last_name,
            s.name AS section_name,
            GROUP_CONCAT(i.name, ', ') AS instruments,
            COALESCE(ms.status, 'non-member') AS membership_status
        FROM person p
        LEFT JOIN section s ON p.section_id = s.id
        LEFT JOIN person_instrument pi ON p.id = pi.person_id
        LEFT JOIN instrument i ON pi.instrument_id = i.id
        LEFT JOIN member_status ms ON p.id = ms.person_id
        WHERE 1=1
    """

    if status:
        if status == "non-member":
            sql += " AND ms.status IS NULL"
        else:
            sql += " AND ms.status = ?"
            params.append(status)

    if section:
        sql += " AND p.section_id = ?"
        params.append(section)

    if search:
        sql += " AND (p.first_name || ' ' || p.last_name) LIKE ?"
        params.append(f"%{search}%")

    sql += " GROUP BY p.id ORDER BY p.last_name, p.first_name"

    return sql, params


def _fetch_sections(db: sqlite3.Connection) -> list[sqlite3.Row]:
    """Fetch all sections for the filter dropdown."""
    return db.execute("SELECT id, name FROM section ORDER BY name").fetchall()


@members_bp.get("/members")
def member_list() -> str:
    """List members with optional filtering."""
    db = get_db()

    status = request.args.get("status", "")
    section = request.args.get("section", "")
    search = request.args.get("search", "")

    sql, params = _build_member_query(
        status=status or None,
        section=section or None,
        search=search or None,
    )
    members = db.execute(sql, params).fetchall()
    sections = _fetch_sections(db)

    return render(
        "members/list.html",
        partial="members/partials/member_list.html",
        members=members,
        sections=sections,
        current_status=status,
        current_section=section,
        current_search=search,
    )
