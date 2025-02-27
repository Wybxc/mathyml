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
  if len.ratio == 0% {
    if len.length.abs == 0pt {
      str(len.length.em) + "em"
    } else {
      str(len.length.to-absolute().pt()) + "pt"
    }
  } else if len.length == 0pt {
    repr(len.ratio)
  } else {
    panic(inner, len)
  }
}

#let is-html() = {
  if "target" in dictionary(std) {
    target() == "html"
  } else {
    false
  }
}
