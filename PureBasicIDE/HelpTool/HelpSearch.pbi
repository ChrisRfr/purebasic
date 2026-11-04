; ----------------------------------------------------------------------------
;---------- Search ---------
; ----------------------------------------------------------------------------
; Search chips (filters by library) and ranked search. The logic is the one of the old code, only the names changed.
; Included inside Module pbhelp (EnableExplicit is active).

Declare ShowHtml(Html$)

; Html of a page with the text of the search string highlighted (the highlight is not part of PageToHtml()).
Procedure.s PageHtmlHighlighted(Name$)
  Protected Html$

  Html$ = PageToHtml(Name$)
  If IsGadget(Ui\Search)
    Html$ = HtmlHighlight(Html$, GetGadgetText(Ui\Search))
  EndIf
  ProcedureReturn Html$
EndProcedure

;- Chips

; Places the chips line by line (vertical scrollbar only if they do not fit).
Procedure ChipsLayout()
  Protected x, y, Pass, AreaWidth, AreaHeight, InnerWidth, InnerHeight, Dummy
  Protected Pad = 2, Gap = 2 ; or a little more space between the buttons with Pad = 3, Gap = 3
  Static ScrollbarWidth

  If IsGadget(Ui\Chips) = 0
    ProcedureReturn
  EndIf
  If ScrollbarWidth = 0
    ; scrollbar width = required size of a vertical scrollbar (logical units)
    Dummy = ScrollBarGadget(#PB_Any, -10, 0, 0, 100, 0, 1, 1, #PB_ScrollBar_Vertical)
    ScrollbarWidth = GadgetWidth(Dummy, #PB_Gadget_RequiredSize)
    FreeGadget(Dummy)
  EndIf

  AreaWidth = GadgetWidth(Ui\Chips)
  AreaHeight = GadgetHeight(Ui\Chips)
  For Pass = 0 To 1 ; pass 0: no vertical scrollbar, pass 1: room reserved for it
    InnerWidth = AreaWidth - 2 * Pad - 4 - Pass * ScrollbarWidth
    x = Pad
    y = Pad
    ForEach Chips()
      If x + Chips()\Width > InnerWidth And x > Pad
        x = Pad
        y + Ui\ChipHeight + Gap
      EndIf
      ResizeGadget(Chips()\Gadget, x, y, Chips()\Width, Ui\ChipHeight)
      x + Chips()\Width + Gap
    Next
    InnerHeight = y + Ui\ChipHeight + Pad
    If InnerHeight <= AreaHeight
      Break
    EndIf
  Next
  SetGadgetAttribute(Ui\Chips, #PB_ScrollArea_InnerWidth, InnerWidth + 2 * Pad)
  SetGadgetAttribute(Ui\Chips, #PB_ScrollArea_InnerHeight, InnerHeight)
EndProcedure

; Relays out the chips when the size of the area (resized by the dialog) has changed; called on every possible resize.
Procedure ChipsPlace(Force = #False)
  Protected w, h
  Static ChipsW, ChipsH

  If IsGadget(Ui\Chips) = 0
    ProcedureReturn
  EndIf
  w = GadgetWidth(Ui\Chips)
  h = GadgetHeight(Ui\Chips)
  If w < 20 Or h < 10 ; panel not shown yet
    ChipsW = -1
    ProcedureReturn
  EndIf
  If Force Or w <> ChipsW Or h <> ChipsH
    ChipsW = w
    ChipsH = h
    ChipsLayout()
  EndIf
EndProcedure

; (Re)creates the chips: one per library + Reference, from the loaded pages.
Procedure ChipsBuild()
  Protected Dummy
  Protected LibName$
  NewMap LibraryOfFile$()
  NewMap LibraryNames.i()

  If IsGadget(Ui\Chips) = 0
    ProcedureReturn
  EndIf
  ForEach Chips() ; only the buttons: the scroll area belongs to the dialog
    If IsGadget(Chips()\Gadget)
      FreeGadget(Chips()\Gadget)
    EndIf
  Next
  ClearList(Chips())

  ; library of a file = title of its lib_ page
  ForEach Pages()
    If Left(Pages()\Name$, 4) = "lib_" And Pages()\UserLib$ = ""
      LibraryOfFile$(Pages()\File$) = Pages()\Title$
    EndIf
  Next
  ForEach Pages()
    If Pages()\UserLib$ <> ""
      Pages()\Group$ = Pages()\UserLib$
    ElseIf FindMapElement(LibraryOfFile$(), Pages()\File$)
      Pages()\Group$ = LibraryOfFile$()
    Else
      Pages()\Group$ = #GroupReference$
    EndIf
    LibraryNames(Pages()\Group$) = 1
  Next

  ; order: All, Reference, then the libraries alphabetically
  ForEach LibraryNames()
    LibName$ = MapKey(LibraryNames())
    If LibName$ <> #GroupReference$
      AddElement(Chips())
      Chips()\Name$ = LibName$
    EndIf
  Next
  SortStructuredList(Chips(), #PB_Sort_Ascending | #PB_Sort_NoCase, OffsetOf(ChipInfo\Name$), #PB_String)
  If FindMapElement(LibraryNames(), #GroupReference$)
    AddElement(Chips())
    MoveElement(Chips(), #PB_List_First)
    Chips()\Name$ = #GroupReference$
  EndIf
  AddElement(Chips())
  MoveElement(Chips(), #PB_List_First)
  Chips()\Name$ = "All"
  Chips()\IsAll = #True

  ForEach Chips()
    If Chips()\IsAll
      Chips()\Caption$ = Language(#TextGroup$, "All")
    ElseIf Chips()\Name$ = #GroupReference$
      Chips()\Caption$ = Language(#TextGroup$, "Reference")
    Else
      Chips()\Caption$ = Chips()\Name$
    EndIf
  Next

  OpenGadgetList(Ui\Chips)
  ; chip size = required size of a button with the small font
  If Ui\ChipFont = 0
    Ui\ChipFont = LoadFont(#PB_Any, #ChipFontName$, #ChipFontSize)
  EndIf
  Dummy = ButtonGadget(#PB_Any, 0, 0, 0, 0, "Abc")
  If Ui\ChipFont
    SetGadgetFont(Dummy, FontID(Ui\ChipFont))
  EndIf
  Ui\ChipHeight = GadgetHeight(Dummy, #PB_Gadget_RequiredSize)
  ForEach Chips()
    SetGadgetText(Dummy, Chips()\Caption$)
    Chips()\Width = GadgetWidth(Dummy, #PB_Gadget_RequiredSize)
  Next
  FreeGadget(Dummy)

  ; the buttons go inside the scroll area created by the dialog
  ForEach Chips()
    Chips()\Gadget = ButtonGadget(#PB_Any, 0, 0, Chips()\Width, Ui\ChipHeight, Chips()\Caption$, #PB_Button_Toggle)
    If Ui\ChipFont
      SetGadgetFont(Chips()\Gadget, FontID(Ui\ChipFont))
    EndIf
    If Chips()\IsAll
      SetGadgetState(Chips()\Gadget, 1) ; All pressed: no library selected
    EndIf
  Next
  CloseGadgetList()
  If ApplyColorsCallback
    ApplyColorsCallback(Ui\Chips)
  EndIf
  ChipsPlace(#True)
EndProcedure

;- Search

; Fills the result list: all words must match, sorted by rank, filtered by the checked chips.
Procedure SearchRun(Clear = #False)
  Protected n, Rank, Ok, AllIn
  Protected *Page.PageInfo
  Protected Text$, Phrase$, Word$
  NewList Results.ResultInfo()
  NewList Words$()
  NewMap SelectedGroups.i()

  Text$ = Trim(GetGadgetText(Ui\Search))
  If Len(Text$) < 3 ; text too short: only the chips filter, no search in the sources
    Text$ = ""
  EndIf
  ForEach Chips()
    If Chips()\IsAll = 0 And GetGadgetState(Chips()\Gadget)
      SelectedGroups(Chips()\Name$) = 1
    EndIf
  Next
  If Text$ = "" And MapSize(SelectedGroups()) = 0 ; nothing to search or filter: keep the list (cleared if Clear)
    If Clear
      ClearGadgetItems(Ui\Results)
    EndIf
    ProcedureReturn
  EndIf

  ; words (all required) and normalized phrase
  For n = 1 To CountString(Text$, " ") + 1
    Word$ = LCase(StringField(Text$, n, " "))
    If Word$ <> ""
      AddElement(Words$())
      Words$() = Word$
      Phrase$ + Word$ + " "
    EndIf
  Next
  Phrase$ = Trim(Phrase$)

  ForEach Pages()
    *Page = @Pages()
    If MapSize(SelectedGroups()) = 0 Or FindMapElement(SelectedGroups(), *Page\Group$)
      Word$ = LCase(*Page\Title$) ; (title, lowercase)
      Ok = #True
      Rank = 9 ; rank (9 = least)
      ForEach Words$() ; each word in the title or in the page source
        If FindString(Word$, Words$()) = 0 And FindString(*Page\Source$, Words$(), 1, #PB_String_NoCase) = 0
          Ok = #False
          Break
        EndIf
      Next
      If Ok And ListSize(Words$())
        ; rank (0 = best): exact name 0, name starts with 1, name contains 2, all words in the name 3, keyword (@Keyword) 4, rest (description...) 5
        If Word$ = Phrase$
          Rank = 0
        ElseIf Left(Word$, Len(Phrase$)) = Phrase$
          Rank = 1
        ElseIf FindString(Word$, Phrase$)
          Rank = 2
        Else
          AllIn = #True
          ForEach Words$()
            If FindString(Word$, Words$()) = 0
              AllIn = #False
              Break
            EndIf
          Next
          FirstElement(Words$())
          If AllIn
            Rank = 3
          ElseIf FindString(*Page\Source$, "@Keyword " + Words$(), 1, #PB_String_NoCase)
            Rank = 4
          EndIf
        EndIf
      EndIf
      If Ok
        AddElement(Results())
        Results()\Page = *Page
        Results()\Key$ = Str(Rank) + Word$ + #LF$ + *Page\Name$
      EndIf
    EndIf
  Next

  SortStructuredList(Results(), #PB_Sort_Ascending, OffsetOf(ResultInfo\Key$), #PB_String)
  HideGadget(Ui\Results, 1)
  ClearGadgetItems(Ui\Results)
  n = 0
  ForEach Results()
    AddGadgetItem(Ui\Results, -1, Results()\Page\Title$)
    SetGadgetItemData(Ui\Results, n, Results()\Page)
    n + 1
  Next
  HideGadget(Ui\Results, 0)
EndProcedure

; The search text changed: updates the highlight of the displayed page and the results.
Procedure SearchChanged(EventType)
  If EventType = #PB_EventType_Change
    If View\PageName$ <> "" ; updates (or clears) the highlight of the displayed page
      ShowHtml(PageHtmlHighlighted(View\PageName$))
    EndIf
    SearchRun()
  EndIf
EndProcedure

; Click on a chip: All clears the selection, otherwise All is pressed only if nothing is selected.
Procedure ChipClick(Gadget)
  Protected Found, IsAll, Selected

  ForEach Chips()
    If Chips()\Gadget = Gadget
      Found = #True
      IsAll = Chips()\IsAll
      Break
    EndIf
  Next
  If Found = 0
    ProcedureReturn
  EndIf
  If IsAll
    ForEach Chips()
      If Chips()\IsAll = 0
        SetGadgetState(Chips()\Gadget, 0)
      EndIf
    Next
  EndIf
  ForEach Chips()
    If Chips()\IsAll = 0 And GetGadgetState(Chips()\Gadget)
      Selected + 1
    EndIf
  Next
  ForEach Chips()
    If Chips()\IsAll
      SetGadgetState(Chips()\Gadget, Bool(Selected = 0))
    EndIf
  Next
  SearchRun(#True)
EndProcedure

; Filters hidden: the results list takes the height of the chips area (the dialog keeps the space of a hidden gadget).
Procedure FiltersFit()
  Protected Height

  If View\FiltersVisible Or IsGadget(Ui\Chips) = 0 Or IsGadget(Ui\Results) = 0 Or IsGadget(Ui\Panel) = 0
    ProcedureReturn
  EndIf
  Height = GetGadgetAttribute(Ui\Panel, #PB_Panel_ItemHeight) - View\FiltersMargin - GadgetY(Ui\Results)
  If Height > 40
    ResizeGadget(Ui\Results, #PB_Ignore, #PB_Ignore, #PB_Ignore, Height)
  EndIf
EndProcedure

; Shows or hides the chips (whole scroll area). Hidden = no filter: All is selected and the results are refreshed.
Procedure FiltersShow(Visible)
  If IsGadget(Ui\Chips) = 0
    ProcedureReturn
  EndIf
  View\FiltersVisible = Visible
  If IsGadget(Ui\ToggleFilters)
    SetGadgetState(Ui\ToggleFilters, Visible)
  EndIf
  If Visible
    HideGadget(Ui\Chips, 0)
    RefreshDialog(Ui\Dialog) ; the dialog gives the space back to the chips area
    ChipsPlace(#True)
  Else
    ForEach Chips()
      SetGadgetState(Chips()\Gadget, Bool(Chips()\IsAll))
    Next
    SearchRun(#True)
    View\FiltersMargin = GetGadgetAttribute(Ui\Panel, #PB_Panel_ItemHeight) - (GadgetY(Ui\Chips) + GadgetHeight(Ui\Chips)) ; space under the chips
    HideGadget(Ui\Chips, 1)
    FiltersFit()
  EndIf
EndProcedure
