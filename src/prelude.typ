#import "unicode.typ": serif, sans, frak, mono, bb, cal

#let _sizes-inner(body, paged, size) = {
  import "convert.typ": _to-mathml
  import "utils.typ": is-html
  context if is-html() {
    _to-mathml(body, ctx: (size: size))
  } else {
    paged(body)
  }
}

/// Forced display style in math.
///
/// This is the normal size for block equations.
#let display(
  /// The content to size
  /// -> content
  body
) = _sizes-inner(body, math.display, "display")

/// Forced inline (text) style in math.
///
/// This is the normal size for inline equations.
#let inline(
  /// The content to size
  /// -> content
  body
) = _sizes-inner(body, math.inline, "text")

/// Forced script style in math.
///
/// This is the smaller size used in powers or sub- or superscripts.
#let script(
  /// The content to size
  /// -> content
  body
) = _sizes-inner(body, math.script, "script")

/// Forced second script style in math.
///
/// This is the smallest size, used in second-level sub- and superscripts (script of the script).
/// Note that this currently is the same as `script` .
#let sscript(
  /// The content to size
  /// -> content
  body
) = _sizes-inner(body, math.sscript, "script-script")
