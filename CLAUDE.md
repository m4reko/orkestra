# CLAUDE.md

## Project

Internal member and project management system for Uppsala Blåsarsymfoniker (wind orchestra). See `docs/mvp-spec.md` for features and `docs/technical-spec.md` for architecture.

## Stack

- **Python >= 3.13** with Flask, Jinja2, HTMX 4, Tailwind CSS
- **SQLite** with raw SQL (no ORM)
- **yoyo-migrations** for schema changes
- **Google OAuth 2.0** for admin/leader auth, magic links for member auth
- **External email** via Google Apps Script polling a notification API

## Tooling

| Tool | Command | Purpose |
|------|---------|---------|
| uv | `uv run`, `uv sync` | Package management, virtual env |
| Ruff | `uv run ruff check .` | Linting |
| Ruff | `uv run ruff format .` | Formatting |
| Pyright | `uv run pyright` | Type checking (strict mode) |
| pytest | `uv run pytest` | Tests |
| yoyo | `uv run yoyo apply` | Run database migrations |
| Tailwind | `uv run tailwindcss -i app/static/css/input.css -o app/static/css/output.css` | CSS compilation (via pytailwindcss, no Node) |

## Git

- Use [Conventional Commits](https://www.conventionalcommits.org/) for all commit messages (e.g., `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`).

## Lint rules

Ruff is configured with an extensive rule set in `pyproject.toml`. If a rule produces frequent false positives or becomes noisy for this codebase, suggest adding it to the `ignore` list or `per-file-ignores` rather than working around it in code.

## Code style

- **Functional style:** functions over classes. No service objects or class-based views.
- **Type hints everywhere.** Pyright strict mode must pass.
- **Swedish UI, English code.** User-facing text in Swedish. Variable names, comments, and git messages in English.
- **Raw SQL.** No ORM. Queries are plain SQL strings in Python functions.
- **HTMX 4.** Routes return HTML fragments for HTMX requests, full pages otherwise.
