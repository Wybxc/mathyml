#import "prelude.typ"
#import "unicode.typ" as _unicode: convert_variants
#import "convert.typ"
#import "utils.typ" as _utils: is-html

/// Transform the content if `html`-export is active.
///
/// Returns the content as-is, if `html` is not active.
/// -> content
#let maybe-html(
  /// This function which will be called to transform the content.
  ///
  /// The first parameter of the function will be @maybe-html.inner, the other parameters are @maybe-html.args.
  /// -> function
  transform,
  /// The content to transform.
  /// -> content | any
  inner,
  /// Extra arguments to pass to @maybe-html.transform.
  /// -> arguments
  ..args
) = context {
  if is-html() {
    transform(inner, ..args)
  } else {
    inner
  }
}

#let html-framed(content, block: true, attrs: none, class: none, center: auto) = {
  let maybe-center = if block {
    if center == auto or center == true {
      "mathyml-block-center "
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
    default-class += "mathyml-inline-span "
    "span"
  }
  html.elem(elem, attrs: (class: default-class) + attrs, html.frame(content))
}

#let mathfonts() = html.elem("link", attrs: (rel: "stylesheet", href: "https://fred-wang.github.io/MathFonts/NewComputerModern/mathfonts.css"))

#let stylesheets(include-fonts: true) = context if is-html() {
  html.elem("style")[
  #```CSS
  .mathyml-block-center {
    text-align: center;
  }
  .mathyml-inline-span {
    /* font-size: 0pt; */
    display: inline-block;
  }
  .mathyml-align-right {
    text-align: right;
    padding-left: 0em;
    padding-right: 0em;
  }
  .mathyml-align-left {
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

/// Convert content to MathML.
///
/// -> content
#let to-mathml-raw(
  /// The equation/ content to convert.
  /// -> content | math.equation
  inner,
  /// Whether the equation is rendered as a separate block.
  /// 
  /// If `block` is auto, it will be inferred from the input.
  /// -> bool | auto
  block: auto,
  /// This callback will be called with every error.
  ///
  /// The function should take a single argument sink as parameter.
  /// If you overwrite this parameter, don't forget to overwrite @to-mathml-raw.is-error.
  /// `is-error` should return true if and only if `on-error` was called.
  ///
  /// For example you could return a custom dictionary on each error and check in `is-error` for that.
  /// -> function
  on-error: panic,
  /// This function will be called with every warning.
  /// 
  /// The function should take a single argument sink as parameter.
  /// If you overwrite this parameter, don't forget to overwrite @to-mathml-raw.is-error.
  /// In combination with `is-error`, you can `panic` on the warning, silence it or propagate it.
  /// -> function
  on-warn: (..args) => (),
  /// This callback will be called to determine if a result is an error.
  ///
  /// Errors will be propagated directly.
  /// -> function
  is-error: res => false,
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
  let converted = convert.convert-mathml(
    inner,
    on-error: on-error,
    on-warn: on-warn,
    is-error: is-error,
    size: if block { "display" } else { "text" },
  )
  if is-error(converted) {
    return converted
  }
  if block {
    return html.elem("math", attrs: (display: "block"), converted)
  } else {
    return html.elem("span", html.elem("math", converted))
  }
}


/// Try to convert the inner body to MathML, but fallback to a svg frame on error.
///
/// -> content
#let try-to-mathml(
  /// The equation/ content to convert.
  /// -> content | math.equation
  inner,
  /// Whether the equation is rendered as a separate block.
  /// 
  /// If `block` is auto, it will be inferred from the input.
  /// -> bool | auto
  block: auto,
  /// Whether to consider warnings as errors.
  /// -> bool
  strict: false,
) = {
  let on-error(..args) = (_utils._err-tag: true, pos: args.pos()) + args.named()
  let on-warn = if strict {
    on-error
  } else {
    (..args) => ()
  }
  let is-error(item) = type(item) == dictionary and _utils._err-tag in item
  let res = to-mathml-raw(
    inner,
    block: block,
    on-error: on-error,
    on-warn: on-warn,
    is-error: is-error,
  )
  if is-error(res) {
    // return repr(res) // FIXME fix all errors with this and `strict = true` above
    html-framed(inner)
  } else {
    res
  }
}

/// Convert the inner body to MathML and panic on error.
///
/// If you want to embed a svg-frame on error instead, use @try-to-mathml.
/// If you want to handle errors yourself, use @to-mathml-raw.
///
/// -> content
#let to-mathml(
  /// The equation/ content to convert.
  /// -> content | math.equation
  inner,
  /// Whether the equation is rendered as a separate block.
  /// 
  /// If `block` is auto, it will be inferred from the input.
  /// -> bool | auto
  block: auto,
) = {
  to-mathml-raw(inner, block: block)
}
