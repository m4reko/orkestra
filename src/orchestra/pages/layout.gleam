import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub fn wrap(title: String, content: Element(a)) -> Element(a) {
  html.html([attribute.attribute("lang", "sv")], [
    html.head([], [
      html.meta([attribute.attribute("charset", "utf-8")]),
      html.meta([
        attribute.name("viewport"),
        attribute.attribute("content", "width=device-width, initial-scale=1"),
      ]),
      html.title([], title),
      html.link([
        attribute.rel("stylesheet"),
        attribute.href("/static/css/output.css"),
      ]),
      html.script(
        [attribute.src("/static/htmx.min.js"), attribute.attribute("defer", "")],
        "",
      ),
    ]),
    html.body([attribute.class("bg-gray-50 text-gray-900")], [
      html.nav([attribute.class("bg-white border-b px-4 py-2")], [
        html.a([attribute.href("/members"), attribute.class("font-semibold")], [
          element.text("Uppsala Blåsarsymfoniker"),
        ]),
      ]),
      html.main([attribute.class("max-w-5xl mx-auto px-4 py-6")], [content]),
    ]),
  ])
}
