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
    } else {
      str(len.to-absolute().pt()) + "pt"
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

#let is-html() = {
  if "target" in dictionary(std) {
    target() == "html"
  } else {
    false
  }
}
