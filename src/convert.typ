#import "utils.typ" as utils: types, convert-relative-len
#import "unicode.typ"

#let _err(ctx, ..args) = (ctx.handlers.on-error)(..args)
#let _warn(ctx, ..args) = (ctx.handlers.on-warn)(..args)
#let _is-err(ctx, inner) = (ctx.handlers.is-error)(inner)

#let _has-limits(ctx, base) = {
  let size = ctx.size
  if type(base) == content {
    let func2 = base.func()
    if func2 == math.limits {
      base = base.body
      true
    } else if func2 == math.scripts {
      base = base.body
      false
    } else if func2 == math.op {
      if base.has("limits") {
        base.limits
      } else {
        false
      }
    } else if func2 == math.class {
      let class = unicode._limits_for_class(base.class)
      if class == "always" { true }
        else if class == "display" { size == "display" }
        else { false }
    } else if func2 == types.symbol {
      let class = unicode._limits-for-char(base.text)
      if class == "always" { true }
        else if class == "display" { size == "display" }
        else { false }
    } else if func2 == math.lr {
      false
    } else if func2 == math.stretch {
      _has-limits(ctx, base.body)
    } else if func2 == metadata {
      if type(base.value) == dictionary and utils._type-ident in base.value {
        return _has-limits(ctx, base.value.body)
      }
      _has-limits(ctx, base.value)
    } else {
      let x = _warn(ctx, "cannot determine limits for content elem of type `" + repr(func2) + "`: " + repr(base))
      if _is-err(ctx, x) { return x }
      false
    }
  } else if type(base) == symbol {
    _has-limits(ctx, [#base])
  } else {
    return _err(ctx, "cannot determine limits for elem of type `" + repr(type(base)) + "`: " + repr(base))
  }
}

#let _convert-sequence-multiline(ctx, rec-seq, rec, inner) = {
  let elem = html.elem
  let rows = ()
  let elems = ()
  for child in inner.children {
    if type(child) == content and child.func() == linebreak {
      rows.push(elems)
      elems = ()
    } else {
      elems.push(child)
    }
  }
  if elems.len() > 0 {
    rows.push(elems)
  }
  let converted = ()
  for row in rows {
    let r = rec-seq(ctx, rec, row.join())
    if _is-err(ctx, r) { return r }
    converted.push(elem("mtr", elem("mtd", r)))
  }
  elem("mtable", converted.join())
}

#let _convert-sequence(ctx, rec, inner) = {
  let elem = html.elem
  // create a table for multiple lines
  for child in inner.children {
    if type(child) == content and child.func() == linebreak {
      return _convert-sequence-multiline(ctx, _convert-sequence, rec, inner)
    }
  }
  // group children until whitespace
  let children = ()
  let ungrouped = ()
  let convert-ungrouped(ungrouped) = {
    if ungrouped.len() == 1 {
      ungrouped.first()
    } else if ungrouped.len() > 1 {
      elem("mrow", ungrouped.join())
    }
  }
  let after-space = false
  for (i, child) in inner.children.enumerate() {
    if type(child) == content and child.func() == types.space {
      children.push(convert-ungrouped(ungrouped))
      ungrouped = ()
    } else if type(child) == content and child.func() == math.lr {
      children.push(convert-ungrouped(ungrouped))
      let r = rec(child)
      if _is-err(ctx, r) { return r }
      children.push(r)
      ungrouped = ()
    } else {
      let inner-ctx = ctx
      inner-ctx.allow-multi-return = true
      let next = inner.children.at(i + 1, default: none)
      if next != none and unicode._is-space(next) {
        inner-ctx.context_.before-space = true
      }
      inner-ctx.context_.after-space = after-space
      let r = rec(child, ctx: inner-ctx)
      if _is-err(ctx, r) { return r }
      if type(r) == array {
        ungrouped += r
      } else {
        ungrouped.push(r)
      }
    }
    after-space = unicode._is-space(child)
  }
  if ungrouped.len() > 0 {
    children.push(convert-ungrouped(ungrouped))
  }
  if children.len() == 1 {
    return children.first() // FIXME is this ok?
  }
  if ctx.allow-multi-return {
    return children
  }
  elem("mrow", children.join())
}

#let _apply-style(
  ctx,
  /// -> str
  text,
  /// symbols should set this to true
  /// -> bool
  auto-italic: false
) = {
  if text.len() == 0 {
    return text
  }
  text.codepoints().map(c => unicode._styled-char(
    c,
    auto-italic: auto-italic,
    bold: ctx.styles.bold,
    italic: ctx.styles.upright-or-italic == "italic",
    variant: ctx.styles.variant,
  )).join()
}

#let _convert-text(ctx, rec, inner) = {
  let unstyled = inner
  if type(inner) != str {
    unstyled = inner.text
  }
  let styled = _apply-style(ctx, unstyled)
  // check if the text is a number
  if unstyled.match(regex("^\d+$")) != none {
    html.elem("mn", styled)
  } else {
    let nbsp = sym.space.nobreak
    if ctx.context_.after-space {
      styled = nbsp + styled
    }
    if ctx.context_.before-space {
      styled = styled + nbsp
    }
    html.elem("mtext", styled)
  }
}

#let _create-mi(ctx, text) = {
  if type(text) != str {
    return _err(ctx, "unreachable", text, type(text))
  }
  let styled = _apply-style(ctx, text)
  if ctx.styles.upright-or-italic == "upright" {
    html.elem("mi", attrs: (mathvariant: "normal"), styled)
  } else{
    html.elem("mi", styled)
  }
}

#let _attrs-for-class(ctx, class) = {
  if class == none or class == "normal" or class == "vary" {
    (:)
  } else if class == "punctuation" {
    (separator: "true")
  } else if class == "opening" or class == "closing" or class == "fence" {
    (fence: "true")
  } else if class == "large" {
    (largeop: "true")
  } else if class == "relation" or class == "binary" {
    (form: "infix")
  } else if class == "unary" {
    (form: "prefix")
  } else {
    return _err(ctx, "invalid class `" + class + "` for `math.class`")
  }
}

#let _convert-symbol(ctx, rec, outer, class: none) = {
  let elem = html.elem
  let inner = outer.text
  let attrs = _attrs-for-class(ctx, class)
  if _is-err(ctx, attrs) { return attrs }

  let maybe_mi(ctx, inner) = {
    if class == none {
      _create-mi(ctx, inner)
    } else {
      let styled = _apply-style(ctx, inner)
      if attrs == none or attrs.len() == 0 {
        html.elem("mo", styled)
      } else {
        html.elem("mo", attrs: attrs, styled)
      }
    }
  }
  // encode letters as identifiers.
  // see <https://www.compart.com/en/unicode/category> and <https://docs.rs/regex/latest/regex/#syntax>
  if inner.match(regex("^(?:\p{Ll}|\p{Lu})+$")) != none {
    // `mi` should sometimes not be italic: "For roman letters and greek lowercase letters, [italic] is already the default."
    if inner.match(regex("[a-zA-Zα-ω]")) != none {
      if ctx.styles.upright-or-italic == auto {
        ctx.styles.upright-or-italic = "italic"
      }
      return maybe_mi(ctx, inner)
    } else {
      if ctx.styles.upright-or-italic == auto {
        ctx.styles.upright-or-italic = "upright"
      }
      return maybe_mi(ctx, inner)
    }
  }
  if unicode._is-space(inner) {
    return elem("mtext", inner)
  }

  if attrs == none or attrs.len() == 0 {
    html.elem("mo", inner)
  } else {
    html.elem("mo", attrs: attrs, inner)
  }
}

#let _convert-op(ctx, rec, outer) = {
  let inner = outer.text
  ctx.styles.upright-or-italic = "upright"
  if type(inner) == content {
    let func = inner.func()
    if func == types.symbol {
      _create-mi(ctx, inner.text)
    } else if func == text {
      _create-mi(ctx, inner.text)
    } else {
      return _err(ctx, "invalid content element of type `" + repr(func) + "`: " + repr(inner))
    }
  } else if type(inner) == str {
    _create-mi(ctx, inner)
  } else if type(inner) == symbol {
    _convert-op(ctx, rec, [#inner])
  } else {
    return _err(ctx, "invalid element of type `" + type(inner) + "`: " + repr(inner))
  }
}

#let _convert-h-space(ctx, rec, inner) = {
  if inner.has("weak") and inner.weak {
    let x = _warn(ctx, "`h.weak` is ignored")
    if _is-err(ctx, x) { return x }
  }
  if type(inner.amount) == fraction {
    return _err(ctx, "fraction amounts are unsupported")
  }
  let width = convert-relative-len(inner.amount, inner)
  html.elem("mspace", attrs: ("width": width))
}

#let _convert-lr(ctx, rec, inner) = {
  if type(inner.body) == content and inner.body.func() == types.sequence {
    let children = inner.body.children
    if children.len() == 0 {
      return none
    }
    if children.len() == 1 {
      if inner.has("size") {
        if inner.size != 100% + 0pt { // FIXME support different sizes
          return _err(ctx, "lr does not support custom sizes. Got size", inner.size, "for elem", inner)
        }
      }
    }
    // remove the left and right delimiter
    let left = rec(children.remove(0))
    let right = rec(children.pop())
    let children = if children.len() > 0 {
      // FIXME: set this to `true` to scale mid correctly
      //        set this to `false` to scale the delims correctly...
      rec(children.join(), allow-multi-return: false)
    } else {
      children
    }

    if _is-err(ctx, left) { return left }
    if _is-err(ctx, right) { return right }
    if _is-err(ctx, children) { return children }

    if inner.has("size") {
      if inner.size != 100% + 0pt { // FIXME support different sizes
        return _err(ctx, "lr does not support custom sizes. Got size", inner.size, "for elem", inner)
      }
    }

    if ctx.allow-multi-return {
      if type(children) == array {
        return (left, ..children, right)
      }
      return (left, children, right)
    }
    if type(children) == array {
      children = children.join()
    }
    return html.elem("mrow")[
      #left
      #children
      #right
    ]
  }
  return rec(inner.body) // FIXME: is this correct?
}

#let _convert-mid(ctx, rec, inner) = {
  let body = rec(inner.body)
  if _is-err(ctx, body) { return body }
  if type(body) == content and body.func() == html.elem and body.tag == "mo" {
    html.elem("mo", attrs: (fence: "true", form: "infix", stretchy: "true"), body.body)
  } else {
    // FIXME: support more
    return _err(ctx, "can't scale mid", body)
  }
}

#let _convert-frac(ctx, rec, inner) = {
  let num = rec(inner.num)
  let denom = rec(inner.denom)
  if _is-err(ctx, num) { return num }
  if _is-err(ctx, denom) { return denom }
  html.elem("mfrac")[#num #denom]
}

#let _convert-root(ctx, rec, inner) = {
  if inner.has("index") {
    let radicand = rec(inner.radicand)
    if _is-err(ctx, radicand) { return radicand }
    if inner.index == none {
      return html.elem("msqrt", radicand)
    }
    let index = rec(inner.index, size: "script-script")
    if _is-err(ctx, index) { return index }
    html.elem("mroot")[#radicand #index]
  } else {
    let radicand = rec(inner.radicand)
    if _is-err(ctx, radicand) { return radicand }
    html.elem("msqrt", radicand)
  }
}

#let _convert-binom(ctx, rec, inner) = {
  let elem = html.elem
  let upper = rec(inner.upper)
  if _is-err(ctx, upper) { return upper }
  let lower = ()
  for v in inner.lower {
    let x = rec(v)
    if _is-err(ctx, x) { return x }
    lower.push(x)
  }
  let lower = lower.join(elem("mo", ","))
  if inner.lower.len() > 1 {
    lower = elem("mrow", lower)
  }
  elem("mrow")[
    #elem("mo", "(")
    #elem("mfrac", attrs: (linethickness: "0"))[
      #upper
      #lower
    ]
    #elem("mo", ")")
  ]
}

#let _convert-attach(ctx, rec, inner) = {
  let elem = html.elem
  let attachments = ("tr", "br", "tl", "bl", "t", "b").map(name => (name, inner.at(name, default: none))).to-dict()

  let base = inner.base
  while type(base) == content and base.func() == math.attach {
    let attachments-before = attachments
    let do-break = false
    for key in ("tr", "br", "tl", "bl", "t", "b") {
      let new = base.at(key, default: none)
      if new != none {
        if attachments.at(key) != none {
          do-break = true
          break
        }
        attachments.insert(key, new)
      }
    }
    if do-break {
      attachments = attachments-before
      break
    }
    base = base.base
  }
  let (tr, br, tl, bl, t, b) = attachments

  let limits = _has-limits(ctx, base)
  if _is-err(ctx, limits) { return limits }
  let size = if ctx.size == "display" or ctx.size == "text" {
    "script"
  } else if ctx.size == "script" or ctx.size == "script-script" {
    "script-script"
  } else {
    return _err(ctx, "invalid size", ctx.size)
  }
  // no need to process `limits` and `scripts` below
  if type(base) == content {
    if base.func() == math.limits {
      base = base.body
      if not limits {
        return _err(ctx, "expected to have limits for `limits`")
      }
      assert(limits)
    } else if base.func() == math.scripts {
      base = base.body
      if limits {
        return _err(ctx, "expected to not have limits for `scripts`")
      }
    }
  }

  // see <https://github.com/typst/typst/blob/d6b0d68ffa4963459f52f7d774080f1f128841d4/crates/typst-layout/src/math/attach.rs#L46>
  let primed = tr != none and type(tr) == content and tr.func() == math.primes
  let (t, tr) = if t != none and tr != none and primed and not limits {
    (none, tr + t)
  } else if t != none and tr == none and not limits {
    (none, t)
  } else {
    (t, tr)
  }
  let (b, br) = if limits or br != none {
    (b, br)
  } else {
    (none, b)
  }

  let base = rec(base)
  if _is-err(ctx, base) { return base }
  let (b, br, bl, t, tr, tl) = {
    let x = ()
    for v in (b, br, bl, t, tr, tl) {
      x.push(if v == none {
        none
      } else {
        let r = rec(v, size: size)
        if _is-err(ctx, r) {
          return r
        }
        r
      })
    }
    x
  }
  let base = if tl == none and bl == none { // only right
    if br != none and tr != none {
      elem("msubsup")[#base #br #tr]
    } else if br != none {
      elem("msub")[#base #br]
    } else if tr != none {
      elem("msup")[#base #tr]
    } else {
      base
    }
  } else { // with left
    let maybe(it) = if it != none {
      it
    } else {
      elem("mrow")
    }
    elem("mmultiscripts")[
      #base
      #if tr != none or br != none {
        maybe(br)
        maybe(tr)
      }
      #elem("mprescripts")
      #maybe(bl)
      #maybe(tl)
    ]
  }
  let attrs = (:)
  if ctx.size == "display" {
    // FIXME is this correct?
    attrs.insert("displaystyle", "true")
  } else {
    attrs.insert("displaystyle", "false")
  }
  if t != none and b != none {
    elem("munderover", attrs: attrs)[
      #base
      #b
      #t
    ]
  } else if t != none {
    elem("mover", attrs: attrs)[
      #base
      #t
    ]
  } else if b != none {
    // FIXME add `accent`?
    // elem("munder", attrs: (accent: "true"))[
    elem("munder", attrs: attrs)[
      #base
      #b
    ]
  } else {
    base
  }
}

#let _convert-vec(ctx, rec, inner) = {
  let elem = html.elem
  let attrs = (:)
  if inner.has("align") and inner.align != center {
    let a = inner.align
    attrs.insert("columnalign", if a == start or a == left {
      "left"
    } else if a == end or a == right {
      "right"
    } else {
      if a != center {
        return _err(ctx, "invalid align", a, "in", inner)
      }
    })
  }
  if inner.has("gap") and inner.gap != 0% + 0.2em {
    attrs.insert("rowspacing", convert-relative-len(inner.gap, inner))
  }
  let children = ()
  for v in inner.children {
    let r = rec(v)
    if _is-err(ctx, r) { return r }
    children.push(elem("mtr", elem("mtd", r)))
  }
  let table = elem("mtable", attrs: attrs, children.join())
  let (left, right) = if not inner.has("delim") {
    ("(", ")")
  } else if inner.delim == none {
    ("(", ")")
  } else if type(inner.delim) == array {
    assert.eq(inner.delim.len(), 2)
    inner.delim
  } else {
    return _err(ctx, "invalid `delim` " + inner.delim  + " in `vec`", inner)
  }
  elem("mrow")[
    #elem("mo", left)
    #table
    #elem("mo", right)
  ]
}

#let _convert-mat(ctx, rec, inner) = {
  let elem = html.elem
  let attrs = (:)
  if inner.has("align") and inner.align != center {
    let a = inner.align
    if a == start or a == left {
      attrs.insert("columnalign", "left")
    } else if a == end or a == right {
      attrs.insert("columnalign", "left")
    } else if a == top {
      attrs.insert("rowalign", "top")
    } else if a == bottom {
      attrs.insert("rowalign", "bottom")
    } else {
      if a != center and a != horizon {
        return _err(ctx, "invalid align", a, "in", inner)
      }
    }
  }
  if inner.has("row-gap") and inner.row-gap != 0% + 0.2em {
    attrs.insert("rowspacing", convert-relative-len(inner.row-gap, inner))
  }
  if inner.has("column-gap") and inner.column-gap != 0% + 0.2em {
    attrs.insert("columnspacing", convert-relative-len(inner.column-gap, inner))
  }
  let nrows = inner.rows.len()
  let ncols = if inner.rows.len() > 0 {
    inner.rows.first().len()
  } else {
    0
  }
  // draw a horizontal line after row?
  let hlines = ()
  // draw a vertical line after column?
  let vlines = ()
  let stroke-thickness = 0.05em
  if inner.has("augment") {
    if inner.augment != none {
      let aug = inner.augment
      if type(aug) == int {
        if aug < 0 {
          aug = ncols + aug
        }
        if aug == 0 {
          return _err(ctx, "cannot draw a vertical line after column 0", inner)
        }
        if aug >= ncols {
          return _err(ctx, "cannot draw a vertical line after column " + str(aug) + " of a matrix with " + str(ncols) + " columns", inner)
        }
        vlines.push(aug - 1)
      } else if type(aug) == dictionary {
        if "stroke" in aug {
          // FIXME support more from stroke
          if aug.stroke != auto and aug.stroke.thickness != auto {
            stroke-thickness = aug.stroke.thickness
          }
        }
        if "vline" in aug {
          let vline = if type(aug.vline) != array {
            (aug.vline,)
          } else {
            aug.vline
          }
          for aug in vline {
            if aug < 0 {
              aug = ncols + aug
            }
            if aug <= 0 {
              return _err(ctx, "cannot draw a vertical line after column " + str(aug), inner)
            }
            if aug >= ncols {
              return _err(ctx, "cannot draw a vertical line after column " + str(aug) + " of a matrix with " + str(ncols) + " columns", inner)
            }
            vlines.push(aug - 1)
          }
        }
        if "hline" in aug {
          let hline = if type(aug.hline) != array {
            (aug.hline,)
          } else {
            aug.hline
          }
          for aug in hline {
            if aug < 0 {
              aug = nrows + aug
            }
            if aug <= 0 {
              return _err(ctx, "cannot draw a horizontal line after row " + str(aug), inner)
            }
            if aug >= nrows {
              return _err(ctx, "cannot draw a horizontal line after row " + str(aug) + " of a matrix with " + str(nrows) + " rows", inner)
            }
            hlines.push(aug - 1)
          }
        }
      } else {
        return _err(ctx, "expected either a int or a dictionary for augment but got", aug, inner)
      }
    }
  }
  let stroke-thickness = convert-relative-len(stroke-thickness, inner)
  let stroke_ = stroke-thickness + " solid"

  let children = ()
  for (y, row) in inner.rows.enumerate() {
    let res = ()
    for (x, v) in row.enumerate() {
      let r = rec(v)
      if _is-err(ctx, r) { return r }
      let e = if x not in vlines and y not in hlines {
        elem("mtd", r)
      } else {
        let style = ""
        if x in vlines {
          style += "border-right:" + stroke_ + ";"
        }
        if y in hlines {
          style += "border-bottom:" + stroke_ + ";"
        }
        elem("mtd", attrs: (style: style.trim()), r)
      }
      res.push(e)
    }
    children.push(elem("mtr", res.join()))
  }
  let table = elem("mtable", attrs: attrs, children.join())
  let (left, right) = if not inner.has("delim") {
    ("(", ")")
  } else if inner.delim == none {
    ("(", ")")
  } else if type(inner.delim) == array {
    if inner.delim.len() != 2 {
      return _err(ctx, "expected delim of length 2 but got", inner.delim, "in", inner)
    }
    inner.delim
  } else {
    return _err(ctx, "invalid `delim` " + inner.delim  + " in `vec`", inner)
  }
  elem("mrow")[
    #elem("mo", left)
    #table
    #elem("mo", right)
  ]
}

#let _convert-cases(ctx, rec, inner) = {
  let elem = html.elem
  let attrs = (:)
  if inner.has("gap") and inner.gap != 0% + 0.2em {
    attrs.insert("rowspacing", convert-relative-len(inner.gap, inner))
  }

  let (left, right) = if inner.has("reverse") and inner.reverse {
    attrs.insert("columnalign", "right")
    let delim = if not inner.has("delim") {
      "}"
    } else if inner.delim == none {
      "}"
    } else if type(inner.delim) == array {
      assert.eq(inner.delim.len(), 2)
      inner.delim.last()
    } else {
      return _err(ctx, "invalid `delim` " + inner.delim  + " in `vec`", inner)
    }
    (none, elem("mo", delim))
  } else {
    attrs.insert("columnalign", "left")
    let delim = if not inner.has("delim") {
      "{"
    } else if inner.delim == none {
      "{"
    } else if type(inner.delim) == array {
      assert.eq(inner.delim.len(), 2)
      inner.delim.first()
    } else {
      return _err(ctx, "invalid `delim` " + inner.delim  + " in `vec`", inner)
    }
    (elem("mo", delim), none)
  }

  for child in inner.children {
    if type(child) == content and child.func() == types.sequence {
      for elem in child.children {
        // FIXME allow linebreak aswell?
        if elem.func() == types.align-point {
          let inner = inner.children.join(linebreak())
          let table = (ctx.rec._convert-alignments)(ctx, rec, inner, attrs: attrs)
          if _is-err(ctx, table) { return table }
          return html.elem("mrow")[
            #left
            #table
            #right
          ]
        }
      }
    }
  }

  let children = ()
  for v in inner.children {
    let r = rec(v)
    if _is-err(ctx, r) { return r }
    children.push(elem("mtr", elem("mtd", r)))
  }
  let table = elem("mtable", attrs: attrs, children.join())

  elem("mrow")[
    #left
    #table
    #right
  ]
}

#let _convert-overset(ctx, rec, inner) = {
  let elem = html.elem
  let func = inner.func()
  let symb = if func == math.overline { "¯" } // or "―"?
    else if func == math.overbrace { "⏞" }
    else if func == math.overbracket { "⎴" }
    else if func == math.overparen { "⏜" }
    else if func == math.overshell { "⏠" }
    else { return _err(ctx, "unreachable", inner) }
  let body = rec(inner.body)
  if _is-err(ctx, body) { return body }
  let res = elem("mover", attrs: (accent: "true"))[ // FIXME `accent` attribute?
    #body
    #elem("mo", symb)
  ]
  if inner.has("annotation") and inner.annotation != none {
    let annotation = rec(inner.annotation)
    if _is-err(ctx, annotation) { return annotation }
    elem("mover")[#res #annotation]
  } else {
    res
  }
}

#let _convert-underset(ctx, rec, inner) = {
  let elem = html.elem
  let func = inner.func()
  let symb = if func == math.underline { "_" }
    else if func == math.underbrace { "⏟" }
    else if func == math.underbracket { "⎵" }
    else if func == math.underparen { "⏝" }
    else if func == math.undershell { "⏡" }
    else { return _err(ctx, "unreachable", inner) }
  let body = rec(inner.body)
  if _is-err(ctx, body) { return body }
  let res = elem("munder", attrs: (accent: "true"))[ // FIXME `accent` attribute?
    #body
    #elem("mo", symb)
  ]
  if inner.has("annotation") and inner.annotation != none {
    let annotation = rec(inner.annotation)
    if _is-err(ctx, annotation) { return annotation }
    elem("munder")[#res #annotation]
  } else {
    res
  }
}

#let _convert-accent(ctx, rec, inner) = {
  let attrs = (:)
  if inner.has("size") {
    if inner.size != 100% + 0pt { // FIXME support different sizes
      return _err(ctx, "size is currently unsupported")
      // this does not work
      attrs.insert("minsize", convert-relative-len(inner.size, inner))
    }
  }
  let base = rec(inner.base)
  if _is-err(ctx, base) { return base }
  // FIXME improve this
  html.elem("mover", attrs: (accent: "true"))[
    #base
    #html.elem("mo", attrs: (stretchy: "true") + attrs, inner.accent)
  ]
}

#let _convert-class(ctx, rec, inner) = {
  let elem = html.elem
  let class = inner.class
  let body = inner.body

  // FIXME is this ok?
  if type(body) == content and body.func() == text and body.text.len() > 1 {
    return _create-mi(ctx, body.text)
  }
  if type(body) == str and body.len() > 1 {
    return _create-mi(ctx, body)
  }
  if not (type(body) == content and body.func() == types.symbol) {
    let body = rec(body)
    if _is-err(ctx, body) { return body }
    return elem("mi", body)
  }

  _convert-symbol(ctx, rec, body, class: class)
}

#let _convert-primes(ctx, rec, inner) = {
  let elem = html.elem
  let c = inner.count
  if c == 0 {
    none
  } else if c < 4 {
    let body = ("′", "″", "‴", "⁗").at(c - 1)
    elem("mo", attrs: (lspace: "0em", rspace: "0em", style: "padding-left: 0.08em"), body)
  } else {
    elem("mrow", attrs: (lspace: "0em", rspace: "0em", style: "padding-left: 0.08em"), {
      for _ in range(c) {
        elem("mo", attrs: (lspace: "0em", rspace: "0em"), "′")
      }
    })
  }
}

#let _convert-stretch(ctx, rec, inner) = {
  let attrs = (stretchy: "true")
  if inner.has("size") and inner.size != 100% + 0pt {
    attrs.insert("minsize", convert-relative-len(inner.size, inner))
  }
  let body = rec(inner.body)
  if _is-err(ctx, body) { return body }
  if type(body) == content and body.func() == html.elem and body.tag == "mo" {
    html.elem("mo", attrs: attrs, body.body)
  } else {
    // FIXME: support more
    return _err(ctx, "can't stretch", body)
  }
}

#let _convert-custom-type(ctx, rec, inner) = {
  let ty = inner.at(utils._type-ident)
  if ty == utils._dict-types.upright {
    ctx.styles.upright-or-italic = "upright"
    rec(inner.body, ctx: ctx)
  } else if ty == utils._dict-types.italic {
    ctx.styles.upright-or-italic = "italic"
    rec(inner.body, ctx: ctx)
  } else if ty == utils._dict-types.bold {
    ctx.styles.bold = true
    rec(inner.body, ctx: ctx)
  } else if ty == utils._dict-types.variant {
    ctx.styles.variant = inner.variant
    rec(inner.body, ctx: ctx)
  } else {
    return _err(ctx, "unknown custom element `" + ty + "`: " + repr(inner))
  }
}

#let _create-rec(outer-ctx) = {
  let rec(inner, allow-multi-return: false, ctx: none, ..args) = {
    assert.eq(args.pos(), ())
    if ctx == none {
      (outer-ctx.rec._to-mathml)(inner, outer-ctx + args.named() + (allow-multi-return: allow-multi-return))
    } else {
      assert.eq(args.named(), (:))
      (outer-ctx.rec._to-mathml)(inner, ctx + (allow-multi-return: allow-multi-return))
    }
  }
  return rec
}

/// ==== Unsupported
/// - `math.cancel`
/// - nested alignment
/// - labels
///
/// ==== Only available via prelude
/// - variants: serif, sans, frak, mono, bb, cal
/// - `math.styles`: upright, italic, bold
/// - sizes: display, inline, script, sscript
///
/// ==== Papercuts
/// - `vec` and `mat` align and gap only work in firefox.
/// - `math.stretch`: only supports `op`s.
#let _to-mathml(inner, ctx) = {
  let rec = _create-rec(ctx)
  let elem = html.elem
  if type(inner) == array {
    if inner.len() == 1 {
      inner = inner.first()
    }
  }
  if type(inner) == content {
    let func = inner.func()
    if func == math.equation {
      rec(inner.body)
    } else if func == html.elem {
      return inner // nothing to do
    } else if func == types.sequence {
      _convert-sequence(ctx, rec, inner)
    } else if func == text {
      _convert-text(ctx, rec, inner)
    } else if func == types.symbol {
      _convert-symbol(ctx, rec, inner)
    } else if func == math.op {
      _convert-op(ctx, rec, inner)
    } else if func == types.space {
      return none // FIXME is that ok?
      elem("mspace", attrs: ("width": "0.5em"), inner)
    } else if func == h {
      _convert-h-space(ctx, rec, inner)
    } else if func == types.styled {
      return _err(ctx, "styles are currently not supported. Use the functions from the prelude instead.", inner)
    } else if func == math.lr {
      _convert-lr(ctx, rec, inner)
    } else if func == math.mid {
      _convert-mid(ctx, rec, inner)
    } else if func == math.frac {
      _convert-frac(ctx, rec, inner)
    } else if func == math.root {
      _convert-root(ctx, rec, inner)
    } else if func == math.binom {
      _convert-binom(ctx, rec, inner)
    } else if func == math.attach {
      _convert-attach(ctx, rec, inner)
    } else if func == math.vec { context {
      _convert-vec(ctx, rec, inner)
    } } else if func == math.mat { context {
      _convert-mat(ctx, rec, inner)
    } } else if func == math.cases { context {
      _convert-cases(ctx, rec, inner)
    } } else if (math.overline, math.overbrace, math.overbracket, math.overparen, math.overshell).contains(func) {
      _convert-overset(ctx, rec, inner)
    } else if (math.underline, math.underbrace, math.underbracket, math.underparen, math.undershell).contains(func) {
      _convert-underset(ctx, rec, inner)
    } else if func == math.accent {
      _convert-accent(ctx, rec, inner)
    } else if func == math.class {
      _convert-class(ctx, rec, inner)
    } else if func == math.primes {
      _convert-primes(ctx, rec, inner)
    } else if func == math.stretch {
      _convert-stretch(ctx, rec, inner)
    } else if func == types.counter-update {
      inner
    } else if func == types.context_ {
      inner // nothing we can do here
    } else if func == metadata {
      if type(inner.value) == dictionary and utils._type-ident in inner.value {
        return _convert-custom-type(ctx, rec, inner.value)
      }
      inner
    } else if func == types.align-point {
      return _err(ctx, "only top-level alignment points are implemented")
    } else if func == linebreak {
      return _err(ctx, "only top-level linebreaks are implemented")
    } else if func == math.limits {
      let x = _warn(ctx, "limits should be handled in attach", inner)
      if _is-err(ctx, x) { return x }
      _to-mathml(inner.body, ctx)
    } else if func == raw {
      // FIXME: improve this?
      _convert-text(ctx, rec, inner.text)
    } else {
      return _err(ctx, "unknown content element of type `" + repr(func) + "`: " + repr(inner))
    }
  } else if type(inner) == str {
    _convert-text(ctx, rec, inner)
  } else if type(inner) == symbol {
    _convert-symbol(ctx, rec, [#inner])
  } else {
    return _err(ctx, "unknown element of type `" + str(type(inner)) + "`: " + repr(inner))
  }
}

#let _convert-alignments(ctx, rec, inner, attrs: (:)) = {
  let elem = html.elem

  let rows = ()
  let columns = ()
  let elems = ()
  for (i, child) in inner.children.enumerate() {
    if type(child) == content {
      let func = child.func()
      if func == types.align-point {
        columns.push(elems.join())
        elems = ()
        continue
      }
      if func == linebreak {
        if elems.len() != 0 {
          columns.push(elems.join())
          elems = ()
        }
        rows.push(columns)
        columns = ()
        continue
      }
    }
    let inner-ctx = ctx
    let prev = inner.children.at(i - 1, default: none)
    if prev != none and unicode._is-space(prev) {
      inner-ctx.context_.after-space = true
    }
    let next = inner.children.at(i + 1, default: none)
    if next != none and unicode._is-space(next) {
      inner-ctx.context_.before-space = true
    }
    let r = rec(child, ctx: inner-ctx)
    if _is-err(ctx, r) { return r }
    elems.push(r)
  }
  if elems.len() != 0 {
    columns.push(elems.join())
  }
  rows.push(columns)

  elem(
    "mtable",
    attrs: attrs,
    rows.map(row => {
      elem("mtr", row.enumerate().map(((i, v)) => {
        let class = if calc.rem(i, 2) == 0 {
          "typstmathml-align-right"
        } else {
          "typstmathml-align-left"
        }
        elem("mtd", attrs: (class: class), v)
      }).join())
    }).join()
  )
}

#let _convert-maybe-aligned(inner, ctx) = {
  if type(inner) == content {
    if inner.func() == types.sequence {
      for child in inner.children {
        if type(child) == content {
          if child.func() == types.align-point or child.func() == linebreak {
            let rec = _create-rec(ctx)
            return _convert-alignments(ctx, rec, inner)
          }
        }
      }
    }
  }
  _to-mathml(inner, ctx)
}


#let convert-mathml(
  /// -> content
  body,
  /// -> "script-script" | "script" | "text" | "display"
  size: "display",
  /// -> bool
  allow-multi-return: false, // FIXME: use this more
  /// -> function
  on-error: panic,
  /// -> function
  on-warn: (..args) => (),
  /// -> function
  is-error: res => false,
) = {
  let ctx = (
    size: size,
    allow-multi-return: allow-multi-return,
    handlers: (
      on-error: on-error,
      on-warn: on-warn,
      is-error: is-error
    ),
    context_: (
      before-space: false,
      after-space: false,
    ),
    styles: (
      upright-or-italic: auto,
      bold: false,
      variant: "serif",
    ),
    rec: (
      _to-mathml: _to-mathml,
      _convert-alignments: _convert-alignments,
    ),
  )
  _convert-maybe-aligned(body, ctx)
}
