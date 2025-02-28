#import "unicode.typ": serif, sans, frak, mono, bb, cal
#import "utils.typ" as _utils

#let _sizes-inner(body, paged, size) = {
  import "convert.typ": convert-mathml
  import "utils.typ": is-html
  context if is-html() {
    convert-mathml(body, size: size)
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

/// Upright (non-italic) font style in math.
#let upright(
  /// The content to style.
  /// -> content
  body
) = metadata((_utils._type-ident: _utils._dict-types.upright, body: body))

/// Italic font style in math.
/// 
/// For roman letters and greek lowercase letters, this is already the default.
#let italic(
  /// The content to style.
  /// -> content
  body
) = metadata((_utils._type-ident: _utils._dict-types.italic, body: body))

/// Bold font style in math.
#let bold(
  /// The content to style.
  /// -> content
  body
) = metadata((_utils._type-ident: _utils._dict-types.bold, body: body))

#let dif = [#sym.space.thin #upright(symbol("d"))]
#let Dif = [#sym.space.thin #upright(symbol("D"))]
