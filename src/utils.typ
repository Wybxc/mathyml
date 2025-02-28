#let types = (
  sequence: [$$ $$].func(),
  symbol: [#sym.eq].func(),
  space: [ ].func(),
  styled: math.bb("a").func(),
  counter-update: counter("_mathml-counter-type").update(0).func(),
  context_: (context 1).func(),
  align-point: $&$.body.func(),
)

#let convert-relative-len(len, inner) = {
  if type(len) == length {
    return if len.abs == 0pt {
      str(len.em) + "em"
    } else if len.em == 0 {
      repr(len.abs)
    } else {
      "calc(" + str(len.em) + "em + " + repr(len.abs) + ")" // FIXME does this work?
    }
  }
  if len.ratio == 0% {
    convert-relative-len(len.length, inner)
  } else if len.length == 0pt {
    repr(len.ratio)
  } else {
    let abs = convert-relative-len(len.length, inner)
    let rel = repr(len.ratio)
    "calc(" + abs + " + " + rel + ")" // FIXME does this work?
  }
}

#let is-html(allow-ctx: true) = {
  if "target" in dictionary(std) {
    if allow-ctx {
      target() == "html"
    } else {
      true
    }
  } else {
    false
  }
}

#let _type-ident = "_mathml-type"
#let _dict-types = (
  upright: "upright",
  italic: "italic",
  bold: "bold",
  variant: "variant",
)
#let _err-tag = "_mathml-error"
