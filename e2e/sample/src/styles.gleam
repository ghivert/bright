import gleam/int
import lustre/attribute as a
import sketch
import sketch/lustre/element/html as h
import sketch/media
import sketch/size.{px}

pub const fonts = "system-ui,-apple-system,BlinkMacSystemFont,\"Segoe UI\",Roboto,Oxygen,Ubuntu,Cantarell,\"Open Sans\",\"Helvetica Neue\",sans-serif"

pub fn intro() {
  sketch.class([
    sketch.padding(px(40)),
    sketch.padding_top(px(0)),
    sketch.font_family(fonts),
    sketch.margin_bottom(px(20)),
  ])
}

pub fn title(title) {
  sketch.class([sketch.font_family("VCR"), sketch.font_weight("bold")])
  |> h.h2([a.class("flickering")], [h.text(title)])
}

pub fn nav() {
  sketch.class([
    sketch.padding(px(40)),
    sketch.font_size(size.rem(2.0)),
    sketch.font_weight("bold"),
    sketch.letter_spacing("6px"),
  ])
  |> h.nav([a.class("flickering")], [h.text("SCART")])
}

pub fn counter(attrs, children) {
  sketch.class([
    sketch.display("flex"),
    sketch.flex_direction("column"),
    sketch.align_items("center"),
    sketch.background("#333"),
    sketch.color("white"),
    sketch.height(px(220)),
    sketch.width(px(220)),
    sketch.border_radius(px(2)),
    sketch.position("relative"),
    sketch.z_index(100),
  ])
  |> h.div(attrs, children)
}

pub fn button(attrs, children) {
  sketch.class([
    sketch.appearance("none"),
    sketch.border_radius(px(2)),
    sketch.background("#555"),
    sketch.display("flex"),
    sketch.border("1px solid white"),
    sketch.align_items("center"),
    sketch.justify_content("center"),
    sketch.padding(px(10)),
    sketch.cursor("pointer"),
    sketch.font_family("inherit"),
    sketch.color("inherit"),
    sketch.font_size_("inherit"),
    sketch.text_transform("uppercase"),
    sketch.font_weight("bold"),
  ])
  |> h.button([a.class("flickering"), ..attrs], children)
}

pub fn counter_number(counter) {
  sketch.class([
    sketch.flex("1"),
    sketch.display("flex"),
    sketch.align_items("center"),
    sketch.padding_top(px(20)),
    sketch.font_weight("bold"),
    sketch.font_size(size.rem(1.4)),
  ])
  |> h.div([], [h.text(int.to_string(counter))])
}

pub fn buttons_wrapper(attrs, children) {
  sketch.class([
    sketch.display("flex"),
    sketch.flex_direction("column"),
    sketch.padding(px(10)),
    sketch.justify_content("space-evenly"),
    sketch.width(size.percent(100)),
    sketch.gap(px(10)),
  ])
  |> h.div(attrs, children)
}

pub fn counter_infos(attrs, children) {
  sketch.class([
    sketch.background("#555"),
    sketch.position("absolute"),
    sketch.top(px(110)),
    sketch.left(px(50)),
    sketch.width(px(250)),
    sketch.height(px(250)),
    sketch.z_index(10),
    sketch.display("flex"),
    sketch.flex_direction("column"),
    sketch.justify_content("end"),
    sketch.padding(px(10)),
    sketch.media(media.max_width(px(400)), [sketch.width(px(200))]),
  ])
  |> h.div(attrs, children)
}

pub fn computed(title, content) {
  h.div_([], [h.text(title), h.text(int.to_string(content))])
}

pub fn container(attrs, children) {
  sketch.class([
    sketch.display("flex"),
    sketch.gap(px(10)),
    sketch.justify_content("center"),
    sketch.media(media.max_width(px(700)), [
      sketch.flex_direction("column"),
      sketch.align_items("center"),
    ]),
  ])
  |> h.div([a.class("flickering"), ..attrs], children)
}

pub fn counter_wrapper(attrs, children) {
  sketch.class([
    sketch.position("relative"),
    sketch.width(px(350)),
    sketch.height(px(400)),
    sketch.media(media.max_width(px(400)), [sketch.width(px(250))]),
  ])
  |> h.div(attrs, children)
}
