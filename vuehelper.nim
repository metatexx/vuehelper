# nim build --verbosity:0
# run nim tests

import nimzend

import pegs

import parser, strtabs

proc process_vue(input: string): ZValArray {.phpfunc.} =
  #result = zvalArray(3)

  var foo = newStringTable()
  proc lookup(key: string): string = result = foo[key]
  proc setvar(key, val: string) = foo[key] = val

  let r = splitter(input, lookup, setvar)
  result.add r.css
  result.add r.tmpl
  result.add r.js

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
    start <- rule {(\n / $)}
    rule <- selector+ body
    body <- {'{' @ '}'}
    selector <- name+
    name <- {'#'* [.a-z_]+}{\s* ','* \s* \n*}
    """, handleMatches)

finishExtension("vuehelper", "0.1")
