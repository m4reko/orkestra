# Orchestra

Internal member and project management system for Uppsala Blåsarsymfoniker.

## Getting started

```sh
gleam run                                        # Start server on http://localhost:8000
sqlite3 orchestra.db < scripts/seed_dev_data.sql # Seed dev data (optional)
```

The server creates `orchestra.db` and runs migrations automatically on startup.

## Development

```sh
gleam run          # Run the server
gleam test         # Run the tests
gleam run -m sqlgen # Regenerate SQL query module from sql/
```
