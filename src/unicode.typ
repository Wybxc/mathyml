#import "utils.typ": types

// See https://github.com/typst/typst/blob/d6b0d68ffa4963459f52f7d774080f1f128841d4/crates/typst-layout/src/math/text.rs#L185
#let _styled-char(
  /// -> str
  c,
  auto-italic: false,
  bold: false,
  /// -> boolean | auto
  italic: auto,
  /// one of "serif", "sans", "cal", "frak", "mono" or "bb"
  /// -> str
  variant: "serif",
) = {
  if c.clusters().len() != 1 {
    panic("expected a single character but got " + c.clusters().len() + ": " + c)
  }
  let matches(regex) = c.find(regex) != none
  let italic = if italic == auto {
    (auto-italic
      and matches(regex("[a-zħıȷA-Zα-ω∂ϵϑϰϕϱϖ]"))
      and variant == "sans" or variant == "serif")
  } else {
    italic
  }

  // basic exception
  let basic-exception = (
    "〈": "⟨",
    "〉": "⟩",
    "《": "⟪",
    "》": "⟫",
  )
  if c in basic-exception {
    return basic-exception.at(c)
  }

  // latin-exception
  if (c, variant, bold) == ("B", "cal", false) { return "ℬ" }
  else if (c, variant, bold) == ("E", "cal", false) { return "ℰ" }
  else if (c, variant, bold) == ("F", "cal", false) { return "ℱ" }
  else if (c, variant, bold) == ("H", "cal", false) { return "ℋ" }
  else if (c, variant, bold) == ("I", "cal", false) { return "ℐ" }
  else if (c, variant, bold) == ("L", "cal", false) { return "ℒ" }
  else if (c, variant, bold) == ("M", "cal", false) { return "ℳ" }
  else if (c, variant, bold) == ("R", "cal", false) { return "ℛ" }
  else if (c, variant, bold) == ("C", "frak", false) { return "ℭ" }
  else if (c, variant, bold) == ("H", "frak", false) { return "ℌ" }
  else if (c, variant, bold) == ("I", "frak", false) { return "ℑ" }
  else if (c, variant, bold) == ("R", "frak", false) { return "ℜ" }
  else if (c, variant, bold) == ("Z", "frak", false) { return "ℨ" }
  else if (c, variant) == ("C", "bb") { return "ℂ" }
  else if (c, variant) == ("H", "bb") { return "ℍ" }
  else if (c, variant) == ("N", "bb") { return "ℕ" }
  else if (c, variant) == ("P", "bb") { return "ℙ" }
  else if (c, variant) == ("Q", "bb") { return "ℚ" }
  else if (c, variant) == ("R", "bb") { return "ℝ" }
  else if (c, variant) == ("Z", "bb") { return "ℤ" }
  else if (c, variant, italic) == ("D", "bb", true) { return "ⅅ" }
  else if (c, variant, italic) == ("d", "bb", true) { return "ⅆ" }
  else if (c, variant, italic) == ("e", "bb", true) { return "ⅇ" }
  else if (c, variant, italic) == ("i", "bb", true) { return "ⅈ" }
  else if (c, variant, italic) == ("j", "bb", true) { return "ⅉ" }
  else if (c, variant, bold, italic) == ("h", "serif", false, true) { return "ℎ" }
  else if (c, variant, bold) == ("e", "cal", false) { return "ℯ" }
  else if (c, variant, bold) == ("g", "cal", false) { return "ℊ" }
  else if (c, variant, bold) == ("o", "cal", false) { return "ℴ" }
  else if (c, variant, italic) == ("ħ", "serif", true) { return "ℏ" }
  else if (c, variant, italic) == ("ı", "serif", true) { return "𝚤" }
  else if (c, variant, italic) == ("ȷ", "serif", true) { return "𝚥" }

  // greek-exception
  if c == "Ϝ" and variant == "serif" and bold {
      return "𝟊";
  }
  if c == "ϝ" and variant == "serif" and bold {
      return "𝟋";
  }
  let list = if c == "ϴ" { ("𝚹", "𝛳", "𝜭", "𝝧", "𝞡", "ϴ") }
    else if c == "∇" { ("𝛁", "𝛻", "𝜵", "𝝯", "𝞩", "∇") }
    else if c == "∂" { ("𝛛", "𝜕", "𝝏", "𝞉", "𝟃", "∂") }
    else if c == "ϵ" { ("𝛜", "𝜖", "𝝐", "𝞊", "𝟄", "ϵ") }
    else if c == "ϑ" { ("𝛝", "𝜗", "𝝑", "𝞋", "𝟅", "ϑ") }
    else if c == "ϰ" { ("𝛞", "𝜘", "𝝒", "𝞌", "𝟆", "ϰ") }
    else if c == "ϕ" { ("𝛟", "𝜙", "𝝓", "𝞍", "𝟇", "ϕ") }
    else if c == "ϱ" { ("𝛠", "𝜚", "𝝔", "𝞎", "𝟈", "ϱ") }
    else if c == "ϖ" { ("𝛡", "𝜛", "𝝕", "𝞏", "𝟉", "ϖ") }
    else if c == "Γ" { ("𝚪", "𝛤", "𝜞", "𝝘", "𝞒", "ℾ") }
    else if c == "γ" { ("𝛄", "𝛾", "𝜸", "𝝲", "𝞬", "ℽ") }
    else if c == "Π" { ("𝚷", "𝛱", "𝜫", "𝝥", "𝞟", "ℿ") }
    else if c == "π" { ("𝛑", "𝜋", "𝝅", "𝝿", "𝞹", "ℼ") }
    else if c == "∑" { ("∑", "∑", "∑", "∑", "∑", "⅀") }
    else { none }
  if list != none {
    if (variant, bold, italic) == ("serif", true, false) { return list.at(0) }
    else if (variant, bold, italic) == ("serif", true, false) { return list.at(1) }
    else if (variant, bold, italic) == ("serif", false, true) { return list.at(2) }
    else if (variant, italic) == ("sans", true) { return list.at(3) }
    else if (variant, italic) == ("sans", false) { return list.at(4) }
    else if variant == "bb" { return list.at(5) }
  }

  let base = if matches(regex("[A-Z]")) { "A" }
  else if matches(regex("[A-Z]")) { "A" }
  else if matches(regex("[a-z]")) { "a" }
  else if matches(regex("[Α-Ω]")) { "Α" }
  else if matches(regex("[α-ω]")) { "α" }
  else if matches(regex("[0-9]")) { "0" }
  else if matches(regex("[\\u05D0-\\u05D3]")) { "\u{05D0}" } // Hebrew Alef -> Dalet.
  else { return c }

  let start = if matches(regex("[A-Z]")) {
    // Latin upper.
    if (variant, bold, italic) == ("serif", false, false) { 0x0041 }
    else if (variant, bold, italic) == ("serif", true, false) { 0x1D400 }
    else if (variant, bold, italic) == ("serif", false, true) { 0x1D434 }
    else if (variant, bold, italic) == ("serif", true, true) { 0x1D468 }
    else if (variant, bold, italic) == ("sans", false, false) { 0x1D5A0 }
    else if (variant, bold, italic) == ("sans", true, false) { 0x1D5D4 }
    else if (variant, bold, italic) == ("sans", false, true) { 0x1D608 }
    else if (variant, bold, italic) == ("sans", true, true) { 0x1D63C }
    else if (variant, bold) == ("cal", false) { 0x1D49C }
    else if (variant, bold) == ("cal", true) { 0x1D4D0 }
    else if (variant, bold) == ("frak", false) { 0x1D504 }
    else if (variant, bold) == ("frak", true) { 0x1D56C }
    else if variant == "mono" { 0x1D670 }
    else if variant == "bb" { 0x1D538 }
    else { panic("unreachable", c, variant, bold, italic) }
  } else if matches(regex("[a-z]")){
    // Latin lower.
    if (variant, bold, italic) == ("serif", false, false) { 0x0041 }
    else if (variant, bold, italic) == ("serif", false, false) { 0x0061 }
    else if (variant, bold, italic) == ("serif", true, false) { 0x1D41A }
    else if (variant, bold, italic) == ("serif", false, true) { 0x1D44E }
    else if (variant, bold, italic) == ("serif", true, true) { 0x1D482 }
    else if (variant, bold, italic) == ("sans", false, false) { 0x1D5BA }
    else if (variant, bold, italic) == ("sans", true, false) { 0x1D5EE }
    else if (variant, bold, italic) == ("sans", false, true) { 0x1D622 }
    else if (variant, bold, italic) == ("sans", true, true) { 0x1D656 }
    else if (variant, bold) == ("cal", false) { 0x1D4B6 }
    else if (variant, bold) == ("cal", true) { 0x1D4EA }
    else if (variant, bold) == ("frak", false) { 0x1D51E }
    else if (variant, bold) == ("frak", true) { 0x1D586 }
    else if variant == "mono" { 0x1D68A }
    else if variant == "bb" { 0x1D552 }
    else { panic("unreachable", c, variant, bold, italic) }
  } else if matches(regex("[Α-Ω]")) {
    // Greek upper.
    if (variant, bold, italic) == ("serif", false, false) { 0x0391 }
    else if (variant, bold, italic) == ("serif", true, false) { 0x1D6A8 }
    else if (variant, bold, italic) == ("serif", false, true) { 0x1D6E2 }
    else if (variant, bold, italic) == ("serif", true, true) { 0x1D71C }
    else if (variant, italic) == ("sans", false) { 0x1D756 }
    else if (variant, italic) == ("sans", true) { 0x1D790 }
    else { return c }
  } else if matches(regex("[α-ω]")) {
    // Greek lower.
    if (variant, bold, italic) == ("serif", false, false) { 0x03B1 }
    else if (variant, bold, italic) == ("serif", true, false) { 0x1D6C2 }
    else if (variant, bold, italic) == ("serif", false, true) { 0x1D6FC }
    else if (variant, bold, italic) == ("serif", true, true) { 0x1D736 }
    else if (variant, italic) == ("sans", false) { 0x1D770 }
    else if (variant, italic) == ("sans", true) { 0x1D7AA }
    else { return c }
  } else if matches(regex("[\\u05D0-\\u05D3]")) {
    0x2135 // Hebrew Alef -> Dalet.
  } else if matches(regex("[0-9]")) {
    // Numbers.
    if (variant, bold) == ("serif", false) { 0x0030 }
    else if (variant, bold) == ("serif", true) { 0x1D7CE }
    else if variant == "bb" { 0x1D7D8 }
    else if (variant, bold) == ("sans", false) { 0x1D7E2 }
    else if (variant, bold) == ("sans", true) { 0x1D7EC }
    else if variant == "mono" { 0x1D7F6 }
    else { return c }
  } else {
    panic("unreachable", c)
  }
 
  str.from-unicode(start + (str.to-unicode(c) - str.to-unicode(base)))
}

#let convert_variants(
  /// -> str | content
  inner,
  auto-italic: false,
  bold: false,
  /// -> boolean | auto
  italic: auto,
  /// one of "serif", "sans", "cal", "frak", "mono" or "bb"
  /// -> str
  variant: "serif",
) = {
  let s = if type(inner) == str {
    inner
  } else if type(inner) == content {
    let func = inner.func()
    if func == types.symbol {
      inner.text
    } else if func == types.sequence {
      return inner.children.map(c => convert_variants(c, auto-italic: auto-italic, bold: bold, italic: italic, variant: variant)).join()
    } else if func == types.space {
      return inner
    } else {
      panic("invalid content type " + repr(func))
    }
  } else {
    panic("invalid type " + repr(type(inner)))
  }
  let res = s.codepoints().map(c => _styled-char(c, auto-italic: auto-italic, bold: bold, italic: italic, variant: variant)).join()
  // don't return a string because in `_to-mathml` we convert strings to `mtext`
  // and we want to create a `mi`.
  symbol(res)
}

#let serif = convert_variants.with(variant: "serif")
#let sans = convert_variants.with(variant: "sans")
#let frak = convert_variants.with(variant: "frak")
#let mono = convert_variants.with(variant: "mono")
#let bb = convert_variants.with(variant: "bb")
#let cal = convert_variants.with(variant: "cal")
