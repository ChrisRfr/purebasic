; ----------------------------------------------------------------------------
;---------- Text ---------
; ----------------------------------------------------------------------------
; String helpers and translations.
; Included inside Module pbhelp (EnableExplicit is active).

; ----------------------------------------------------------------------------
;- String helpers
; ----------------------------------------------------------------------------

; Position of the last occurrence of Find$ at or before Position (0 = from the end), 0 if none.
Procedure StringFindReverse(Text$, Find$, Position = 0)
  Protected Length = Len(Find$)

  If Position = 0
    Position = Len(Text$)
  EndIf
  While Position > 0 And Mid(Text$, Position, Length) <> Find$
    Position - 1
  Wend
  ProcedureReturn Position
EndProcedure

; Text between the first Before$ found after Start and the next After$ (up to the end if After$ is missing).
; The search of After$ starts just after the first character of Before$ (as in the old Stringparse).
Procedure.s StringBetween(Text$, Before$, After$, Start = 0)
  Protected First, Last

  First = FindString(Text$, Before$, Start + 1)
  If First = 0
    ProcedureReturn ""
  EndIf
  Last = FindString(Text$, After$, First + 1)
  If Last = 0
    Last = Len(Text$)
  EndIf
  First + Len(Before$)
  If Last <= First
    ProcedureReturn ""
  EndIf
  ProcedureReturn Mid(Text$, First, Last - First)
EndProcedure

; Escapes "<" and ">" for HTML; with LineBreaks, every line feed also gets a <br> before it.
Procedure.s HtmlEscape(Text$, LineBreaks = #False)
  Text$ = ReplaceString(Text$, "<", "&lt;")
  Text$ = ReplaceString(Text$, ">", "&gt;")
  If LineBreaks
    Text$ = ReplaceString(Text$, #LF$, "<br>" + #LF$)
  EndIf
  ProcedureReturn Text$
EndProcedure

; ----------------------------------------------------------------------------
;- Translations (same interface as the IDE: Language(Group$, Key$))
; ----------------------------------------------------------------------------

Global NewMap Catalog$() ; "Group/Key" -> text in the current language

; Reads one block of HelpCatalog.pbi (the data pointer must be set with Restore) into Catalog$().
Procedure CatalogReadBlock()
  Protected Line$, Group$, Position

  Repeat
    Read.s Line$
    Line$ = Trim(Line$)
    If Line$ = ""
      Break
    EndIf
    If Left(Line$, 1) = "["
      Group$ = Mid(Line$, 2, Len(Line$) - 2)
    ElseIf Left(Line$, 1) <> ";"
      Position = FindString(Line$, "=")
      If Position
        Catalog$(Group$ + "/" + Trim(Left(Line$, Position - 1))) = Trim(Mid(Line$, Position + 1))
      EndIf
    EndIf
  ForEver
EndProcedure

; Loads the texts of a language (English first, so a missing key falls back to English).
Procedure LanguageSet(LanguageName$)
  ClearMap(Catalog$())
  Restore Catalog_English
  CatalogReadBlock()
  Select LanguageName$
    Case "French"  : Restore Catalog_French  : CatalogReadBlock()
    Case "German"  : Restore Catalog_German  : CatalogReadBlock()
    Case "Italian" : Restore Catalog_Italian : CatalogReadBlock()
    Case "Spanish" : Restore Catalog_Spanish : CatalogReadBlock()
    Case "Russian" : Restore Catalog_Russian : CatalogReadBlock()
  EndSelect
  Settings\Language$ = LanguageName$
EndProcedure

; Text of Key$ in the section Group$ of the current language (the key itself if it is unknown).
Procedure.s Language(Group$, Key$)
  If LanguageCallback ; IDE: the texts are in the language files of the IDE ([HelpTool] section)
    ProcedureReturn LanguageCallback(Group$, Key$)
  EndIf
  If FindMapElement(Catalog$(), Group$ + "/" + Key$)
    ProcedureReturn Catalog$()
  EndIf
  ProcedureReturn Key$
EndProcedure
