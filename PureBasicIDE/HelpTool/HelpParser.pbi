; ----------------------------------------------------------------------------
;---------- Parser ---------
; ----------------------------------------------------------------------------
; DocMaker tags and conversion of a page (DocMaker source -> html).
; Included inside Module pbhelp (EnableExplicit is active).

; ----------------------------------------------------------------------------
;- Tags
; ----------------------------------------------------------------------------
; The html of a tag can contain:
;   $p1, $p2 : 1st and 2nd parameter of the tag      $lg  : rest of the line
;   $ex      : number of the example                 $im  : image          $lt  : rest of the line, trimmed
;   $ose     : OS of the example (shown only for this OS or "All")

; Adds a tag. Param: 1 function parameter, 2 optional parameter, 3 end of the parameters. Title = 1: title level tag.
Procedure TagAdd(Name$, Param, Title, Html$)
  AddMapElement(Tags(), Name$)
  Tags()\Html$ = Html$
  Tags()\Param = Param
  Tags()\Title = Title
  If FindString(Html$, "<pre")
    Tags()\Pre = 1
  ElseIf FindString(Html$, "</pre")
    Tags()\Pre = -1
  EndIf
EndProcedure

; Html of one example button: icon with a tooltip, or text (#PB_Helpsample_Image).
Procedure.s SampleButton(Title$, Icon$, Message$)
  CompilerIf #PB_Helpsample_Image
    ProcedureReturn "<button title='" + Title$ + "' onclick='jsmessage(" + #DQUOTE$ + Message$ + #DQUOTE$ + ")'>" + Icon$ + "</button>"
  CompilerElse
    ProcedureReturn "<button onclick='jsmessage(" + #DQUOTE$ + Message$ + #DQUOTE$ + ")'>" + Title$ + "</button>"
  CompilerEndIf
EndProcedure

; Html of the example buttons Open, Copy, Run. Kind$ "c" (code of the page) or "f" (example file), Id$ = $ex or $lg.
Procedure.s SampleButtons(Kind$, Id$, Separator$)
  ProcedureReturn SampleButton(Language(#TextGroup$, "Open"), Theme\IconOpen$, Kind$ + "o:" + Id$) + Separator$ +
                  SampleButton(Language(#TextGroup$, "Copy"), Theme\IconCopy$, Kind$ + "c:" + Id$) + Separator$ +
                  SampleButton(Language(#TextGroup$, "Run"), Theme\IconRun$, Kind$ + "r:" + Id$)
EndProcedure

; Builds the tag table in the current language (replaces the old initbalise()).
Procedure TagsInit()
  Protected OverviewText$ = Language(#TextGroup$, "Overview")
  Protected CommandListText$ = Language(#TextGroup$, "CommandList")
  Protected ReturnValueText$ = Language(#TextGroup$, "ReturnValue")
  Protected NoneText$ = Language(#TextGroup$, "None")
  Protected RemarksText$ = Language(#TextGroup$, "Remarks")
  Protected ExampleText$ = Language(#TextGroup$, "Example")
  Protected SeeAlsoText$ = Language(#TextGroup$, "SeeAlso")
  Protected SyntaxText$ = Language(#TextGroup$, "Syntax")
  Protected DescriptionText$ = Language(#TextGroup$, "Description")
  Protected DeprecatedText$ = Language(#TextGroup$, "Deprecated")
  Protected DeprecatedNoteText$ = Language(#TextGroup$, "DeprecatedNote")

  ClearMap(Tags())
  TagAdd("linebreak", 0, 0, "<br>")
  TagAdd("red", 0, 0, "<font color=Red>$p1</font>")
  TagAdd("green", 0, 0, "<font color=Green>$p1</font>")
  TagAdd("blue", 0, 0, "<font color=Blue>$p1</font>")
  TagAdd("orange", 0, 0, "<font color=Orange>$p1</font>")
  TagAdd("bold", 0, 0, "<b>$p1</b>")
  TagAdd("underline", 0, 0, "<u>$p1</u>")
  TagAdd("constantcolor", 0, 0, "<font class='cst'>$p1</font>")
  TagAdd("functioncolor", 0, 0, "<font class='fct'>$p1</font>")
  TagAdd("formatif", 0, 0, "$lg")
  TagAdd("formatelse", 0, 0, "")
  TagAdd("formatendif", 0, 0, "")
  TagAdd("html", 0, 0, "")
  TagAdd("endhtml", 0, 0, "")
  TagAdd("code", 0, 0, "<div class='butcode'>" + SampleButtons("c", "$ex", "") + "</div><pre class='ex'>")
  TagAdd("endcode", 0, 0, "</pre>")
  TagAdd("os", 0, 0, "")
  TagAdd("endos", 0, 0, "")
  TagAdd("fixedfont", 0, 0, "<pre>")
  TagAdd("endfixedfont", 0, 0, "</pre>")
  TagAdd("indent", 0, 1, "<blockquote>")
  TagAdd("endindent", 0, 1, "</blockquote>")
  TagAdd("keyword", 0, 0, "<font class='kw'>$p1</font>")
  TagAdd("image", 0, 0, "$im<br>")
  TagAdd("examplefile", 0, 0, "$ose<a href='#' onclick='jsmessage(" + #DQUOTE$ + "ef:$lt" + #DQUOTE$ + ")'>$lt</a>") ; link to the example shown as a page
  TagAdd("library", 0, 1, "")
  TagAdd("section", 0, 1, "<h3>$lg</h3>")
  TagAdd("overview", 0, 1, "<h3>" + OverviewText$ + "</h3>")
  TagAdd("commandlist", 0, 1, "<h3>" + CommandListText$ + "</h3>")
  TagAdd("returnvalue", 3, 1, "<h3>" + ReturnValueText$ + "</h3>")
  TagAdd("noreturnvalue", 3, 1, "<h3>" + ReturnValueText$ + "</h3>" + NoneText$ + ".")
  TagAdd("remarks", 3, 1, "<h3>" + RemarksText$ + "</h3>")
  TagAdd("example", 0, 1, "<h3>" + ExampleText$ + "</h3>")
  TagAdd("seealso", 0, 1, "<h3>" + SeeAlsoText$ + "</h3>")
  TagAdd("supportedos", 0, 1, "")
  TagAdd("function", 0, 1, "<h3>" + SyntaxText$ + "</h3><pre>$p1")
  TagAdd("syntax", 0, 1, "<h3>" + SyntaxText$ + "</h3><pre>")
  TagAdd("description", 0, 1, "</pre><h3>" + DescriptionText$ + "</h3>")
  TagAdd("deprecated", 0, 0, "<div class='deprecated'><b>" + DeprecatedText$ + "</b><br>" + DeprecatedNoteText$ + "</div>")
  TagAdd("parameter", 1, 1, "")
  TagAdd("optionalparameter", 2, 1, "")
  TagAdd("noparameters", 3, 1, "")
  TagAdd("internetlink", 0, 0, "<a href='$p1'>$p2</a>")
  TagAdd("link", 0, 0, "<a href='#' onclick='jsmessage(" + #DQUOTE$ + "lk:$p1" + #DQUOTE$ + ")'>$p2</a>")
  TagAdd("librarylink", 0, 0, "<a href='#' onclick='jsmessage(" + #DQUOTE$ + "lk:lib_$p1" + #DQUOTE$ + ")'>$p2 </a>")
  TagAdd("fastlink", 0, 0, "<a href='#' onclick='jsmessage(" + #DQUOTE$ + "lk:$p1" + #DQUOTE$ + ")'>$p1 </a>")
  TagAdd("referencelink", 0, 0, "<a href='#' onclick='jsmessage(" + #DQUOTE$ + "lk:$p1" + #DQUOTE$ + ")'>$p2 </a>")
  TagAdd("mainguidelink", 0, 0, "<a href='#' onclick='jsmessage(" + #DQUOTE$ + "lk:$p1" + #DQUOTE$ + ")'>$p2 </a>")
EndProcedure

; ----------------------------------------------------------------------------
;- Page conversion
; ----------------------------------------------------------------------------

Enumeration ParserAddType
  #AddText ; plain text: html escaped
  #AddRaw  ; html code: added as is
  #AddHtml ; html code from the sources: images inlined, links converted
EndEnumeration

; State of the conversion of one page.
Structure ParserState
  Source$        ; source of the page, without the comment lines
  Output$        ; html built so far
  Position.i     ; reading position in Source$
  PreCount.i     ; > 0 inside <pre> (the line feeds are kept as they are)
  AddLineBreaks.i ; #True: a <br> is added to the line feeds of the next text
EndStructure

Global ParserDelimiters$ = " .,;:()[]{}>@/" + #LF$ + Chr(34) + Chr(160) ; end of a tag name or of a parameter

; Source without the lines that start with ";".
Procedure.s RemoveCommentLines(Text$)
  Protected Start = 1, Stop
  Protected Result$

  If Left(Text$, 1) <> ";" And FindString(Text$, #LF$ + ";") = 0
    ProcedureReturn Text$
  EndIf
  While Start <= Len(Text$)
    Stop = FindString(Text$, #LF$, Start)
    If Stop = 0
      Stop = Len(Text$)
    EndIf
    If Mid(Text$, Start, 1) <> ";"
      Result$ + Mid(Text$, Start, Stop - Start + 1)
    EndIf
    Start = Stop + 1
  Wend
  ProcedureReturn Result$
EndProcedure

; Adds an error note to the page and to ParserErrors$.
Procedure ParserError(*Parser.ParserState, Message$)
  *Parser\Output$ + "<font class='note'>" + Message$ + "</font>"
  ParserErrors$ + Message$ + #LF$
EndProcedure

; Reads the next parameter of a tag: a "quoted text", or a text up to one of the Delimiters$ characters.
Procedure.s ParserReadParam(*Parser.ParserState, Delimiters$)
  Protected Closing$, Start

  While Mid(*Parser\Source$, *Parser\Position, 1) = " "
    *Parser\Position + 1
  Wend
  If Mid(*Parser\Source$, *Parser\Position, 1) = #DQUOTE$
    Closing$ = #DQUOTE$
  Else
    Closing$ = Delimiters$
  EndIf
  Start = *Parser\Position
  *Parser\Position + 1
  While *Parser\Position <= Len(*Parser\Source$) And FindString(Closing$, Mid(*Parser\Source$, *Parser\Position, 1)) = 0
    *Parser\Position + 1
  Wend
  If Closing$ = #DQUOTE$
    *Parser\Position + 1
    ProcedureReturn Mid(*Parser\Source$, Start + 1, *Parser\Position - Start - 2)
  EndIf
  ProcedureReturn Mid(*Parser\Source$, Start, *Parser\Position - Start)
EndProcedure

; Adds text to the page (see ParserAddType).
Procedure ParserAdd(*Parser.ParserState, Text$, AddType = #AddText)
  Protected Position
  Protected Path$, Image$

  Select AddType
    Case #AddText
      Text$ = HtmlEscape(Text$, Bool(*Parser\AddLineBreaks And *Parser\PreCount = 0))
    Case #AddRaw
      ; nothing to do
    Case #AddHtml
      Position = 0
      Repeat ; <img src=...> -> inlined picture
        Position = FindString(Text$, "<img", Position + 1)
        If Position = 0
          Break
        EndIf
        Path$ = StringBetween(Text$, "src=", ">", Position)
        Image$ = ImageToHtml(GetFilePart(Path$))
        If Image$ <> ""
          Text$ = ReplaceString(Text$, "src=" + Path$ + ">", Image$)
          Position + Len(Image$) - Len(Path$)
        Else
          ParserError(*Parser, "image not found:* " + Path$)
        EndIf
      ForEver
      Position = 0
      Repeat ; <a href=...> -> link to a page of the help
        Position = FindString(Text$, "<a", Position + 1)
        If Position = 0
          Break
        EndIf
        Path$ = StringBetween(Text$, "href=", ">", Position)
        If FindString(Path$, "#") = 0
          Text$ = ReplaceString(Text$, "href=" + Path$ + ">", "href='#' onclick='jsmessage(" + #DQUOTE$ + "lk:" + LCase(GetFilePart(Path$, #PB_FileSystem_NoExtension)) + #DQUOTE$ + ")'>")
        EndIf
      ForEver
  EndSelect
  *Parser\Output$ + Text$
EndProcedure

; Converts the page Name$ (DocMaker source) to html. The errors are in ParserErrors$.
; The search highlight (HtmlHighlight) is applied by the caller.
Procedure.s PageToHtml(Name$)
  Protected *Page.PageInfo, *Target.PageInfo
  Protected Parser.ParserState
  Protected Position, Position2, FirstEnd, Index
  Protected ChunkStart, TagStart
  Protected TitleTag, PrevTitleTag, TableRows, ExampleStarted, ExampleNumber
  Protected Tag$, Char$, Html$, Param$, Reference$, LinkText$, OptionClass$, Image$, LowerSource$, OsNote$
  Protected ParametersText$, ExampleText$

  If FindMapElement(*PageByName(), LCase(Name$)) = 0
    ProcedureReturn ""
  EndIf
  *Page = *PageByName()
  ParametersText$ = Language(#TextGroup$, "Parameters")
  ExampleText$ = Language(#TextGroup$, "Example")

  Parser\Source$ = *Page\Source$
  If Right(Parser\Source$, 1) <> #LF$ ; the tags read up to the end of the line ($lg) need it (ie: @ExampleFile at the end of a file)
    Parser\Source$ + #LF$
  EndIf
  Parser\Source$ = RemoveCommentLines(Parser\Source$)
  ParserErrors$ = ""

  Parser\Position = 1
  Repeat
    ChunkStart = Parser\Position
    TagStart = FindString(Parser\Source$, "@", Parser\Position)
    If TagStart = 0 ; no more tags: the rest is text
      ParserAdd(@Parser, Mid(Parser\Source$, Parser\Position), #AddText)
      Break
    EndIf

    ; --- name of the tag: up to a delimiter
    Parser\Position = TagStart + 1
    Tag$ = ""
    Char$ = Mid(Parser\Source$, Parser\Position, 1)
    Repeat
      Parser\Position + 1
      Tag$ + Char$
      Char$ = Mid(Parser\Source$, Parser\Position, 1)
    Until (FindString(ParserDelimiters$, Char$) And Tag$ + Char$ <> "</") Or Char$ = ""
    Char$ = Mid(Parser\Source$, TagStart + 1, 1)
    If Char$ = "@" Or Char$ = "#" ; @@Function and @#Constant: only letters, digits and "_" (as DocMaker)
      Parser\Position = TagStart + 2
      While Mid(Parser\Source$, Parser\Position, 1) <> "" And FindString(#IdentifierChars$, Mid(Parser\Source$, Parser\Position, 1))
        Parser\Position + 1
      Wend
      Tag$ = Mid(Parser\Source$, TagStart + 1, Parser\Position - TagStart - 1)
    EndIf

    ; --- the line feeds around the "title" tags are ignored
    PrevTitleTag = TitleTag
    If FindString("#@<", Char$)
      TitleTag = 0
    EndIf
    If FindMapElement(Tags(), LCase(Tag$))
      TitleTag = Tags()\Title
    EndIf
    If PrevTitleTag And Mid(Parser\Source$, ChunkStart, 1) = #LF$
      ChunkStart + 1
    EndIf
    If TitleTag And Mid(Parser\Source$, TagStart - 1, 1) = #LF$
      TagStart - 1
    EndIf
    If TagStart > ChunkStart ; (TagStart < ChunkStart if two title tags follow each other)
      ParserAdd(@Parser, Mid(Parser\Source$, ChunkStart, TagStart - ChunkStart), #AddText)
    EndIf

    ; --- the tag
    Parser\AddLineBreaks = #True
    Select Char$
      Case "#" ; constant
        ParserAdd(@Parser, "<font class='cst'>" + Tag$ + "</font>", #AddRaw)

      Case "@" ; link to a function
        Reference$ = LCase(Mid(Tag$, 2))
        *Target = 0
        If FindMapElement(*PageByName(), Reference$)
          *Target = *PageByName()
        EndIf
        If *Target
          LinkText$ = *Target\Title$
          If *Target\UserLib$ <> ""
            LinkText$ = "<font class='ul'>" + LinkText$ + "</font>"
          EndIf
          ParserAdd(@Parser, "<a href='#' onclick='jsmessage(" + #DQUOTE$ + "lk:" + Reference$ + #DQUOTE$ + ")'>" + LinkText$ + "</a>", #AddRaw)
        Else
          ParserError(@Parser, "ref not found: " + Reference$)
        EndIf

      Case "<" ; html tag (@<table border=1>)
        Parser\AddLineBreaks = #False
        Position = Parser\Position
        Parser\Position = FindString(Parser\Source$, ">", Parser\Position)
        ParserAdd(@Parser, "<" + Mid(Tag$, 2) + " " + Mid(Parser\Source$, Position, Parser\Position - Position) + ">", #AddRaw)
        Parser\Position + 1

      Default
        If FindMapElement(Tags(), LCase(Tag$))
          Parser\PreCount + Tags()\Pre
          If Parser\PreCount < 0 ; @Description without @Syntax/@Function before (ie: Reference pages)
            Parser\PreCount = 0
          EndIf
          Html$ = ""
          Select Tags()\Param
            Case 1, 2 ; row of the parameters table
              TableRows + 1
              If TableRows = 1
                Html$ = "<h3>" + ParametersText$ + "</h3><table class='param'>" + #LF$
              EndIf
              If TableRows > 1
                Html$ = "</td></tr>"
              EndIf
              If Tags()\Param = 2
                OptionClass$ = " class='opt'"
              Else
                OptionClass$ = ""
              EndIf
              Html$ + "<tr" + OptionClass$ + "><td width='10%'><i>$p1</i></td><td width='90%'>"
            Case 3 ; end of the parameters table
              If TableRows
                Html$ = "</td></tr></table>"
                TableRows = 0
              EndIf
          EndSelect
          If Tag$ = "ExampleFile" And ExampleStarted = 0
            ExampleStarted = 1
            Html$ = "<h3>" + ExampleText$ + "</h3>"
          EndIf
          Html$ + Tags()\Html$

          ; --- parameters of the tag
          If FindString(Html$, "$")
            If FindString(Html$, "$ose")
              Param$ = ParserReadParam(@Parser, " " + #LF$)
              If Param$ = "All" Or Param$ = Settings\OsName$
                Html$ = ReplaceString(Html$, "$ose", "")
              Else
                Html$ = ""
                Parser\Position = FindString(Parser\Source$, #LF$, Parser\Position)
              EndIf
            EndIf
            If FindString(Html$, "$p1")
              Param$ = ParserReadParam(@Parser, ParserDelimiters$)
              Html$ = ReplaceString(Html$, "$p1", HtmlEscape(Param$))
            EndIf
            If FindString(Html$, "$p2")
              Param$ = ParserReadParam(@Parser, ParserDelimiters$)
              Html$ = ReplaceString(Html$, "$p2", HtmlEscape(Param$))
            EndIf
            If FindString(Html$, "$im")
              Param$ = ParserReadParam(@Parser, " " + #LF$)
              Image$ = ImageToHtml(Param$)
              If Image$ <> ""
                Html$ = ReplaceString(Html$, "$im", Image$)
              Else
                ParserError(@Parser, "image Not found: " + Param$)
              EndIf
            EndIf
            If FindString(Html$, "$ex")
              Parser\Position + 1
              Html$ = ReplaceString(Html$, "$ex", Str(ExampleNumber))
              ExampleNumber + 1
            EndIf
            If FindString(Html$, "$lg") Or FindString(Html$, "$lt") ; rest of the line (with / without the spaces around)
              Position = Parser\Position
              Parser\Position = FindString(Parser\Source$, #LF$, Parser\Position)
              Html$ = ReplaceString(Html$, "$lg", Mid(Parser\Source$, Position, Parser\Position - Position))
              Html$ = ReplaceString(Html$, "$lt", Trim(Mid(Parser\Source$, Position, Parser\Position - Position)))
            EndIf
          EndIf

          ; --- @OS: like DocMaker, the block of another OS is skipped up to the next @OS, @EndOS, @CommandList, @SupportedOS or @Function
          If LCase(Tag$) = "os"
            Position = Parser\Position
            Parser\Position = FindString(Parser\Source$ + #LF$, #LF$, Parser\Position)
            If LCase(Trim(Mid(Parser\Source$, Position, Parser\Position - Position))) <> LCase(Settings\OsName$)
              If LowerSource$ = ""
                LowerSource$ = LCase(Parser\Source$)
              EndIf
              FirstEnd = 0
              For Index = 1 To 5
                Position2 = FindString(LowerSource$, #LF$ + StringField("@os ,@endos,@commandlist,@supportedos,@function ", Index, ","), Parser\Position)
                If Position2 And (FirstEnd = 0 Or Position2 < FirstEnd)
                  FirstEnd = Position2
                EndIf
              Next
              If FirstEnd
                Parser\Position = FirstEnd
              Else
                Parser\Position = Len(Parser\Source$) + 1
              EndIf
            EndIf
          EndIf

          ParserAdd(@Parser, Html$, #AddRaw)

          ; --- tags that contain text up to their end tag
          If Tag$ = "Code"
            ChunkStart = Parser\Position
            Parser\Position = FindString(Parser\Source$, "@EndCode", Parser\Position, #PB_String_NoCase) - 1
            If Parser\Position = -1
              ParserError(@Parser, "missing : @EndCode")
              Break
            Else
              Parser\AddLineBreaks = #False
              If ColorCodeCallback
                ParserAdd(@Parser, ColorCodeCallback(Mid(Parser\Source$, ChunkStart, Parser\Position - ChunkStart)), #AddRaw)
              Else
                ParserAdd(@Parser, Mid(Parser\Source$, ChunkStart, Parser\Position - ChunkStart), #AddText)
              EndIf
            EndIf
          EndIf
          If Tag$ = "FormatIf"
            ChunkStart = Parser\Position
            Parser\Position = FindString(Parser\Source$, "@FormatEndIf", Parser\Position, #PB_String_NoCase) - 1
            If Parser\Position = -1
              ParserError(@Parser, "missing : @FormatEndIf")
              Break
            Else
              ParserAdd(@Parser, Mid(Parser\Source$, ChunkStart, Parser\Position - ChunkStart), #AddHtml)
            EndIf
          EndIf
          If Tag$ = "HTML"
            ChunkStart = Parser\Position
            Parser\Position = FindString(Parser\Source$, "@EndHTML", Parser\Position, #PB_String_NoCase) - 1
            If Parser\Position = -1
              ParserError(@Parser, "missing : @EndHTML")
              Break
            Else
              Parser\AddLineBreaks = #False
              ParserAdd(@Parser, Mid(Parser\Source$, ChunkStart, Parser\Position - ChunkStart), #AddHtml)
            EndIf
          EndIf
        Else ; unknown tag: shown as text
          ParserAdd(@Parser, "@" + Tag$, #AddText)
        EndIf
    EndSelect
    If Parser\Position < ChunkStart
      ParserError(@Parser, "undefined error (maybe line feed missing)")
      Break
    EndIf
  ForEver

  If ParserErrors$ <> ""
    Parser\Output$ = "<font class='note'>" + ReplaceString(ParserErrors$, #LF$, "<br>") + "</font>" + Parser\Output$
  EndIf
  If FindMapElement(OsInfo$(), Name$)
    OsNote$ = "<div class='note'>" + OsInfo$() + "</div>"
  EndIf
  Html$ = "<html><head><title>$titrepage</title><style>" + Theme\Colors$ + Theme\Style$ + "</style></head><body><h2><div class='t'>" + OsNote$ + *Page\Title$ + "<br>" +
          "<font class='nav'>" + *Page\Navigation$ + "</font></div></h2>"
  ProcedureReturn Html$ + #LF$ + Parser\Output$ + "</body></html>"
EndProcedure
