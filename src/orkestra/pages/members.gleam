import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/time/duration
import hx
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import orkestra/models/instrument.{type Instrument}
import orkestra/models/person.{type MemberRow}
import orkestra/models/section.{type Section}

pub fn list_page(
  members: List(MemberRow),
  sections: List(Section),
  current_status: String,
  current_section: String,
  current_search: String,
) -> Element(a) {
  html.div([], [
    html.div([attribute.class("flex items-center justify-between mb-4")], [
      html.h1([attribute.class("text-xl font-bold")], [
        element.text("Medlemmar"),
      ]),
      html.a(
        [attribute.href("/members/new"), attribute.class("btn btn-primary")],
        [element.text("Lägg till person")],
      ),
    ]),
    filter_form(sections, current_status, current_section, current_search),
    html.div([attribute.id("member-list")], [member_table(members)]),
  ])
}

fn filter_form(
  sections: List(Section),
  current_status: String,
  current_section: String,
  current_search: String,
) -> Element(a) {
  html.form(
    [
      attribute.id("filter-form"),
      attribute.class("flex gap-3 mb-4 flex-wrap"),
    ],
    [
      status_select(current_status),
      section_select(sections, current_section),
      html.input([
        attribute.type_("search"),
        attribute.name("search"),
        attribute.value(current_search),
        attribute.placeholder("Sök namn..."),
        attribute.class("input input-sm"),
        hx.trigger([hx.with_delay(hx.input(), duration.milliseconds(300))]),
        ..filter_hx_attrs()
      ]),
    ],
  )
}

fn filter_hx_attrs() -> List(attribute.Attribute(a)) {
  [
    hx.get("/members"),
    hx.target(hx.Selector("#member-list")),
    hx.swap(hx.InnerHTML),
    attribute.attribute("hx-include", "#filter-form"),
  ]
}

fn status_select(current: String) -> Element(a) {
  html.select(
    [
      attribute.name("status"),
      attribute.class("select select-sm"),
      hx.trigger([hx.change()]),
      ..filter_hx_attrs()
    ],
    [
      html.option([attribute.value("")], "Alla statusar"),
      html.option(
        [attribute.value("current"), ..selected_if(current == "current")],
        "Aktiv medlem",
      ),
      html.option(
        [attribute.value("former"), ..selected_if(current == "former")],
        "Tidigare medlem",
      ),
      html.option(
        [attribute.value("non-member"), ..selected_if(current == "non-member")],
        "Icke-medlem",
      ),
    ],
  )
}

fn section_select(sections: List(Section), current: String) -> Element(a) {
  let section_options =
    list.map(sections, fn(s) {
      let id_str = int.to_string(s.id)
      html.option(
        [attribute.value(id_str), ..selected_if(current == id_str)],
        s.name,
      )
    })

  html.select(
    [
      attribute.name("section"),
      attribute.class("select select-sm"),
      hx.trigger([hx.change()]),
      ..filter_hx_attrs()
    ],
    [html.option([attribute.value("")], "Alla sektioner"), ..section_options],
  )
}

fn selected_if(condition: Bool) -> List(attribute.Attribute(a)) {
  case condition {
    True -> [attribute.selected(True)]
    False -> []
  }
}

pub fn member_table(members: List(MemberRow)) -> Element(a) {
  case members {
    [] ->
      html.p([attribute.class("text-base-content/60 py-4")], [
        element.text("Inga personer hittades."),
      ])
    _ ->
      html.table([attribute.class("table")], [
        html.thead([], [
          html.tr([], [
            html.th([], [element.text("Namn")]),
            html.th([], [element.text("Instrument")]),
            html.th([], [element.text("Sektion")]),
            html.th([], [element.text("Status")]),
          ]),
        ]),
        html.tbody([], list.map(members, member_row)),
      ])
  }
}

fn member_row(member: MemberRow) -> Element(a) {
  html.tr([], [
    html.td([], [
      element.text(member.first_name <> " " <> member.last_name),
    ]),
    html.td([], [
      element.text(option_or(member.instruments, "—")),
    ]),
    html.td([], [
      element.text(option_or(member.section_name, "—")),
    ]),
    html.td([], [status_badge(member.membership_status)]),
  ])
}

fn status_badge(status: String) -> Element(a) {
  let #(label, class) = case status {
    "current" -> #("Aktiv medlem", "badge badge-sm badge-success")
    "former" -> #("Tidigare medlem", "badge badge-sm badge-neutral")
    _ -> #("Icke-medlem", "badge badge-sm badge-ghost")
  }
  html.span([attribute.class(class)], [element.text(label)])
}

fn option_or(opt: Option(String), default: String) -> String {
  case opt {
    Some(s) -> s
    None -> default
  }
}

pub fn add_page(
  sections: List(Section),
  instruments: List(Instrument),
  today: String,
) -> Element(a) {
  html.div([], [
    html.h1([attribute.class("text-xl font-bold mb-4")], [
      element.text("Lägg till person"),
    ]),
    html.form(
      [
        attribute.method("post"),
        attribute.attribute("action", "/members"),
        attribute.class("space-y-4 max-w-lg"),
      ],
      [
        text_field("first_name", "Förnamn", True),
        text_field("last_name", "Efternamn", True),
        text_field("email", "E-post", False),
        text_field("phone", "Telefonnummer", False),
        text_field("street_address", "Gatuadress", False),
        text_field("postal_code", "Postnummer", False),
        text_field("city", "Postort", False),
        add_section_select(sections),
        instrument_checkboxes(instruments),
        membership_section(today),
        textarea_field("metadata", "Metadata"),
        html.div([attribute.class("flex gap-3")], [
          html.button(
            [attribute.type_("submit"), attribute.class("btn btn-primary")],
            [element.text("Spara")],
          ),
          html.a(
            [attribute.href("/members"), attribute.class("btn btn-ghost")],
            [element.text("Avbryt")],
          ),
        ]),
      ],
    ),
  ])
}

fn text_field(name: String, label: String, required: Bool) -> Element(a) {
  html.div([], [
    html.label([attribute.for(name), attribute.class("label")], [
      element.text(label),
    ]),
    html.input([
      attribute.type_("text"),
      attribute.name(name),
      attribute.id(name),
      attribute.class("input w-full"),
      ..case required {
        True -> [attribute.required(True)]
        False -> []
      }
    ]),
  ])
}

fn textarea_field(name: String, label: String) -> Element(a) {
  html.div([], [
    html.label([attribute.for(name), attribute.class("label")], [
      element.text(label),
    ]),
    html.textarea(
      [
        attribute.name(name),
        attribute.id(name),
        attribute.class("textarea w-full"),
        attribute.attribute("rows", "3"),
      ],
      "",
    ),
  ])
}

fn membership_section(today: String) -> Element(a) {
  html.fieldset([attribute.class("fieldset")], [
    html.legend([attribute.class("fieldset-legend")], [
      element.text("Medlemskap"),
    ]),
    html.label([attribute.class("flex items-center gap-2 text-sm")], [
      html.input([
        attribute.type_("checkbox"),
        attribute.name("active_member"),
        attribute.value("true"),
        attribute.class("checkbox checkbox-sm"),
        attribute.attribute(
          "onclick",
          "document.getElementById('membership-date').classList.toggle('hidden')",
        ),
      ]),
      element.text("Aktiv medlem"),
    ]),
    html.div([attribute.id("membership-date"), attribute.class("hidden")], [
      html.label(
        [
          attribute.for("membership_start"),
          attribute.class("label"),
        ],
        [element.text("Startdatum")],
      ),
      html.input([
        attribute.type_("date"),
        attribute.name("membership_start"),
        attribute.id("membership_start"),
        attribute.value(today),
        attribute.class("input w-full"),
      ]),
    ]),
  ])
}

fn add_section_select(sections: List(Section)) -> Element(a) {
  let section_options =
    list.map(sections, fn(s) {
      html.option([attribute.value(int.to_string(s.id))], s.name)
    })

  html.div([], [
    html.label([attribute.for("section_id"), attribute.class("label")], [
      element.text("Sektion"),
    ]),
    html.select(
      [
        attribute.name("section_id"),
        attribute.id("section_id"),
        attribute.class("select w-full"),
      ],
      [html.option([attribute.value("")], "Ingen sektion"), ..section_options],
    ),
  ])
}

fn instrument_checkboxes(instruments: List(Instrument)) -> Element(a) {
  let grouped = group_by_section(instruments)
  html.fieldset([attribute.class("fieldset")], [
    html.legend([attribute.class("fieldset-legend")], [
      element.text("Instrument"),
    ]),
    ..list.map(grouped, fn(group) {
      let #(section_name, section_instruments) = group
      html.div([], [
        html.p(
          [attribute.class("text-xs text-base-content/60 font-medium mt-2")],
          [element.text(section_name)],
        ),
        html.div(
          [attribute.class("flex flex-wrap gap-x-4 gap-y-1")],
          list.map(section_instruments, fn(i) {
            let id_str = int.to_string(i.id)
            html.label([attribute.class("flex items-center gap-1 text-sm")], [
              html.input([
                attribute.type_("checkbox"),
                attribute.name("instrument"),
                attribute.value(id_str),
                attribute.class("checkbox checkbox-sm"),
              ]),
              element.text(i.name),
            ])
          }),
        ),
      ])
    })
  ])
}

fn group_by_section(
  instruments: List(Instrument),
) -> List(#(String, List(Instrument))) {
  list.fold(instruments, [], fn(acc, i) {
    case acc {
      [] -> [#(i.section_name, [i])]
      [#(name, items), ..rest] if name == i.section_name -> [
        #(name, list.append(items, [i])),
        ..rest
      ]
      _ -> [#(i.section_name, [i]), ..acc]
    }
  })
  |> list.reverse
}
