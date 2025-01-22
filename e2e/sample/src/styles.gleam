import gleam/int
import icons
import lustre/attribute as a
import sketch/css
import sketch/css/length.{px}
import sketch/css/media
import sketch/lustre/element/html as h

pub fn intro() {
  css.class([
    css.padding(px(40)),
    css.padding_top(px(0)),
    css.margin_bottom(px(20)),
    css.first_of_type([css.padding_top(px(40))]),
  ])
}

pub fn title(title) {
  css.class([css.font_weight("bold")])
  |> h.h2([], [h.text(title)])
}

pub fn nav() {
  css.class([
    css.font_size(length.rem(1.3)),
    css.font_weight("bold"),
    css.display("flex"),
    css.justify_content("space-between"),
    css.margin(px(18)),
    css.gap(px(36)),
    css.background("var(--navbar-background)"),
    css.position("sticky"),
    css.border_radius(px(10)),
    css.top(px(18)),
    css.border("1px solid var(--dark-background)"),
    css.backdrop_filter("blur(8px)"),
  ])
  |> h.nav([a.id("navbar")], [
    css.class([
      css.display("flex"),
      css.align_items("center"),
      css.padding_left(px(18)),
    ])
      |> h.div([], [h.text("Bright")]),
    h.div_([], []),
    h.div(
      css.class([css.display("flex"), css.gap(px(24)), css.padding(px(18))]),
      [],
      [
        external_icon("https://hexdocs.pm/bright", icons.book_open()),
        external_icon("https://github.com/ghivert/bright", icons.github()),
      ],
    ),
  ])
}

fn external_icon(url, icon) {
  css.class([
    css.color("#aaa"),
    css.transition("all .3s"),
    css.hover([css.color("var(--text-color)")]),
  ])
  |> h.a([a.href(url)], [icons.small(icon)])
}

pub fn counter(attrs, children) {
  css.class([
    css.display("flex"),
    css.flex_direction("column"),
    css.align_items("center"),
    css.background("var(--darker-background)"),
    css.color("var(--text-color)"),
    css.height(px(220)),
    css.width(px(220)),
    css.border_radius(px(2)),
    css.position("relative"),
    css.z_index(100),
    css.border_radius(px(10)),
  ])
  |> h.div(attrs, children)
}

pub fn button(attrs, children) {
  css.class([
    css.appearance("none"),
    css.border_radius(px(5)),
    css.background("var(--dark-background)"),
    css.display("flex"),
    css.border("1px solid var(--border-color)"),
    css.align_items("center"),
    css.justify_content("center"),
    css.padding(px(10)),
    css.cursor("pointer"),
    css.font_family("inherit"),
    css.color("var(--text-color)"),
    css.font_size_("inherit"),
    css.text_transform("uppercase"),
    css.font_weight("bold"),
    css.hover([css.background("var(--button-hover)")]),
  ])
  |> h.button(attrs, children)
}

pub fn counter_number(counter) {
  css.class([
    css.flex("1"),
    css.display("flex"),
    css.align_items("center"),
    css.padding_top(px(20)),
    css.font_weight("bold"),
    css.font_size(length.rem(1.4)),
  ])
  |> h.div([], [h.text(int.to_string(counter))])
}

pub fn buttons_wrapper(attrs, children) {
  css.class([
    css.display("flex"),
    css.flex_direction("column"),
    css.padding(px(10)),
    css.justify_content("space-evenly"),
    css.width(length.percent(100)),
    css.gap(px(10)),
  ])
  |> h.div(attrs, children)
}

pub fn counter_infos(attrs, children) {
  css.class([
    css.font_family("Fira Code"),
    css.background("var(--dark-background)"),
    css.position("absolute"),
    css.top(px(110)),
    css.left(px(50)),
    css.width(px(250)),
    css.height(px(250)),
    css.z_index(10),
    css.display("flex"),
    css.flex_direction("column"),
    css.justify_content("end"),
    css.padding(px(10)),
    css.border_radius(px(10)),
    css.media(media.max_width(px(400)), [css.width(px(200))]),
  ])
  |> h.div(attrs, children)
}

pub fn computed(title, content) {
  h.div_([], [h.text(title), h.text(int.to_string(content))])
}

pub fn container(attrs, children) {
  css.class([
    css.display("flex"),
    css.gap(px(10)),
    css.justify_content("center"),
    css.media(media.max_width(px(700)), [
      css.flex_direction("column"),
      css.align_items("center"),
    ]),
  ])
  |> h.div(attrs, children)
}

pub fn counter_wrapper(attrs, children) {
  css.class([
    css.position("relative"),
    css.width(px(350)),
    css.height(px(400)),
    css.media(media.max_width(px(400)), [css.width(px(250))]),
  ])
  |> h.div(attrs, children)
}

pub fn footer(attrs, children) {
  css.class([
    css.text_align("center"),
    css.margin_top(px(60)),
    css.margin_bottom(px(30)),
    css.color("var(--text-grey)"),
  ])
  |> h.div(attrs, children)
}

pub fn body(attrs, children) {
  css.class([css.max_width(px(1000)), css.margin_("auto")])
  |> h.div(attrs, children)
}
