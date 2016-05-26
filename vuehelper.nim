# nim build --verbosity:0
# run nim tests

import nimzend

import pegs

proc scoped_css(s: string, id: string): string {.phpfunc.} =
  proc handleMatches(m: int, n: int, c: openArray[string]): string =
    var
      n = n
      first = true

    result = ""

    for x in c:
      if first:
        result.add x & "[" & id & "]"
        first = false
      else:
        result.add x
        if x =~ peg"\s*','\s*":
          first = true

      #echo m+1, ".", n, ": ", x
      dec n
      if n == 0: break

  result = s.replace(peg"""
    a <- l {(\n / $)}
    l <- k+ r
    r <- {'{' @ '}'}
    k <- n+
    n <- {'#'* [.a-z_]+}{\s*','*\s*\n*}
    """, handleMatches)

finishExtension("vuehelper", "0.1")
