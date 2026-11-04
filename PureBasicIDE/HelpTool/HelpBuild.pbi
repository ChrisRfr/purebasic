; ----------------------------------------------------------------------------
;---------- Build ---------
; ----------------------------------------------------------------------------
; Tools to build the help from the DocMaker sources (--init, --initzip) and to check the help sources.
; Included inside Module pbhelp (EnableExplicit is active).

; Folder path with "/" separators and a trailing "/".
Procedure.s FolderPath(Path$)
  Path$ = ReplaceString(Path$, "\", "/")
  If Right(Path$, 1) <> "/"
    Path$ + "/"
  EndIf
  ProcedureReturn Path$
EndProcedure

; Converts the html contents page (reference.html) to the DocMaker format of the help (@Section, @Link, @<table...>).
Procedure.s ReferenceHtmlToDoc(Html$)
  Protected Position, NextLine, Index
  Protected Line$, Char$, Result$, Tag$, Attributes$, Text$, Link$

  Html$ = ReplaceString(Html$, #CR$, "")
  Html$ = ReplaceString(Html$, #TAB$, "")
  Repeat
    Position = NextLine + 1
    NextLine = FindString(Html$, #LF$, Position)
    If NextLine = 0
      Break
    EndIf
    Line$ = Trim(Mid(Html$, Position, NextLine - Position))
    Char$ = Mid(Line$, 1, 1)
    If Char$ = "<"
      Index = 1
      Repeat
        Index + 1
        Char$ = Mid(Line$, Index, 1)
      Until FindString(" >", Char$) Or Char$ = ""
      Tag$ = LCase(Mid(Line$, 2, Index - 2))
      Attributes$ = Mid(Line$, Index, FindString(Line$, ">") - Index)
      Text$ = StringBetween(Line$, ">", "<")
      Select Tag$
        Case "table", "tr", "td", "/table", "/tr", "/td"
          Result$ + "@<" + Tag$ + Attributes$ + ">" + #LF$
        Case "b"
          Result$ + "@Section " + Text$ + #LF$
        Case "a"
          If FindString(Line$, "href")
            If FindString(Line$, "/index")
              Link$ = "lib_" + StringBetween(Line$, "/", "/")
            Else
              Link$ = StringBetween(Line$, #DQUOTE$, ".")
            EndIf
            Result$ + "@Link " + Link$ + " " + #DQUOTE$ + Text$ + #DQUOTE$ + #LF$
          EndIf
      EndSelect
    EndIf
  ForEver
  ProcedureReturn ReplaceString(Result$, "<table", "<table style='all: unset;'")
EndProcedure

; Converts a source file of the documentation (DocMaker) to the format of the help (no @FormatIf / @LineBreak,
; one paragraph per line). Source and destination can be the same file. Returns #True if done.
Procedure DocFileConvert(Source$, Destination$)
  Protected File, Format, Pre, IsText, WasText, Ok, Position
  Protected Line$, Result$, FirstChar$, Char$, Tag$

  File = ReadFile(#PB_Any, Source$)
  If File = 0
    ProcedureReturn #False
  EndIf
  Format = ReadStringFormat(File)
  If Format = #PB_Ascii
    Format = #PB_UTF8 ; sources without BOM: UTF-8
  EndIf
  Ok = 1
  Repeat
    Line$ = ReadString(File, Format)
    FirstChar$ = Left(Line$, 1)
    If Pre = 0 And LCase(Left(LTrim(Line$), 13)) = "@examplefile " ; often indented: kept on its own line (read up to the end of the line)
      Line$ = LTrim(Line$)
      FirstChar$ = "@"
    EndIf
    If Trim(Line$) = "@LineBreak"
      FirstChar$ = " "
    EndIf
    If FirstChar$ = "@"
      Position = 1
      Tag$ = ""
      Char$ = ""
      Repeat
        Position + 1
        Tag$ + Char$
        Char$ = Mid(Line$, Position, 1)
      Until (FindString(ParserDelimiters$, Char$) And Tag$ + Char$ <> "</") Or Char$ = ""
      Tag$ = LCase(Tag$)
      Select Tag$
        Case "code", "fixedfont", "function", "syntax"
          Pre = 1
        Case "endcode", "endfixedfont", "description"
          Pre = 0
        Case "formatif"
          Line$ = "@HTML"
          Pre = 1
        Case "formatelse"
          Ok = 0
        Case "formatendif"
          Line$ = "@EndHTML"
          Ok = 1
          Pre = 0
      EndSelect
    EndIf
    WasText = IsText
    IsText = Bool(FindString("@;", FirstChar$) = 0)
    If Pre = 0
      Line$ = Trim(Line$)
    EndIf
    If LCase(Trim(Line$)) = "@indent"
      Line$ + #LF$
    EndIf
    If LCase(Trim(Line$)) = "@endindent"
      Line$ = #LF$ + Line$
    EndIf
    If Pre Or IsText = 0 Or WasText = 0
      Line$ = #LF$ + Line$
    Else
      Line$ = " " + Trim(Line$)
    EndIf
    Line$ = ReplaceString(Line$, "@LineBreak", #LF$)
    If Ok
      Result$ + Line$
    EndIf
  Until Eof(File)
  CloseFile(File)
  Result$ = ReplaceString(Result$, " " + #LF$, #LF$)
  If Ok = 0
    Debug "!!! @FormatEndIf missing: " + Source$
  EndIf
  ProcedureReturn FileWriteText(Destination$, Result$)
EndProcedure

; Builds the help folder from the sources of the documentation (--init). Returns the errors ("" if none).
Procedure.s BuildHelpFolder(Source$, Destination$)
  Protected Index
  Protected Errors$, Path$, File$, Text$, LanguageName$
  NewList Files$()

  Source$ = FolderPath(Source$)
  Destination$ = FolderPath(Destination$)
  If FileSize(Source$) <> -2
    ProcedureReturn "Help source not found: " + Source$ + #LF$
  EndIf
  If DirectoryCreateTree(Destination$) = 0
    ProcedureReturn "Can't create: " + Destination$ + #LF$
  EndIf

  For Index = 1 To CountString(#LanguageList$, ",") + 1
    LanguageName$ = StringField(#LanguageList$, Index, ",")
    If FileSize(Source$ + LanguageName$) <> -2
      Continue
    EndIf
    LanguageSet(LanguageName$)

    ; --- files converted to the format of the help (no @FormatIf / @LineBreak), ascii.txt -> asciitable.txt
    DirectoryListFiles(Files$(), Source$ + LanguageName$, "txt")
    ForEach Files$()
      File$ = Files$()
      If LCase(File$) = "reference/ascii.txt"
        File$ = GetPathPart(File$) + "asciitable.txt"
      EndIf
      DirectoryCreateTree(GetPathPart(Destination$ + LanguageName$ + "/" + File$))
      If DocFileConvert(Source$ + LanguageName$ + "/" + Files$(), Destination$ + LanguageName$ + "/" + File$) = #False
        Errors$ + "Can't convert: " + Source$ + LanguageName$ + "/" + Files$() + #LF$
      EndIf
    Next

    ; --- reference.html converted to the format of the help, with the "User library" section
    Path$ = Source$ + LanguageName$ + "/Reference/reference.html"
    If FileSize(Path$) > 0
      Text$ = "@Title " + Language(#TextGroup$, "Home") + #LF$ + ReferenceHtmlToDoc(FileReadText(Path$, #False))
      Text$ = InsertString(Text$, "@Section User library" + #LF$ + "$userlib" + #LF$, FindString(Text$, "@Section", FindString(Text$, "lib_texture")))
      Text$ = ReplaceString(Text$, "@Link ascii", "@Link asciitable")
      If FileWriteText(Destination$ + LanguageName$ + "/Reference/reference.txt", Text$) = #False
        Errors$ + "Can't write: " + Destination$ + LanguageName$ + "/Reference/reference.txt" + #LF$
      EndIf
    Else
      Errors$ + "Not found: " + Path$ + #LF$
    EndIf

    ; --- images
    Path$ = Source$ + LanguageName$ + "/Reference/Images"
    If FileSize(Path$) = -2 And CopyDirectory(Path$, Destination$ + LanguageName$ + "/Reference/Images", "", #PB_FileSystem_Recursive | #PB_FileSystem_Force) = 0
      Errors$ + "Can't copy: " + Path$ + #LF$
    EndIf
  Next

  If FileSize(Source$ + "HelpPictures") = -2 And CopyDirectory(Source$ + "HelpPictures", Destination$ + "HelpPictures", "", #PB_FileSystem_Recursive | #PB_FileSystem_Force) = 0
    Errors$ + "Can't copy: " + Source$ + "HelpPictures" + #LF$
  EndIf
  If CopyFile(Source$ + "OSSpecificFunctions.txt", Destination$ + "OSSpecificFunctions.txt") = 0
    Errors$ + "Can't copy: " + Source$ + "OSSpecificFunctions.txt" + #LF$
  EndIf
  ProcedureReturn Errors$
EndProcedure

; Same as BuildHelpFolder() but into the .zip archive Destination$ (--initzip). Returns the errors ("" if none).
Procedure.s BuildHelpZip(Source$, Destination$)
  Protected Pack
  Protected Temp$, Errors$
  NewList Files$()

  ; the help is built in a temporary folder, then compressed (relative paths with "/", at the root of the archive)
  Temp$ = GetTemporaryDirectory() + "PBHelp_" + Str(ElapsedMilliseconds()) + "/"
  Errors$ = BuildHelpFolder(Source$, Temp$)
  If FileSize(Temp$) = -2
    UseZipPacker()
    DirectoryCreateTree(GetPathPart(Destination$))
    Pack = CreatePack(#PB_Any, Destination$, #PB_PackerPlugin_Zip)
    If Pack
      DirectoryListFiles(Files$(), Temp$, "")
      ForEach Files$()
        If AddPackFile(Pack, Temp$ + Files$(), Files$()) = 0
          Errors$ + "Can't add to the archive: " + Files$() + #LF$
        EndIf
      Next
      ClosePack(Pack)
    Else
      Errors$ + "Can't create: " + Destination$ + #LF$
    EndIf
    DeleteDirectory(Temp$, "", #PB_FileSystem_Recursive | #PB_FileSystem_Force)
  EndIf
  ProcedureReturn Errors$
EndProcedure

; One-shot conversion IN PLACE of the documentation sources (dev tool, replaces listfilemef()). Returns the errors.
Procedure.s ConvertSources(Folder$)
  Protected Index
  Protected Errors$, Path$, Text$, LanguageName$
  NewList Files$()

  If MessageRequester("HelpTool", "This converts the help sources IN PLACE." + #LF$ + "Run it only once. Continue?", #PB_MessageRequester_YesNo | #PB_MessageRequester_Warning) <> #PB_MessageRequester_Yes
    ProcedureReturn ""
  EndIf
  Folder$ = FolderPath(Folder$)

  For Index = 1 To 3
    LanguageName$ = StringField(#LanguageList$, Index, ",")
    LanguageSet(LanguageName$)

    ; --- files converted to the new format (no @FormatIf / @LineBreak)
    DirectoryListFiles(Files$(), Folder$ + LanguageName$, "txt")
    ForEach Files$()
      If DocFileConvert(Folder$ + LanguageName$ + "/" + Files$(), Folder$ + LanguageName$ + "/" + Files$()) = #False
        Errors$ + "Can't convert: " + Folder$ + LanguageName$ + "/" + Files$() + #LF$
      EndIf
    Next

    ; --- reference.html -> reference.txt, with the "User library" section; ascii.txt -> asciitable.txt
    Path$ = Folder$ + LanguageName$ + "/Reference/reference.html"
    Text$ = "@Title " + Language(#TextGroup$, "Home") + #LF$ + ReferenceHtmlToDoc(FileReadText(Path$))
    Text$ = InsertString(Text$, "@Section User library" + #LF$ + "$userlib" + #LF$, FindString(Text$, "@Section", FindString(Text$, "lib_texture")))
    Text$ = ReplaceString(Text$, "@Link ascii", "@Link asciitable")
    Path$ = ReplaceString(Path$, ".html", ".txt")
    If FileWriteText(Path$, Text$) = #False
      Errors$ + "Can't write: " + Path$ + #LF$
    EndIf
    If RenameFile(Folder$ + LanguageName$ + "/Reference/ascii.txt", Folder$ + LanguageName$ + "/Reference/asciitable.txt") = 0
      Errors$ + "Can't rename: " + Folder$ + LanguageName$ + "/Reference/ascii.txt" + #LF$
    EndIf
  Next
  ProcedureReturn Errors$
EndProcedure

; Parses every page of the help source (folder or .zip) for the 3 languages (OS Windows) and returns the parse errors
; as a report (replaces CheckFile()).
Procedure.s CheckSources(Source$)
  Protected Index
  Protected Report$, LanguageName$

  SourceOpen(Source$)
  Settings\OsName$ = "Windows"
  For Index = 1 To 3
    LanguageName$ = StringField(#LanguageList$, Index, ",")
    Report$ + #LF$ + "================" + #LF$ + LanguageName$ + #LF$ + "================" + #LF$
    LanguageSet(LanguageName$)
    PagesLoad()
    ForEach Pages()
      PageToHtml(Pages()\Name$)
      If ParserErrors$ <> ""
        Report$ + "-------" + Pages()\File$ + "---" + Pages()\Name$ + #LF$ + ParserErrors$
      EndIf
    Next
    Report$ + #LF$ + "==============================" + Str(ListSize(Pages()))
  Next
  SourceClose()
  ProcedureReturn Report$
EndProcedure
