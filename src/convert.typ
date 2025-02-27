#import "utils.typ" as utils: types, convert-relative-len
#import "unicode.typ"

#let _has-limits(base, size) = {
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
      _has-limits(base.body, size)
    } else {
      // FIXME remove this panic
      panic("cannot determine limits for content elem of type `" + repr(func2) + "`: " + repr(base))
      false
    }
  } else {
    // FIXME remove this panic
    panic("cannot determine limits for elem of type `" + repr(type(base)) + "`: " + repr(base))
  }
}

// TODO
// wrong:
// - `math.stretch`
// - `lr` size (sometimes?)

/// ==== Unsupported
/// - `math.cancel`
/// - `math.styles`: upright, italic, bold
/// - labels
/// ==== Papercuts
/// - variants: `math.frak` (works with prelude but not automatically)
/// - sizes: `math.display`, `math.inline`, `math.script`, `math.sscript` (work with prelude but not automatically)
/// - `vec` and `mat` align and gap only work in firefox.
///
#let _to-mathml(
  inner,
  /// -> "script-script" | "script" | "text" | "display"
  size: "display",
  allow-multi-return: false, // FIXME: use this more
) = {
  let rec(inner, size: size, allow-multi-return: false) = {
    _to-mathml(inner, size: size, allow-multi-return: allow-multi-return)
  }
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
      // TODO remove this hack
      // group children until whitespace
      let children = ()
      let ungrouped = ()
      let convert-ungrouped(ungrouped) = {
        if ungrouped.len() == 1 {
          let f = ungrouped.first()
          // FIXME remove this hack
          if f.func() == html.elem and f.tag == "mtext" {
            let nbsp = sym.space.nobreak
            // TODO remove the space?
            f = elem("mtext", nbsp + f.body + nbsp)
          }
          f
        } else if ungrouped.len() > 1 {
          elem("mrow", ungrouped.join())
        }
      }
      for child in inner.children {
        if type(child) == content and child.func() == types.space {
          children.push(convert-ungrouped(ungrouped))
          ungrouped = ()
        } else {
          let r = rec(child, allow-multi-return: true)
          if type(r) == array {
            ungrouped += r
          } else {
            ungrouped.push(r)
          }
        }
      }
      // let children = inner.children.map(rec).join()
      if ungrouped.len() > 0 {
        children.push(convert-ungrouped(ungrouped))
      }
      if children.len() == 1 {
        return children.first() // FIXME is this ok?
      }
      if allow-multi-return {
        return children
      }
      elem("mrow", children.join())
    } else if func == text {
      let inner = inner.text
      // check if the text is a number
      if inner.match(regex("^\d+$")) != none {
        elem("mn", inner)
      } else {
        elem("mtext", inner)
      }
    } else if func == types.symbol {
      let inner = inner.text
      // encode letters as identifiers.
      // see <https://www.compart.com/en/unicode/category> and <https://docs.rs/regex/latest/regex/#syntax>
      if inner.match(regex("^(?:\p{Ll}|\p{Lu})+$")) != none {
        return elem("mi", inner)
      }
      // TODO is this correct?
      elem("mo", inner)
    } else if func == math.op {
      elem("mi", inner.text)
    } else if func == types.space {
      assert.eq(inner.fields(), (:)) // TODO remove
      elem("mspace", attrs: ("width": "0.5em"), inner)
    } else if func == types.styled {
      panic("styles are currently not supported. Use the functions from the prelude instead.", inner)
    } else if func == math.lr {
      if inner.has("size") {
        assert.eq(inner.size, 100%, 0pt) // TODO support different sizes
      }
      if type(inner.body) == content and inner.body.func() == types.sequence {
        let children = inner.body.children
        // remove the left and right delimiter
        let left = rec(children.remove(0))
        let right = rec(children.pop())
        let children = rec(children.join(), allow-multi-return: true)
        if allow-multi-return {
          if type(children) == array {
            return (left, ..children, right)
          }
          return (left, children, right)
        }
        if type(children) == array {
          children = children.join()
        }
        return elem("mrow")[
          #left
          #children
          #right
        ]
      }
      return rec(inner.body) // FIXME: is this correct?
    } else if func == math.frac {
      elem("mfrac")[
        #rec(inner.num)
        #rec(inner.denom)
      ]
    } else if func == math.root {
      if inner.has("index") {
        elem("mroot")[
          #rec(inner.radicand)
          #rec(inner.index, size: "script-script")
        ]
      } else {
        elem("msqrt", rec(inner.radicand))
      }
    } else if func == math.binom {
      let lower = inner.lower.map(v => rec(v)).join(elem("mo", ","))
      if inner.lower.len() > 1 {
        lower = elem("mrow", lower)
      }
      elem("mrow")[
        #elem("mo", "(")
        #elem("mfrac", attrs: (linethickness: "0"))[
          #rec(inner.upper)
          #lower
        ]
        #elem("mo", ")")
      ]
    } else if func == math.attach {
      let (tr, br, tl, bl, t, b) = ("tr", "br", "tl", "bl", "t", "b").map(name => inner.at(name, default: none))

      let base = inner.base
      while type(base) == content and base.func() == math.attach {
        base = base.base
      }
      let limits = _has-limits(base, size)
      let outer-size = size
      let size = if size == "display" or size == "text" {
        "script"
      } else {
        assert(("script", "script-script").contains(size))
        "script-script"
      }
      // no need to process `limits` and `scripts` below
      if type(base) == content {
        if base.func() == math.limits {
          base = base.body
          assert(limits)
        } else if base.func() == math.scripts {
          base = base.body
          assert(not limits)
        }
      }

      // see <https://github.com/typst/typst/blob/d6b0d68ffa4963459f52f7d774080f1f128841d4/crates/typst-layout/src/math/attach.rs#L46>
      let primed = type(base) == content and base.func() == math.primes
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
      let (b, br, bl, t, tr, tl) = (b, br, bl, t, tr, tl).map(v => {
        if v == none {
          none
        } else {
          rec(v, size: size)
        }
      })
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
      if outer-size == "display" {
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
    } else if func == math.vec { context {
      let attrs = (:)
      if inner.has("align") and inner.align != center {
        let a = inner.align
        attrs.insert("columnalign", if a == start or a == left {
          "left"
        } else if a == end or a == right {
          "right"
        } else {
          assert.eq(a, center)
        })
      }
      if inner.has("gap") and inner.gap != 0% + 0.2em {
        attrs.insert("rowspacing", convert-relative-len(inner.gap, inner))
      }
      let children = inner.children.map(v => elem("mtr", elem("mtd", rec(v))))
      let table = elem("mtable", attrs: attrs, children.join())
      let (left, right) = if not inner.has("delim") {
        ("(", ")")
      } else if inner.delim == none {
        ("(", ")")
      } else if type(inner.delim) == array {
        assert.eq(inner.delim.len(), 2)
        inner.delim
      } else {
        panic("invalid `delim` " + inner.delim  + " in `vec`", inner)
      }
      elem("mrow")[
        #elem("mo", left)
        #table
        #elem("mo", right)
      ]
    } } else if func == math.mat { context {
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
          assert(a == center or a == horizon)
        }
      }
      if inner.has("row-gap") and inner.row-gap != 0% + 0.2em {
        attrs.insert("rowspacing", convert-relative-len(inner.row-gap, inner))
      }
      if inner.has("column-gap") and inner.column-gap != 0% + 0.2em {
        attrs.insert("columnspacing", convert-relative-len(inner.column-gap, inner))
      }
      if inner.has("augment") {
        // TODO augment
        assert.eq(inner.augment, none)
      }

      let children = inner.rows.map(row =>
        elem("mtr", row.map(v =>
          elem("mtd", rec(v))
        ).join())
      )
      let table = elem("mtable", attrs: attrs, children.join())
      let (left, right) = if not inner.has("delim") {
        ("(", ")")
      } else if inner.delim == none {
        ("(", ")")
      } else if type(inner.delim) == array {
        assert.eq(inner.delim.len(), 2)
        inner.delim
      } else {
        panic("invalid `delim` " + inner.delim  + " in `vec`", inner)
      }
      elem("mrow")[
        #elem("mo", left)
        #table
        #elem("mo", right)
      ]
    } } else if func == math.cases { context {
      let attrs = (:)
      if inner.has("gap") and inner.gap != 0% + 0.2em {
        attrs.insert("rowspacing", convert-relative-len(inner.gap, inner))
      }
      let (left, right) = if not inner.has("delim") {
        ("(", ")")
      } else if inner.delim == none {
        ("(", ")")
      } else if type(inner.delim) == array {
        assert.eq(inner.delim.len(), 2)
        inner.delim
      } else {
        panic("invalid `delim` " + inner.delim  + " in `vec`", inner)
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
          panic("invalid `delim` " + inner.delim  + " in `vec`", inner)
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
          panic("invalid `delim` " + inner.delim  + " in `vec`", inner)
        }
        (elem("mo", delim), none)
      }

      let children = inner.children.map(v => elem("mtr", elem("mtd", rec(v))))
      let table = elem("mtable", attrs: attrs, children.join())

      elem("mrow")[
        #left
        #table
        #right
      ]
    } } else if (math.overline, math.overbrace, math.overbracket, math.overparen, math.overshell).contains(func) {
      let symb = if false { }
        else if func == math.overline { "¯" } // or "―"? TODO
        else if func == math.overbrace { "⏞" }
        else if func == math.overbracket { "⎴" }
        else if func == math.overparen { "⏜" }
        else if func == math.overshell { "⏠" }
        else { panic(inner) }
      let res = elem("mover", attrs: (accent: "true"))[ // TODO `accent` attribute?
        #rec(inner.body)
        #elem("mo", symb)
      ]
      if inner.has("annotation") and inner.annotation != none {
        elem("mover")[
          #res
          #rec(inner.annotation)
        ]
      } else {
        res
      }
    } else if (math.underline, math.underbrace, math.underbracket, math.underparen, math.undershell).contains(func) {
      let symb = if false { }
        else if func == math.underline { "_" }
        else if func == math.underbrace { "⏟" }
        else if func == math.underbracket { "⎵" }
        else if func == math.underparen { "⏝" }
        else if func == math.undershell { "⏡" }
        else { panic(inner) }
      let res = elem("munder", attrs: (accent: "true"))[ // TODO `accent` attribute?
        #rec(inner.body)
        #elem("mo", symb)
      ]
      if inner.has("annotation") and inner.annotation != none {
        elem("munder")[
          #res
          #rec(inner.annotation)
        ]
      } else {
        res
      }
    } else if func == math.accent {
      if inner.has("size") {
        assert.eq(inner.size, 100% + 0pt)
      }
      let base = rec(inner.base)
      // TODO improve this
      elem("mover", attrs: (accent: "true"))[
        #base
        #elem("mtext", inner.accent)
      ]
    } else if func == math.class {
      let class = inner.class
      // TODO convert `inner.body` in all cases with `rec`?
      let body = inner.body

      // FIXME is this ok?
      if type(body) == content and body.func() == text and body.text.len() > 1 {
        return elem("mi", body.text)
      }
      if type(body) == str and body.len() > 1 {
        return elem("mi", body)
      }
      if not (type(body) == content and body.func() == types.symbol
      ) {
        return elem("mi", rec(inner.body))
      }

      if class == "normal" or class == "vary" {
        rec(inner.body)
      } else if class == "punctuation" {
        elem("mo", attrs: (separator: "true"), body)
      } else if class == "opening" or class == "closing" or class == "fence" {
        elem("mo", attrs: (fence: "true"), body)
      } else if class == "large" {
        elem("mo", attrs: (largeop: "true"), body)
      } else if class == "relation" or class == "binary" {
        elem("mo", attrs: (form: "infix"), body)
      } else if class == "unary" {
        elem("mo", attrs: (form: "prefix"), body)
      } else {
        panic("invalid class `" + class + "` for `math.class`")
      }
    } else if func == math.primes {
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
    } else if func == math.stretch {
      // FIXME: is it ok to use `mo` for everything?
      let attrs = (stretchy: "true")
      if inner.has("size") and inner.size != 100% + 0pt {
        attrs.insert("minsize", convert-relative-len(inner.size, inner)) // FIXME: this is likely wrong
      }
      elem("mo", attrs: attrs, rec(inner.body))
    } else if func == types.counter-update {
      inner
    } else if func == types.context_ {
      inner // nothing we can do here
    } else {
      panic("unknown content element of type `" + repr(func) + "`: " + repr(inner))
    }
  } else {
    panic("unknown element of type `" + str(type(inner)) + "`: " + repr(inner))
  }
}

