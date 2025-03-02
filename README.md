# mathyml
[mathyml](https://codeberg.org/akida/mathyml) converts your equations to MathML.
See the [manual](./docs/doc.pdf) for documentation.

## Overview
Mathyml converts your typst equations to MathML Core.
MathML Core is a language for describing mathematical notation and supported by major browsers (firefox and chrome).
You can find an overview of MathML on [mdn](https://developer.mozilla.org/en-US/docs/Web/MathML) and in the [specification](https://www.w3.org/TR/mathml-core/).

Note that MathML rendering is certainly not perfect, some features work better and some worse.
In general the output tends to look much better in firefox than chrome.
See the section about missing/ non-working features below.

MathML Core is not complete and can't render everything itself. Instead it relies on Web Platform features (such as CSS) (see the [explainer](https://w3c.github.io/mathml-core/docs/explainer.html)).
You can find a list of of elements/ features used that do not come from MathML Core below.

## Installation
Execute `python install.py`. This will install the `mathyml` package to the local package folder.

## Quickstart
First, import mathyml and include the prelude, which defines replacements for elements which mathyml can't handle (e.g. `bold` or `cal`).
```typst
#import "@local/mathyml:0.1.0"
#import mathyml: to-mathml
#import mathyml.prelude: *
```
Include the required stylesheet (and the mathfont):
```typst
#mathyml.stylesheets()
```
Note that the mathfont is required, else the rendering looks really bad. The font is currently downloaded from [github](https://github.com/fred-wang/MathFonts). I would recommend changing the font family to your liking and downloading the css files yourself (so that it works without an internet connection).

Convert equations manually:
```typst
The fraction #to-mathml($1/3$) is not a decimal number. And we know
#to-mathml($ a^2 + b^2 = c^2. $)
```
You can also convert equations automatically.
If this panics, try `try-to-mathml` instead, which will create a svg on error.
```typst
#show math.equation: to-mathml

To solve the cubic equation $t^3 + p t + q = 0$ (where the real numbers
$p, q$ satisfy $4p^3 + 27q^2 > 0$) one can use Cardano's formula:
$
  root(3, -q/2 + sqrt(q^2/4 + p^3/27)) + root(3, -q/2 - sqrt(q^2/4 + p^3/27)).
$
```

## Missing/ non-working features
<!--- TODO link to html output of testsuite -->

- set and show rules. Examples:
  - `#show math.equation: set align(start)`
  - `#show math.equation: set text(font: "STIX Two Math")`
  (E.g. issue-3973-math-equation-align, math-attach-show-limit, math-cases-delim, math-equation-show-rule, math-mat-delim-set,math-mat-augment-set, math-vec-delim-set)
- non-math elements: generally not supported
- cancel (just not implemented)
- multiline: break in text (issue-1948-math-text-break)
- weak spacing (math-lr-weak-spacing)
- equation numbering and labels (math-equation-align-numbered)
- rtl (issue-3696-equation-rtl)
- semantics:
  mathml allows adding svg annotations (https://www.w3.org/TR/mathml-core/#semantics-and-presentation).
  Typst html elements may not contain hyphens, so it is currently not possible to create an `annotation-xml` element.
- accents
  - chrome
    - it generally seems the chrome does not recognize the width of the accents, so they also collide and are offset (math-accent-high-base, math-accent-sym-call)
    - dotless (math-accent-dotless)
  - `size` does not work
- alignment
  - nested alignments are unsupported
  - chrome: sometimes chrome does not align the columns correctly (math-align-toggle, math-align-wider-first-column) (does not respect `text-align: right;`)
- attach
  - `t` and `b` attachments are further away (math-attach-mixed, math-attach-subscript-multiline)
  - scripts are limits sometimes  (math-op-scripts-vs-limits) (I am not sure to improve this, as displaystyle should be enough)
  - limits are scripts sometimes (math-accent-wide-base, math-attach-limit-long) (set `movablelimits="false"` for the next inner `mo` in `limits`)
  - attached text is not rendered as stack above but at the top right (math-stretch-attach-nested-equation)
  - nested attachs are not merged (math-attach-nested-deep-base)
  - attachs are not stretched automatically
- lr/ mid
  - the size parameter does not work 
  - firefox: mid is sometimes not completely large enough (math-lr-mid)
  - firefox: lr does not include subscript (math-lr-unparen) 
- mat
  - manual alignment does not work
  - chrome: gap does not work (math-mat-gaps)
  - augment colors (math-mat-augment)
  - linebreaks are not discarded (math-mat-linebreaks)
- primes:
  - chrome: they are really small (math-primes-attach)
- sqrt:
  - chrome: small artifacts (math-root-large-body, math-root-large-index)
- sizes (display, inline, script, sscript):
  - only two levels (math-size)
  - only available via prelude
  - `cramped` is not supported
- variants (serif, sans, frak, mono, bb, cal):
  - only available via prelude
- styles (upright, italic, bold):
  - only available via prelude
  - dotless styles don't really work (math-style-dotless)
- spacing
  - MathML adds extra spaces (math-spacing-kept-spaces) (not too bad)
- stretch
  - only supports `op`s
  - only works (horizontally) with an element above/ below (see math-stretch-complex, math-stretch-horizontal, math-underover-brace)
- overset: multiline in overbrace looks weird, it has extra space

