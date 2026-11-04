; ----------------------------------------------------------------------------
;---------- Render ---------
; ----------------------------------------------------------------------------
; Page style, images, search highlight and Internet Explorer mode.
; Included inside Module pbhelp (EnableExplicit is active).

; Default theme: CSS variables (replaced by the colors of the IDE theme, see setcolors()) and page style.
Theme\Colors$ = ":root {color-scheme: light; --bg:#fed; --text:#000; --titlebg:#ff8; --codebg:#edc; --tablebg:#fff; --optbg:#eee; --border:#0002; --notebg:#f80; --link:#00f; --constant:#a00; --function:#088; --keyword:#088; --userlib:#080;}"
Theme\ColorsLight$ = Theme\Colors$
Theme\ColorsDark$ = ":root {color-scheme: dark; --bg:#1f2023; --text:#e0e0e0; --titlebg:#5a5a1e; --codebg:#2c2e33; --tablebg:#26282c; --optbg:#303338; --border:#ffffff33; --notebg:#a05a00; --link:#7db7ff; --constant:#ff8f8f; --function:#4fd1c5; --keyword:#4fd1c5; --userlib:#7ddf7d;}"
Theme\Style$ = "body {display: inline-block; min-width: calc(100% - 38px); box-sizing: border-box; background-color: var(--bg); color: var(--text); font-family: Arial, Helvetica, sans-serif; font-size: 10pt;margin-left:30px}" +
         "h2 {position: sticky;z-index: 10;font-size:20pt; font-weight: normal; top:0; text-align: center; background-color:var(--titlebg);padding: 5px; margin:-8px -8px 8px -30px; box-shadow: 0px 5px 5px #00000088;}" +
         "h3 {margin-left:-20px;}" +
         "a, a:visited, a:active {font-size: 10pt; color: var(--link);}" +
         ".nav, .nav a {color: var(--link); font-size: 13px;}" +
         ".cst {color: var(--constant);} .fct {color: var(--function);} .kw {color: var(--keyword); font-weight: bold;} .ul {color: var(--userlib);}" +
         ".opt {background-color: var(--optbg);}" +
         ".note {background-color: var(--notebg);} div.note {font-size: 16px;}" +
         ".deprecated {padding: 5px; margin: 5px 0px 10px; border: 1px solid var(--border);} .deprecated b {color: #e00;}" +
         ".found {background-color: #ff0; color: #000;}" +
         "img {box-shadow: 2px 2px 5px #0008;}" +
         "button img {box-shadow: none; width: 16px; height: 16px; vertical-align: middle;}" +
         "pre {overflow: visible; width: max-content; min-width: 100%; box-sizing: border-box; font-family:consolas, Courier, monospace; font-size: 9pt;}" +
         "pre.ex {padding: 5px; background-color:var(--codebg);border-style: solid; border-width:1px; border-color:var(--border);}" +
         "button {box-shadow: 2px 2px 2px #0008;}" +
         ".butcode {display: flex; gap: 5px; width: fit-content; margin: 8px 0 3px auto; position: sticky; right: 5px;}" +
         "table {box-shadow: 2px 2px 3px #0008;background-color: var(--tablebg);}" +
         "table, th, td {border-collapse: collapse;padding:2px 10px 2px;font-size: 10pt;border-color:var(--border);}" +
         "table.param {width:100%;  border-spacing: 0px; border-style: none; }" +
         "table.param td { border-width: 1px; padding: 6px; border-style: solid;  vertical-align: top;}"
Theme\UserLibColor = $008800        ; color of the user libraries in the contents tree
Theme\IconOpen$ = "&#128194;"       ; example buttons (replaced by the icons of the IDE)
Theme\IconRun$  = "&#9654;"
Theme\IconCopy$ = "&#128203;"
; The page scrolls, not the code blocks; the title bar and the example buttons follow the width of the page
; (the title text stays centered in the window, see the script of ShowHtml()).
Theme\Style$ + " h2 .t {position: sticky; left: 0; width: calc(var(--vw, 100%) - 10px);}"
CompilerIf #PB_Helpsample_Image = #False ; text buttons of the examples: same font as the chips
  Theme\Style$ + " .butcode button {font-family: '" + #ChipFontName$ + "', sans-serif; font-size: " + Str(#ChipFontSize) + "pt;}"
CompilerEndIf

; Chooses the colors of the pages: dark mode first, else the colors of the IDE theme if it gave some, else the built-in light ones.
Procedure ColorsApply()
  If Theme\Dark
    Theme\Colors$ = Theme\ColorsDark$
  ElseIf Theme\Custom
    Theme\Colors$ = Theme\ColorsCustom$
  Else
    Theme\Colors$ = Theme\ColorsLight$
  EndIf
EndProcedure

; Html <img> of a picture of the help (HelpPictures, else the images of the language), "" if not found.
Procedure.s ImageToHtml(Name$)
  Protected *Memory
  Protected Html$

  *Memory = SourceReadBinary("HelpPictures/" + Name$)
  If *Memory = 0
    *Memory = SourceReadBinary(LanguageFolder() + "Reference/Images/" + Name$)
  EndIf
  If *Memory = 0
    ProcedureReturn ""
  EndIf
  Html$ = "<img src ='Data:image/" + GetExtensionPart(Name$) + ";base64," + Base64Encoder(*Memory, MemorySize(*Memory)) + "' />"
  FreeMemory(*Memory)
  ProcedureReturn Html$
EndProcedure

; Highlights Search$ in the text of the body, without touching the html tags and ignoring the case.
; Single pass: FindString() would restart from the length of the string at each call (too slow on big pages).
Procedure.s HtmlHighlight(Html$, Search$)
  Protected *Char.Character, *Start
  Protected Pos, CopyStart, SearchLength, InTag
  Protected Result$, LowerHtml$, LowerSearch$

  Search$ = HtmlEscape(Search$)
  SearchLength = Len(Search$)
  If SearchLength = 0
    ProcedureReturn Html$
  EndIf
  Pos = FindString(Html$, "<body")
  If Pos = 0
    ProcedureReturn Html$
  EndIf
  LowerHtml$ = LCase(Html$)
  LowerSearch$ = LCase(Search$)
  *Start = @LowerHtml$
  *Char = *Start + (Pos - 1) * SizeOf(Character)
  CopyStart = 1 ; start of the part not copied yet
  While *Char\c
    If *Char\c = '<'
      InTag = #True
    ElseIf *Char\c = '>'
      InTag = #False
    ElseIf InTag = #False And CompareMemoryString(*Char, @LowerSearch$, #PB_String_CaseSensitive, SearchLength) = #PB_String_Equal ; Search$ has no "<" (HtmlEscape): can't overflow on a tag
      Pos = (*Char - *Start) / SizeOf(Character) + 1
      If Pos > CopyStart
        Result$ + Mid(Html$, CopyStart, Pos - CopyStart)
      EndIf
      Result$ + "<font class='found'>" + Mid(Html$, Pos, SearchLength) + "</font>"
      CopyStart = Pos + SearchLength
      *Char + (SearchLength - 1) * SizeOf(Character)
    EndIf
    *Char + SizeOf(Character)
  Wend
  ProcedureReturn Result$ + Mid(Html$, CopyStart)
EndProcedure

; Internet Explorer mode: no CSS variables and no javascript callback (jsmessage() is sent by a 'pbhelp:' url).
Procedure.s HtmlForIe(Html$)
  Protected Index
  Protected Variable$, Name$, Value$

  For Index = 1 To CountString(Theme\Colors$, ";") + 1
    Variable$ = Trim(StringField(Theme\Colors$, Index, ";"))
    If Left(Variable$, 2) = "--"
      Name$ = Trim(StringField(Variable$, 1, ":"))
      Value$ = Trim(RemoveString(StringField(Variable$, 2, ":"), "}"))
      Html$ = ReplaceString(Html$, "var(" + Name$ + ")", Value$)
    EndIf
  Next
  Html$ = ReplaceString(Html$, "onclick='jsmessage(", "onclick='return jsmessage(")
  Html$ = ReplaceString(Html$, "<head>", "<head><meta http-equiv='X-UA-Compatible' content='IE=edge'>" +
                                          "<script>function jsmessage(m) {window.location.href='pbhelp:'+encodeURIComponent(m); return false;}</script>", #PB_String_CaseSensitive, 1, 1)
  ProcedureReturn "<!DOCTYPE html>" + Html$
EndProcedure
