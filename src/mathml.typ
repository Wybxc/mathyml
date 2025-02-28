#import "prelude.typ"
#import "unicode.typ" as _unicode: convert_variants
#import "convert.typ"
#import "utils.typ": is-html

#let maybe-html(transform, inner) = context {
  if is-html() {
    transform(inner)
  } else {
    inner
  }
}

#let html-framed(content, block: true, attrs: none, class: none, center: auto) = {
  let maybe-center = if block {
    if center == auto or center == true {
      "typstmathml-block-center "
    } else {
      ""
    }
  } else {
    if center != auto and center != none {
      panic("center is only supported for blocks")
    } else {
      ""
    }
  }
  let default-class = if class != none {
    let r = maybe-center + class
    if not r.ends-with(" ") {
      r += " "
    }
    r
  } else {
    maybe-center
  }
  let elem = if block {
    "div"
  } else {
    default-class += "typstmathml-inline-span "
    "span"
  }
  // TODO
  // let light-attrs = (class: default-class + "lighttheme") + attrs
  // let dark-attrs = (class: default-class + " darktheme") + attrs

  // html.elem(elem, attrs: light-attrs, html.frame(content))
  // html.elem(elem, attrs: dark-attrs, html.frame(theme.dark(content)))
  html.elem(elem, attrs: (class: default-class) + attrs, html.frame(content))
}

#let mathfonts() = html.elem("link", attrs: (rel: "stylesheet", href: "https://fred-wang.github.io/MathFonts/LatinModern/mathfonts.css"))

#let stylesheets(include-fonts: true) = context if is-html() {
  html.elem("style")[
  #```CSS
  .typstmathml-block-center {
    text-align: center;
  }
  .typstmathml-inline-span {
    /* font-size: 0pt; */
    display: inline-block;
  }
  .typstmathml-align-right {
    text-align: right;
    padding-left: 0em;
    padding-right: 0em;
  }
  .typstmathml-align-left {
    text-align: left;
    padding-left: 0em;
    padding-right: 0em;
  }
  ```.text
  ]

  if include-fonts {
    mathfonts()
  }
}

#let to-mathml(
  inner,
  block: auto,
) = {
  if type(inner) == content and inner.func() == math.equation {
    if block == auto {
      block = inner.block
      inner = inner.body
    } else {
      inner = inner.body
    }
  }
  if block == auto {
    block = false
  }
  let inner = convert.convert-mathml(inner, size: if block { "display" } else { "text" })
  if block {
    return html.elem("math", attrs: (display: "block"), inner)
  } else {
    return html.elem("span", html.elem("math", inner))
  }
}

