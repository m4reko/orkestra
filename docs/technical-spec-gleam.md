# Technical & Architectural Spec (Gleam)

Companion to [mvp-spec.md](mvp-spec.md). This document covers _how_ the system is built, not _what_ it does.

---

## 1. Tech Stack

| Layer | Choice | Notes |
|-------|--------|-------|
| Language | Gleam (on BEAM/Erlang) | Statically typed, functional, compiles to Erlang |
| Web framework | Wisp | Function-oriented request/response handlers |
| HTTP server | Mist | Erlang-based, runs Wisp handlers. Caddy reverse proxy for TLS. |
| HTML generation | Lustre (SSR) | Type-safe HTML builder, server-side rendering only |
| HTMX attributes | hx | Lustre-compatible HTMX attribute helpers |
| Database | SQLite (single file) | Via sqlight (esqlite NIF) |
| DB access | Raw SQL via sqlight | Parameterized queries with typed decoders |
| Migrations | Plain SQL files | Run directly via `sqlight.exec` at startup. No migration library. |
| Frontend interactivity | HTMX 4 | Served from static files, no CDN dependency |
| CSS | Tailwind CSS (standalone CLI) | No Node.js. Downloaded binary. |
| Auth (admin/leader) | Google OAuth 2.0 | Manual HTTP flow via `gleam_httpc` |
| Auth (member) | Magic links with signed tokens | Wisp signed cookies for session state |
| Email | External (Google Apps Script) | Polls a JSON notification API |
| Deployment | Single Linux VM | Podman container, systemd quadlet, Caddy reverse proxy (auto-TLS) |
| Testing | gleeunit | Standard Gleam test framework |
| Package manager | gleam (hex packages) | `gleam add`, `gleam run`, `gleam test` |

### Why Gleam

- **Exhaustive pattern matching** eliminates missed cases and None-handling bugs.
- **Immutable data** and **Result types** (no runtime exceptions) make the app predictable.
- **BEAM runtime** gives lightweight processes, supervision trees, and graceful crash recovery.
- **Type-safe SQL decoders** catch column type mismatches at compile time.

### Why Lustre for SSR (not as an SPA)

Lustre's `element` module provides a type-safe HTML builder. We use it purely for server-side HTML generation — no client-side Lustre runtime is shipped. The `hx` library builds on Lustre's attribute types to provide typed HTMX attributes.

### Why plain SQL migrations

The data model is small (< 15 tables) and only one developer runs migrations. SQL files in a directory are applied in order at startup, tracked by a simple `_migrations` table. No migration library needed — `sqlight.exec` handles it.

### Why no Node.js

The standalone Tailwind CSS CLI binary is downloaded directly. HTMX is a single JS file served statically. No Node.js or npm anywhere.

### Email

Same approach as the Python version: an external Google Apps Script polls the app's JSON API for pending notifications and dispatches email via Gmail. Keeps SMTP out of the app.

---

## 2. Project Structure

```
orchestra/
├── src/
│   └── orchestra/
│       ├── orchestra.gleam       # Entry point: migrations, Mist start
│       ├── web.gleam             # Context type, middleware stack
│       ├── router.gleam          # Top-level route dispatch
│       ├── db.gleam              # Connection helpers, pragmas, migration runner
│       ├── auth.gleam            # Google OAuth + magic link logic
│       ├── routes/               # Route modules, one per domain
│       │   ├── members.gleam
│       │   ├── projects.gleam
│       │   ├── absences.gleam
│       │   └── api.gleam
│       ├── queries/              # SQL query functions, one per table group
│       │   ├── member_queries.gleam
│       │   ├── project_queries.gleam
│       │   └── absence_queries.gleam
│       └── pages/                # Lustre HTML builders (templates)
│           ├── layout.gleam      # Base page layout, nav
│           ├── member_pages.gleam
│           ├── project_pages.gleam
│           └── components.gleam  # Shared UI components
├── priv/
│   ├── migrations/               # Plain SQL files, applied in order
│   │   ├── 0001_create_sections_instruments.sql
│   │   ├── 0002_create_persons.sql
│   │   └── ...
│   └── static/                   # htmx.min.js, compiled CSS
├── test/
├── docs/
└── gleam.toml
```

### Routing convention

The top-level router dispatches on path segments via pattern matching. Each route module handles a domain and further matches on HTTP method. Follows the same pattern as j26-booking:

```gleam
// router.gleam
pub fn handle_request(req: Request, ctx: Context) -> Response {
  use req, ctx <- web.middleware(req, ctx)

  case wisp.path_segments(req) {
    [] -> home_page(req, ctx)
    ["members", ..rest] -> members.handle(req, ctx, rest)
    ["projects", ..rest] -> projects.handle(req, ctx, rest)
    ["api", ..rest] -> api.handle(req, ctx, rest)
    _ -> wisp.not_found()
  }
}
```

### HTMX fragment convention

Routes check for the `HX-Request` header to decide between a full page and an HTML fragment:

```gleam
pub fn respond_html(req: Request, full_page: Element(a), fragment: Element(a)) -> Response {
  let html = case wisp.get_header(req, "hx-request") {
    Ok("true") -> element.to_string(fragment)
    _ -> element.to_document_string(full_page)
  }
  wisp.ok()
  |> wisp.html_body(string_builder.from_string(html))
}
```

---

## 3. Architecture

### Request flow

```
Browser ──HTMX──▶ Caddy (TLS) ──▶ Mist (port 8000) ──▶ Wisp handler ──▶ sqlight ──▶ SQLite
                                              │
                                              ▼
                                        Lustre SSR → HTML fragment
                                              │
                                              ▼
                                        Browser (HTMX swaps DOM)

Apps Script ──poll──▶ /api/notifications/pending ──▶ Gmail
```

### Context and middleware

Application state is passed through a `Context` type, following the j26-booking pattern:

```gleam
pub type Context {
  Context(
    db: sqlight.Connection,
    secret_key_base: String,
    static_directory: String,
    auth: AuthResult,
  )
}

pub type AuthResult {
  NotAuthenticated
  AdminSession(account: Account)
  MemberSession(person_id: Int)
}

pub fn middleware(
  req: Request,
  ctx: Context,
  handle_request: fn(Request, Context) -> Response,
) -> Response {
  let req = wisp.method_override(req)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)
  use <- wisp.serve_static(req, under: "/static", from: ctx.static_directory)
  let ctx = authenticate(req, ctx)
  handle_request(req, ctx)
}
```

### Entry point with supervision

```gleam
// orchestra.gleam
pub fn main() -> Nil {
  wisp.configure_logger()

  let secret_key_base = get_secret_key_base()
  let assert Ok(priv_dir) = wisp.priv_directory("orchestra")

  // Open DB and run migrations
  let assert Ok(db) = sqlight.open("./orchestra.db")
  let assert Ok(Nil) = db.configure(db)
  let assert Ok(Nil) = db.run_migrations(db, priv_dir <> "/migrations")

  let ctx = Context(
    db: db,
    secret_key_base: secret_key_base,
    static_directory: priv_dir <> "/static",
    auth: NotAuthenticated,
  )

  let handler = fn(req) { router.handle_request(req, ctx) }
  let assert Ok(_) =
    wisp_mist.handler(handler, secret_key_base)
    |> mist.new
    |> mist.port(8000)
    |> mist.bind("0.0.0.0")
    |> mist.start_http

  process.sleep_forever()
}
```

### HTMX patterns

Same patterns as the Python version, expressed with Lustre + hx:

**Pattern 1: Inline editing**
```gleam
// Display mode
div([hx.get("/members/42/edit"), hx.swap(hx.OuterHTML)], [
  text("Anna Andersson — Tvärflöjt"),
])

// Edit mode (returned as fragment)
html.form(
  [hx.put("/members/42"), hx.swap(hx.OuterHTML)],
  [input([attribute.name("first_name"), attribute.value("Anna")]), ...],
)
```

**Pattern 2: List filtering with throttled search**
```gleam
input([
  attribute.type_("search"),
  attribute.name("search"),
  attribute.placeholder("Sök..."),
  hx.get("/members"),
  hx.trigger([hx.with_throttle(hx.input(), duration.milliseconds(300))]),
  hx.target(hx.Selector("#member-list")),
  hx.swap(hx.InnerHTML),
])
```

**Pattern 3: Absence toggle**
```gleam
button(
  [
    hx.post("/absences"),
    hx.vals("{\"project_id\": 1, \"rehearsal_date\": \"2026-04-10\"}"),
    hx.swap(hx.OuterHTML),
  ],
  [text("Anmäl frånvaro")],
)
```

### HTML-first, with a small JSON API for integrations

Browser-facing routes return HTML via Lustre SSR. HTMX sends form-encoded data and receives HTML back.

A small JSON API (`/api/...`) exists for external integrations — at minimum for the Apps Script email sender. JSON responses use `wisp.json_response` with `gleam/json` for encoding.

---

## 4. Data Model

The data model is identical to the Python version — see [mvp-spec.md](mvp-spec.md) for the conceptual model and [technical-spec-python.md](technical-spec-python.md) for the full ER diagram. The SQL schema uses the same tables:

```
section, instrument, person, person_instrument, membership_period,
account, section_leader, project, rehearsal_date, sheet_music_link,
project_assignment, rehearsal_absence, magic_token, notification
```

### Decoders

Each table has a corresponding decoder for type-safe row parsing:

```gleam
pub type Person {
  Person(
    id: Int,
    first_name: String,
    last_name: String,
    email: String,
    phone: String,
    section_id: Int,
  )
}

fn person_decoder() -> decode.Decoder(Person) {
  use id <- decode.field(0, decode.int)
  use first_name <- decode.field(1, decode.string)
  use last_name <- decode.field(2, decode.string)
  use email <- decode.field(3, decode.string)
  use phone <- decode.field(4, decode.string)
  use section_id <- decode.field(5, decode.int)
  decode.success(Person(id:, first_name:, last_name:, email:, phone:, section_id:))
}
```

### Query functions

```gleam
pub fn list_members(db: sqlight.Connection, section_id: Option(Int), search: String) {
  let base = "SELECT id, first_name, last_name, email, phone, section_id FROM person"
  // Build WHERE clauses based on filters
  sqlight.query(sql, on: db, with: params, expecting: person_decoder())
}
```

### SQLite pragmas (set on every connection)

```gleam
pub fn configure(conn: sqlight.Connection) -> Result(Nil, sqlight.Error) {
  sqlight.exec("PRAGMA journal_mode = WAL;", conn)
  |> result.try(fn(_) { sqlight.exec("PRAGMA foreign_keys = ON;", conn) })
  |> result.try(fn(_) { sqlight.exec("PRAGMA busy_timeout = 5000;", conn) })
  |> result.try(fn(_) { sqlight.exec("PRAGMA synchronous = NORMAL;", conn) })
}
```

### Migrations: plain SQL files

Migration files live in `priv/migrations/` as numbered SQL files. A `_migrations` table tracks which have been applied:

```gleam
pub fn run_migrations(
  conn: sqlight.Connection,
  migrations_dir: String,
) -> Result(Nil, String) {
  // 1. Create _migrations table if not exists
  // 2. Read SQL files from migrations_dir, sorted by filename
  // 3. For each file not yet in _migrations:
  //    - Execute the SQL via sqlight.exec
  //    - Insert filename into _migrations
  // 4. Return Ok(Nil) or error
}
```

```sql
-- priv/migrations/0001_create_sections_instruments.sql
CREATE TABLE IF NOT EXISTS section (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS instrument (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    section_id INTEGER NOT NULL REFERENCES section(id)
);

-- Seed data
INSERT INTO section (name) VALUES
  ('Flöjt'), ('Oboe'), ('Fagott'), ('Klarinett'), ('Saxofon'),
  ('Valthorn'), ('Trumpet'), ('Trombon'), ('Euphonium'), ('Tuba'),
  ('Slagverk'), ('Kontrabas/Harpa/Piano'), ('Dirigent');

INSERT INTO instrument (name, section_id) VALUES
  ('Tvärflöjt', 1), ('Piccolaflöjt', 1),
  ('Oboe', 2), ('Engelskt horn', 2),
  -- ... etc
```

### sqlight gotchas

- **Boolean decoding:** SQLite has no native boolean. Use `sqlight.decode_bool()` (treats 0 as False, nonzero as True), not `decode.bool` from stdlib.
- **Single statement per query:** `sqlight.query` runs one statement. For multi-statement DDL (like migrations), use `sqlight.exec`.
- **Nullable fields:** Use `sqlight.nullable(sqlight.text, option_value)` for optional parameters and `decode.optional` for nullable result columns.

---

## 5. Auth Implementation

### Admin / Section leader: Google OAuth 2.0

Implemented manually using `gleam_httpc` for HTTP requests:

1. User clicks "Logga in" → redirect to Google authorization URL
2. Google callback returns authorization code
3. Exchange code for tokens via POST to Google token endpoint
4. Extract email from ID token (decode JWT claims)
5. Look up `account` by `google_email`
6. If found → set signed session cookie via `wisp.set_cookie` with `Signed` security
7. If not found → reject with "not authorized" message

Session data in signed cookies:

```gleam
wisp.set_cookie(
  response,
  req,
  "session",
  json.to_string(session_json),
  wisp.Signed,
  60 * 60 * 24 * 30,  // 30 days
)
```

### Member: Magic links

1. Admin triggers "send magic links" for a project
2. System generates a token per assigned member (via `crypto.strong_random_bytes`)
3. Token hash (SHA-256) stored in `magic_token` table
4. Token + member info queued as a pending notification
5. Member clicks link → token verified → signed session cookie set
6. Token expiry = latest concert date among member's active assignments

### Authorization helpers

```gleam
pub fn require_admin(
  ctx: Context,
  handler: fn(Account) -> Response,
) -> Response {
  case ctx.auth {
    AdminSession(account) if account.is_admin -> handler(account)
    _ -> wisp.response(403) |> wisp.string_body("Forbidden")
  }
}

pub fn require_section_leader(
  ctx: Context,
  section_ids: List(Int),
  handler: fn(Account) -> Response,
) -> Response {
  case ctx.auth {
    AdminSession(account) if account.is_admin -> handler(account)
    AdminSession(account) -> {
      case list.any(section_ids, fn(id) { list.contains(account.sections, id) }) {
        True -> handler(account)
        False -> wisp.response(403) |> wisp.string_body("Forbidden")
      }
    }
    _ -> wisp.response(403) |> wisp.string_body("Forbidden")
  }
}
```

---

## 6. Key Design Decisions

### D1: Raw SQL over ORM

**Decision:** Use sqlight directly with parameterized queries and typed decoders.
**Rationale:** < 15 tables, simple queries, one developer. Gleam's decoder pattern gives type safety at the boundary without an ORM. Queries stay searchable and debuggable.

### D2: No SPA, no client-side state

**Decision:** Server-rendered HTML via Lustre SSR + HTMX for all interactivity.
**Rationale:** No client-side Lustre runtime shipped. No JavaScript bundle beyond htmx.min.js. Same mental model as the Python version — server renders everything.

### D3: Lustre + hx over string templates

**Decision:** Use Lustre's `element` module for HTML generation instead of string-based templates.
**Rationale:** Type-safe HTML construction catches typos and structural errors at compile time. The `hx` library provides typed HTMX attributes. No template language to learn — it's just Gleam functions.

### D4: Plain SQL migrations over a library

**Decision:** SQL files in `priv/migrations/` applied at startup via `sqlight.exec`, tracked in a `_migrations` table.
**Rationale:** The data model is small and changes rarely. A simple migration runner (< 50 lines) avoids a dependency. SQL files are directly executable in any SQLite tool for debugging. No down migrations — for rollback, write a new forward migration.

### D5: Caddy reverse proxy for TLS

**Decision:** Mist binds to port 8000 on localhost. Caddy handles TLS termination and reverse proxying.
**Rationale:** Caddy provides automatic HTTPS via Let's Encrypt with zero configuration. Mist handles application-level HTTP, Caddy handles TLS and certificate renewal. This follows the [official Gleam deployment guide](https://gleam.run/deployment/linux-server/).

### D6: Functional style (natural in Gleam)

**Decision:** Everything is functions. No classes, no service objects.
**Rationale:** Gleam is purely functional. Route handlers are functions: request + context in → response out. DB queries are functions that take a connection and return `Result(data, Error)`.

### D7: Swedish UI, English code

**Decision:** User-facing text in Swedish, code (variable names, comments, git) in English.
**Rationale:** Users are Swedish speakers. Code stays in English for consistency with libraries and tooling.

### D8: Result types for error handling

**Decision:** All fallible operations return `Result(value, error)`. No panics in application code.
**Rationale:** Gleam has no exceptions. The compiler forces you to handle every error case. `let assert` is used only for truly impossible startup failures. Application logic uses `result.try`, `result.map`, and `case`.

---

## 7. Development Workflow

### Commands

| Task | Command |
|------|---------|
| Build | `gleam build` |
| Run | `gleam run` |
| Test | `gleam test` |
| Add dependency | `gleam add <package>` |
| Format | `gleam format` |
| Compile CSS | `tailwindcss -i priv/static/css/input.css -o priv/static/css/output.css` |

### Dependencies (gleam.toml)

```toml
[dependencies]
gleam_stdlib = ">= 0.44.0 and < 2.0.0"
gleam_http = ">= 4.0.0 and < 5.0.0"
gleam_json = ">= 3.0.0 and < 4.0.0"
gleam_erlang = ">= 1.0.0 and < 2.0.0"
gleam_crypto = ">= 1.0.0 and < 2.0.0"
gleam_httpc = ">= 5.0.0 and < 6.0.0"
wisp = ">= 2.2.0 and < 3.0.0"
mist = ">= 5.0.0 and < 6.0.0"
sqlight = ">= 1.0.0 and < 2.0.0"
lustre = ">= 5.0.0 and < 6.0.0"
hx = ">= 3.0.0 and < 4.0.0"
envoy = ">= 1.0.0 and < 2.0.0"
gleam_time = ">= 1.0.0 and < 2.0.0"

[dev-dependencies]
gleeunit = ">= 1.0.0 and < 2.0.0"
```

### Deployment

Follows the [official Gleam Linux server guide](https://gleam.run/deployment/linux-server/) as a starting point. Details TBD — likely Google Cloud Compute.

**Container image** built via multi-stage Dockerfile:
1. Copy Gleam binary from official image
2. `gleam export erlang-shipment` → self-contained Erlang release
3. Minimal Alpine runtime image with the shipment

**Caddy** reverse proxy for automatic HTTPS (Let's Encrypt).

**GitHub Actions** builds and pushes the container image to GHCR on version tags.
