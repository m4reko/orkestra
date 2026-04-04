from flask import render_template, request


def render(template: str, partial: str | None = None, **context: object) -> str:
    """Render a full page or HTMX partial based on the request type."""
    if request.headers.get("HX-Request"):
        return render_template(partial or template, **context)
    return render_template(template, **context)
