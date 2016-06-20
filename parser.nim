
# pure Nim for testing

import strscans, strutils, parseutils

type
  Sections* = object
    css*, tmpl*, js*: string

proc scanStyle(input: string; idx: int; r: var Sections;
               lookup: proc(key: string): string;
               setvar: proc (key, val: string); scope: string): int =
  var idx = idx
  var ident = newStringOfCap(80)
  var val = newStringOfCap(80)
  var path = newStringOfCap(80)
  var inbody = false
  var first = true
  while idx < input.len:
    if scanp(input, idx, "</style>"): break
    if not inbody:
      path.setLen 0
      if scanp(input, idx, +{'a'..'z','A'..'Z','0'..'9','#','-','_','.',':'} ->
               path.add($_)):
        r.css.add path
        if first: r.css.add scope
        first = false
    if input[idx] == '$':
      ident.setLen 0
      inc idx
      case input[idx]
      of '{':
        inc idx
        while idx < input.len and input[idx] != '}':
          ident.add input[idx]
          inc idx
        inc idx
      of '$':
        r.css.add '$'
        inc idx
      of IdentStartChars:
        while true:
          ident.add input[idx]
          inc idx
          if input[idx] notin IdentChars: break
      else:
        r.css.add '$'
      if ident.len > 0:
        var i = idx
        while input[i] in Whitespace: inc i
        if input[i] == ':':
          inc i
          val.setLen 0
          while input[i] in Whitespace: inc i
          while i < input.len and input[i] != ';':
            val.add input[i]
            inc i
          idx = i+1
          setVar(ident, val)
        else:
          r.css.add lookup(ident)
    elif input[idx] == '/' and input[idx+1] == '*':
      while idx < input.len and skip(input, "*/", idx)==0:
        inc idx
      inc idx, 2
    else:
      if input[idx] == '{': inbody = true
      elif input[idx] == '}': inbody = false; first = true
      elif input[idx] == ',' and not inbody: first = true
      r.css.add input[idx]
      inc idx
  result = idx

proc scanScript(input: string; i: int; r: var Sections;
                tmplId: string): int =
  var i = i
  const vuecomp = "Vue.component("
  var incomp = false
  while i < input.len:
    if skip(input, "</script>", i) != 0: break
    if input[i] == '/' and input[i+1] == '*':
      while i < input.len and skip(input, "*/", i)==0:
        inc i
      inc i, 2
      continue
    elif input[i] == '/' and input[i+1] == '/':
      while i < input.len and input[i] notin {'\C','\L'}:
        inc i
      continue
    if tmplId.len > 0:
      if skip(input, vuecomp, i) != 0: incomp = true
      if i > 0 and input[i-1] == '{' and incomp:
        incomp = false
        r.js.add("template: '#" & tmplId & "',\n")
    r.js.add(input[i])
    inc i
  result = i

proc scanTemplate(input: string; i: int; r: var Sections;
                  tag, scope: string): int =
  var i = i
  var nested = 0
  var inangle = false
  var outmost = 0
  var ident = newStringOfCap(40)
  while i < input.len:
    case input[i]
    of '<':
      inangle = true
      if skip(input, tag, i+1) != 0 and
          input[i+1+tag.len] in Whitespace+{'>'}:
        inc nested
      elif input[i+1] == '/' and skip(input, tag, i+2) != 0 and
        input[i+2+tag.len] == '>':
        if nested == 0:
          inc i, tag.len+2
          break
        dec nested
      elif skip(input, "<!--", i) != 0:
        inc i, "<!--".len
        while i < input.len and skip(input, "-->", i)==0:
          inc i
        inc i, "-->".len
        continue
    of '>': inangle = false
    of '=':
      if inangle and scope.len > 0:
        # adapt HTML for Scoped CSS:
        var j = i
        # search backwards for the identifier
        while j > 0 and input[j-1] in Whitespace: dec j
        ident.setLen 0
        while j > 0 and input[j-1] notin Whitespace: dec j
        let rollback = j
        while input[j] notin Whitespace+{'='}:
          ident.add input[j]
          inc j
        if ident in ["v-bind:class", ":class", "class", "id"]:
          r.tmpl.setLen r.tmpl.len - (j-rollback)
          r.tmpl.add ' '
          r.tmpl.add scope
          r.tmpl.add ' '
          r.tmpl.add ident
    else: discard
    r.tmpl.add input[i]
    inc i
  result = i


var uniq: int

proc splitter*(input: string; lookup: proc(key: string): string;
             setvar: proc (key, val: string)): Sections =
  result = Sections(css: "", tmpl: "", js: "")
  inc uniq
  let scope = "_vc" & $uniq
  let tmplId = "tmpl" & $uniq
  var idx = 0
  var scoped = false
  var idGenerated = false
  var attr = newStringOfCap(40)
  var tag = newStringOfCap(40)
  while idx < input.len:
    if scanp(input, idx, "<style", *`Whitespace`,
             *`IdentChars` -> attr.add($_), '>'):
      scoped = attr == "scoped"
      idx = scanStyle(input, idx, result, lookup,
                      setvar, if scoped: "[" & scope & "]" else: "")
    elif scanp(input, idx, "<script", * ~ '>','>'):
      idx = scanScript(input, idx, result, if idGenerated: tmplId else: "")
    elif input[idx] == '<':
      attr.setLen 0
      tag.setLen 0
      if scanp(input, idx, '<', *`Whitespace`,
              (+`IdentChars`) -> tag.add($_), *`Whitespace`,
              (* ~'>') -> attr.add($_),'>'):
        if attr.len > 0:
          result.tmpl.add("<" & tag & " " & attr & ">")
        else:
          result.tmpl.add("<" & tag & " id=\"" & tmplId & "\" >")
          idGenerated = true
        idx = scanTemplate(input, idx, result, tag,
                           if scoped: scope else: "")
        result.tmpl.add("</" & tag & ">")
      else:
        inc idx
    else:
      inc idx

when isMainModule:
  import strtabs
  proc main =
    var foo = newStringTable()
    proc lookup(key: string): string =
      result = foo[key]
    proc setvar(key, val: string) =
      foo[key] = val

    let inp = readFile("pdwe-marktfilter.vue")
    var r = splitter(inp, lookup, setvar)
    echo "css ---------------"
    echo r.css
    echo "tmpl ----------------"
    echo r.tmpl
    echo "js ------------------"
    echo r.js

  main()

