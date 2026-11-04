; ----------------------------------------------------------------------------
;---------- Pages ---------
; ----------------------------------------------------------------------------
; Pages of the help: extraction from the source files, generated pages, loading.
; Included inside Module pbhelp (EnableExplicit is active).

; Link to a page of the help; "$" in Text$ is replaced by the title of the page.
Procedure.s PageLink(Reference$, Text$ = "$")
  Protected Title$

  Reference$ = LCase(Reference$)
  If FindMapElement(*PageByName(), Reference$)
    Title$ = *PageByName()\Title$
  EndIf
  ProcedureReturn "<a href='#' onclick='jsmessage(" + #DQUOTE$ + "lk:" + Reference$ + #DQUOTE$ + ")'>" + ReplaceString(Text$, "$", Title$) + "</a>"
EndProcedure

; Adds a page built from the other pages (like DocMaker does).
Procedure PageAddGenerated(Name$, Title$, Source$)
  LastElement(Pages())
  AddElement(Pages())
  Pages()\Name$ = Name$
  Pages()\Title$ = Title$
  Pages()\Source$ = Source$
  *PageByName(Name$) = @Pages()
EndProcedure

; Reads a help file and adds its pages: the page of the file (library or guide), then one page per @Function.
Procedure PagesFromFile(File$, IsUserLib = #False)
  Protected PageCount, Index, Start, NextStart, Position, Position2, Finished
  Protected *LibraryPage.PageInfo
  Protected Text$, Name$, Title$, Prefix$, FileName$, FunctionName$, FunctionList$, PageText$, Line$, Navigation$, LibDest$
  NewList Functions$()

  FileName$ = GetFilePart(File$, #PB_FileSystem_NoExtension)
  If IsUserLib
    Text$ = FileReadText(Settings\UserLibPath$ + File$)
  Else
    Text$ = SourceReadText(LanguageFolder() + File$)
  EndIf

  Position = FindString(Text$, "@Title ")
  If Position = 0
    Position = FindString(Text$, "@Library ")
    Prefix$ = "lib_"
  EndIf
  If Position = 0 ; not a help file (ie: a readme in the userlib folder)
    ProcedureReturn
  EndIf
  Position = FindString(Text$, " ", Position) + 1
  Position2 = FindString(Text$, #LF$, Position)
  If Position2 = 0
    Position2 = Len(Text$) + 1
  EndIf
  Title$ = Trim(Mid(Text$, Position, Position2 - Position))
  NextStart = Position2 + 1

  Repeat
    Start = NextStart
    NextStart = FindString(Text$, "@Function ", Start + 1)
    If NextStart = 0
      NextStart = Len(Text$) + 1
      Finished = #True
    EndIf
    PageText$ = Mid(Text$, Start, NextStart - Start)
    LastElement(Pages())
    AddElement(Pages())

    If PageCount = 0 ; the page of the file
      Name$ = Prefix$ + LCase(FileName$)
      *LibraryPage = @Pages()
    Else ; a function: "@Function Name(" on the first line
      Line$ = Left(PageText$, FindString(PageText$, #LF$))
      Line$ = ReplaceString(Line$, "(d)", "")
      Line$ = ReplaceString(Line$, "(.d)", "") ; bug math
      Position = FindString(Line$, "(")
      Position2 = StringFindReverse(Line$, " ", Position)
      FunctionName$ = Mid(Line$, Position2 + 1, Position - Position2 - 1)
      Title$ = FunctionName$
      Name$ = LCase(FunctionName$)
      Position = FindString(PageText$, "@LibraryDestination")
      If Position
        LibDest$ = StringBetween(PageText$, "tion", #LF$, Position)
        PageText$ = ReplaceString(PageText$, "@LibraryDestination" + LibDest$ + #LF$, "")
        UserLibDest$(Name$) = LCase(Trim(LibDest$))
      Else
        LibDest$ = ""
      EndIf
      AddElement(Functions$())
      Functions$() = Name$
    EndIf

    Pages()\Title$ = Title$
    Pages()\File$ = File$
    Pages()\Position = Start
    Pages()\Source$ = PageText$
    Pages()\Name$ = Name$
    If IsUserLib
      Pages()\UserLib$ = FileName$
      Pages()\LibDest$ = LibDest$
    EndIf
    *PageByName(Name$) = @Pages()
    PageCount + 1
  Until Finished

  ; --- list of the functions on the library page (+ the functions of other user libraries attached to this one)
  ForEach UserLibDest$()
    If UserLibDest$() = LCase(FileName$)
      AddElement(Functions$())
      Functions$() = MapKey(UserLibDest$())
    EndIf
  Next
  SortList(Functions$(), #PB_Sort_Ascending)
  ForEach Functions$()
    FunctionList$ + "@@" + Functions$() + #LF$
    AddElement(*LibraryPage\SubPages())
    *LibraryPage\SubPages() = *PageByName(Functions$())
  Next
  *LibraryPage\Source$ = ReplaceString(*LibraryPage\Source$, "@CommandList", "@CommandList" + #LF$ + FunctionList$)

  ; --- navigation of the function pages: < previous | library index | next >
  Index = 0
  ForEach Functions$()
    Navigation$ = ""
    Index + 1
    If Index > 1
      Navigation$ + "< " + PageLink(Mid(StringField(FunctionList$, Index - 1, #LF$), 3))
    EndIf
    Navigation$ + " | " + PageLink("lib_" + FileName$, "$ Index") + " | "
    If Index < PageCount - 1
      Navigation$ + PageLink(Mid(StringField(FunctionList$, Index + 1, #LF$), 3)) + " >"
    EndIf
    If FindMapElement(*PageByName(), Functions$())
      *PageByName()\Navigation$ = Navigation$
    EndIf
  Next
EndProcedure

; Background color of a cell of the OS table: orange "(OS)", green supported, red not supported.
Procedure.s OsTableColor(OsList$, OsName$)
  If FindString(OsList$, "(" + OsName$ + ")")
    ProcedureReturn "bgcolor=#fb0"
  ElseIf FindString(OsList$, OsName$)
    ProcedureReturn "bgcolor=#0f0"
  EndIf
  ProcedureReturn "bgcolor=#f00"
EndProcedure

; Builds the pages made from the other pages: osspecific, commandindex and pbconstants (replaces pagesgenerees()).
Procedure PagesGenerate()
  Protected Position, PrevPosition, ColonPosition, ConstantStart, ConstantEnd
  Protected *SubPage.PageInfo
  Protected Text$, Line$, Key$, Value$, Info$, OsList$, FunctionName$, Letter$, Constant$, Source$, LibraryTitle$, Char$
  NewList OsFunctions$()
  NewList Entries$()
  NewMap ConstantPages$()
  NewMap Seen.i()

  ; --- OSSpecificFunctions.txt (PureBasic format): "function: OS list" lines grouped by "#StartGroup: information"
  ClearMap(OsInfo$())
  Text$ = RemoveString(SourceReadText("OSSpecificFunctions.txt"), #CR$) + #LF$
  Repeat
    PrevPosition = Position
    Position = FindString(Text$, #LF$, Position + 1)
    If Position = 0
      Break
    EndIf
    Line$ = Trim(Trim(Mid(Text$, PrevPosition + 1, Position - PrevPosition - 1)), #TAB$)
    If Len(Line$) > 0 And Left(Line$, 1) <> ";"
      ColonPosition = FindString(Line$ + ":", ":")
      Key$ = Trim(Left(Line$, ColonPosition - 1))
      Value$ = Trim(Mid(Line$, ColonPosition + 1))
      Select LCase(Key$)
        Case "#library"
        Case "#startgroup"
          Info$ = Value$
        Case "#endgroup"
        Default
          If Value$ <> ""
            Info$ = Value$
          EndIf
          AddElement(OsFunctions$())
          OsFunctions$() = Key$ + #TAB$ + ReplaceString(Info$, "-", #TAB$)
          OsInfo$(LCase(Key$)) = Info$
      EndSelect
    EndIf
  ForEver

  ; --- table of the functions that are not on all the OS
  SortList(OsFunctions$(), #PB_Sort_Ascending | #PB_Sort_NoCase)
  Text$ = "@<table border=1>" + #LF$
  ForEach OsFunctions$()
    FunctionName$ = StringField(OsFunctions$(), 1, #TAB$)
    OsList$ = StringField(OsFunctions$(), 2, #TAB$)
    Info$ = StringField(OsFunctions$(), 3, #TAB$)
    Text$ + " @<tr> @<td> " + "@@" + FunctionName$ + " @</td> " +
            "@<td " + OsTableColor(OsList$, "Windows") + "> windows @</td> " +
            "@<td " + OsTableColor(OsList$, "Linux") + "> Linux @</td> " +
            "@<td " + OsTableColor(OsList$, "MacOS") + "> Mac @</td> " +
            "@<td> " + Info$ + " @</td> @</tr>" + #LF$
  Next
  Text$ + "@</table>"

  ; --- list of the functions of the libraries, and PureBasic constants (@#PB_xxx) with the pages that use them
  ForEach Pages()
    If Pages()\UserLib$ <> ""
      Continue
    EndIf
    If Left(Pages()\Name$, 4) = "lib_"
      LibraryTitle$ = Pages()\Title$
      ForEach Pages()\SubPages()
        *SubPage = Pages()\SubPages()
        If *SubPage\UserLib$ = ""
          AddElement(Entries$())
          Entries$() = *SubPage\Title$ + #TAB$ + *SubPage\Name$ + #TAB$ + LibraryTitle$
        EndIf
      Next
    EndIf
    Position = 0
    Source$ = Pages()\Source$
    Repeat
      Position = FindString(Source$, "@#PB_", Position + 1)
      If Position = 0
        Break
      EndIf
      ConstantEnd = Position + 1
      Repeat
        ConstantEnd + 1
        Char$ = Mid(Source$, ConstantEnd, 1)
      Until Char$ = "" Or FindString(#IdentifierChars$, Char$) = 0
      Constant$ = Mid(Source$, Position + 1, ConstantEnd - Position - 1)
      If FindMapElement(Seen(), Constant$ + #TAB$ + Pages()\Name$) = 0
        Seen(Constant$ + #TAB$ + Pages()\Name$) = 1
        If FindMapElement(ConstantPages$(), Constant$)
          ConstantPages$() + ", "
        Else
          AddMapElement(ConstantPages$(), Constant$)
        EndIf
        ConstantPages$() + "@@" + Pages()\Name$
      EndIf
    ForEver
  Next

  PageAddGenerated("osspecific", Language(#TextGroup$, "OsFunctions"), Text$)

  SortList(Entries$(), #PB_Sort_Ascending | #PB_Sort_NoCase)
  Text$ = ""
  Letter$ = ""
  ForEach Entries$()
    If UCase(Left(Entries$(), 1)) <> Letter$
      Letter$ = UCase(Left(Entries$(), 1))
      Text$ + "@Section " + Letter$ + #LF$
    EndIf
    Text$ + "@@" + StringField(Entries$(), 2, #TAB$) + " - " + StringField(Entries$(), 3, #TAB$) + #LF$
  Next
  PageAddGenerated("commandindex", Language(#TextGroup$, "CommandIndex"), Text$)

  ClearList(Entries$())
  ForEach ConstantPages$()
    AddElement(Entries$())
    Entries$() = MapKey(ConstantPages$())
  Next
  SortList(Entries$(), #PB_Sort_Ascending | #PB_Sort_NoCase)
  Text$ = ""
  Letter$ = ""
  ForEach Entries$()
    If UCase(Mid(Entries$(), 5, 1)) <> Letter$ ; letter after "#PB_"
      Letter$ = UCase(Mid(Entries$(), 5, 1))
      Text$ + "@Section " + Letter$ + #LF$
    EndIf
    Text$ + "@" + Entries$() + " : " + ConstantPages$(Entries$()) + #LF$
  Next
  PageAddGenerated("pbconstants", Language(#TextGroup$, "Constants"), Text$)
EndProcedure

; Loads all the pages of the current language and OS (Settings\Language$, Settings\OsName$, the source must be open,
; LanguageSet() done). Returns #False if the help source is not found. The UI part of the old initFichier() is not here.
Procedure PagesLoad()
  Protected *Reference.PageInfo
  Protected Links$, LibName$
  NewList Files$()
  NewList UserLibs$()

  ClearMap(*PageByName())
  ClearMap(UserLibDest$())
  ClearList(Pages())
  TagsInit()

  ; --- user libraries, then the sources
  If Settings\UserLibPath$ <> "" And FileSize(Settings\UserLibPath$) = -2
    DirectoryListFiles(Files$(), Settings\UserLibPath$, "txt")
    ForEach Files$()
      PagesFromFile(Files$(), #True)
    Next
    CopyList(Files$(), UserLibs$())
  EndIf
  SourceList(Files$(), LanguageFolder(), "txt")
  ForEach Files$()
    PagesFromFile(Files$())
  Next

  If FindMapElement(*PageByName(), "reference") = 0 ; help source not found
    ProcedureReturn #False
  EndIf
  *Reference = *PageByName() ; to copy now: PagesGenerate() changes the current element of the map
  PagesGenerate() ; before the contents, which refers to them

  ; --- user libraries in the contents ("$userlib" line of the reference page)
  ForEach UserLibs$()
    LibName$ = GetFilePart(UserLibs$(), #PB_FileSystem_NoExtension)
    Links$ + "@Link lib_" + LCase(LibName$) + " " + #DQUOTE$ + LibName$ + #DQUOTE$ + #LF$
  Next
  If Links$ = "" ; no user library: no empty section
    *Reference\Source$ = ReplaceString(*Reference\Source$, "@Section User library" + #LF$, "")
  EndIf
  *Reference\Source$ = ReplaceString(*Reference\Source$, "$userlib" + #LF$, Links$)
  ProcedureReturn #True
EndProcedure

; Contents outline: the "@Section" and "@Link" lines of the reference page, as "Title" or "Title<TAB>page".
Procedure PagesOutline(List Outline$())
  Protected Position
  Protected Text$

  ClearList(Outline$())
  If FindMapElement(*PageByName(), "reference") = 0
    ProcedureReturn
  EndIf
  Text$ = *PageByName()\Source$
  Repeat
    Position = FindString(Text$, "@", Position + 1)
    If Position = 0
      Break
    EndIf
    Select StringBetween(Text$, "@", " ", Position - 1)
      Case "Section"
        AddElement(Outline$())
        Outline$() = StringBetween(Text$, "Section ", #LF$, Position)
      Case "Link"
        AddElement(Outline$())
        Outline$() = StringBetween(Text$, " " + #DQUOTE$, #DQUOTE$ + #LF$, Position) + #TAB$ + StringBetween(Text$, "Link ", " " + #DQUOTE$, Position)
    EndSelect
  ForEver
EndProcedure
