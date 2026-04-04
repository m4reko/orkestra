import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub fn wrap(title: String, content: Element(a)) -> Element(a) {
  html.html(
    [
      attribute.attribute("lang", "sv"),
      attribute.attribute("data-theme", "ubs"),
    ],
    [
      html.head([], [
        html.meta([attribute.attribute("charset", "utf-8")]),
        html.meta([
          attribute.name("viewport"),
          attribute.attribute("content", "width=device-width, initial-scale=1"),
        ]),
        html.title([], title),
        html.link([
          attribute.rel("preconnect"),
          attribute.href("https://fonts.googleapis.com"),
        ]),
        html.link([
          attribute.rel("preconnect"),
          attribute.href("https://fonts.gstatic.com"),
          attribute.attribute("crossorigin", ""),
        ]),
        html.link([
          attribute.rel("stylesheet"),
          attribute.href(
            "https://fonts.googleapis.com/css2?family=Playfair+Display:wght@400;700&family=Source+Sans+3:wght@300;400;600&display=swap",
          ),
        ]),
        html.link([
          attribute.rel("stylesheet"),
          attribute.href("https://cdn.jsdelivr.net/npm/daisyui@5"),
          attribute.type_("text/css"),
        ]),
        html.link([
          attribute.rel("stylesheet"),
          attribute.href("/static/css/output.css"),
        ]),
        html.script(
          [
            attribute.src("/static/htmx.min.js"),
            attribute.attribute("defer", ""),
          ],
          "",
        ),
      ]),
      html.body([attribute.class("bg-base-100 text-base-content")], [
        html.div(
          [attribute.class("navbar bg-neutral text-neutral-content px-4")],
          [
            html.div([attribute.class("navbar-start")], [
              html.a(
                [
                  attribute.href("/members"),
                  attribute.class("text-lg font-bold"),
                ],
                [element.text("Uppsala Blåsarsymfoniker")],
              ),
            ]),
          ],
        ),
        html.main([attribute.class("max-w-5xl mx-auto px-4 py-6")], [content]),
      ]),
    ],
  )
}
