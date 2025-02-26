#import "utils.typ": types, convert-relative-len

// TODO
// wrong:
// - `attach` for sum etc
// - `math.stretch`
// unsupported:
// - `math.cancel`
// - `math.limits`
// - `math.scripts`
// - sizes: `math.display`, `math.inline`, `math.script`, `math.sscript`
// - `math.styles`: upright, italic, bold
// - variants: `math.frak` etc.
// - labels
#let _to-mathml(
  inner,
) = {
  let elem = html.elem
  if type(inner) == array {
    if inner.len() == 1 {
      inner = inner.first()
    }
  }
  if type(inner) == content {
    let func = inner.func()
    if func == math.equation {
      _to-mathml(inner.body)
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
          ungrouped.push(_to-mathml(child))
        }
      }
      // let children = inner.children.map(_to-mathml).join()
      if ungrouped.len() > 0 {
        children.push(convert-ungrouped(ungrouped))
      }
      if children.len() == 1 {
        return children.first() // FIXME is this ok?
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
      if inner.has("limits") and inner.limits {
        panic("`limits` for `math.op` are not supported yet", inner)
      }
      elem("mi", inner.text)
    } else if func == types.space {
      assert.eq(inner.fields(), (:)) // TODO remove
      elem("mspace", attrs: ("width": "0.5em"), inner)
    } else if func == types.styled {
      let child = inner.child
      assert.eq(inner.styles, inner.styles)
      panic(inner, inner.child, inner.styles) // TODO support these
    } else if func == math.lr {
      if inner.has("size") {
        assert.eq(inner.size, 100%, 0pt) // TODO support different sizes
      }
      return _to-mathml(inner.body)
    } else if func == math.frac {
      elem("mfrac")[
        #_to-mathml(inner.num)
        #_to-mathml(inner.denom)
      ]
    } else if func == math.root {
      if inner.has("index") {
        elem("mroot")[
          #_to-mathml(inner.radicand)
          #_to-mathml(inner.index)
        ]
      } else {
        elem("msqrt", _to-mathml(inner.radicand))
      }
    } else if func == math.binom {
      let lower = inner.lower.map(v => _to-mathml(v)).join(elem("mo", ","))
      if inner.lower.len() > 1 {
        lower = elem("mrow", lower)
      }
      elem("mrow")[
        #elem("mo", "(")
        #elem("mfrac", attrs: (linethickness: "0"))[
          #_to-mathml(inner.upper)
          #lower
        ]
        #elem("mo", ")")
      ]
    } else if func == math.attach {
      // TODO
      // if inner.base.func() == types.symbol and inner.base.text != "x" {
      //   panic(inner)
      // }
      let base = _to-mathml(inner.base)
      let (tr, br, tl, bl, t, b) = ("tr", "br", "tl", "bl", "t", "b").map(name => inner.at(name, default: none))
      if t != none {
        if tr == none {
          tr = t // TODO improve this
        } else {
          panic(inner)
        }
      }
      if b != none {
        if br == none {
          br = b // TODO improve this
        } else {
          panic(inner)
        }
      }
      if tr == none and br == none and bl == none and tl == none {
        return base
      }
      if tl == none and bl == none { // only right
        if tr == none {
          elem("msub")[#base #_to-mathml(br)]
        } else if br == none {
          elem("msup")[#base #_to-mathml(tr)]
        } else {
          elem("msubsup")[#base #_to-mathml(br) #_to-mathml(tr)]
        }
      } else { // with left
        let maybe(it) = if it != none {
          _to-mathml(it)
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
      let children = inner.children.map(v => elem("mtr", elem("mtd", _to-mathml(v))))
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
          elem("mtd", _to-mathml(v))
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

      let children = inner.children.map(v => elem("mtr", elem("mtd", _to-mathml(v))))
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
        #_to-mathml(inner.body)
        #elem("mo", symb)
      ]
      if inner.has("annotation") and inner.annotation != none {
        elem("mover")[
          #res
          #_to-mathml(inner.annotation)
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
        #_to-mathml(inner.body)
        #elem("mo", symb)
      ]
      if inner.has("annotation") and inner.annotation != none {
        elem("munder")[
          #res
          #_to-mathml(inner.annotation)
        ]
      } else {
        res
      }
    } else if func == math.accent {
      if inner.has("size") {
        assert.eq(inner.size, 100% + 0pt)
      }
      let base = _to-mathml(inner.base)
      // TODO improve this
      elem("mover", attrs: (accent: "true"))[
        #base
        #elem("mtext", inner.accent)
      ]
    } else if func == math.class {
      let class = inner.class
      // TODO convert `inner.body` in all cases with `_to-mathml`?
      let body = inner.body
      if class == "normal" or class == "vary" {
        _to-mathml(inner.body)
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
      elem("mo", attrs: attrs, _to-mathml(inner.body))
    } else if func == types.counter-update {
      inner
    } else {
      panic(func, types.counter-update)
      panic("unknown content element of type `" + repr(func) + "`: " + repr(inner))
    }
  } else {
    panic("unknown element of type `" + str(type(inner)) + "`: " + repr(inner))
  }
}

