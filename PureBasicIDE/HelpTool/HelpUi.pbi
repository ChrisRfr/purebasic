; ----------------------------------------------------------------------------
;---------- Ui ---------
; ----------------------------------------------------------------------------
; User interface: page display, Dialog, events, standalone window and IDE API.
; Included inside Module pbhelp (EnableExplicit is active). #Standalone is defined by HelpTool.pb.

; Initial values
View\Zoom = 1.0
View\BarWidth = -1 ; not measured yet
Ui\ToggleContents = -1

;- Page display

; Shows an html page in the WebView. The zoom (CSS) and the keys/mouse buttons are handled by the page itself.
Procedure ShowHtml(Html$)
  Html$ = ReplaceString(Html$, "<head>", "<head><meta charset='utf-8'>", #PB_String_CaseSensitive, 1, 1) ; explicit encoding (accents, umlauts)
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    If View\IeMode
      SetGadgetItemText(Ui\Web, #PB_Web_HtmlCode, HtmlForIe(Html$))
      ProcedureReturn
    EndIf
  CompilerEndIf
  ; Zoom (Ctrl+wheel, Ctrl +/-/0) is done by the page (CSS zoom), because the native zoom is lost when another page is loaded;
  ; the factor is sent to JsAction() and injected in each new page. Mouse back/forward buttons and Alt+arrows use our own history
  ; (not the one of the WebView, which goes back to an old page, sometimes empty). Escape closes the help.
  Html$ = ReplaceString(Html$, "<head>","<head><script>"+
                   "function nav(e,s) {e.preventDefault(); jsmessage('lk:'+s);}"+
                   "window.addEventListener('mousedown', function(e) {if (e.button==3 || e.button==4) e.preventDefault();});"+
                   "window.addEventListener('mouseup', function(e) {if (e.button==3) nav(e,'-'); else if (e.button==4) nav(e,'+');});"+
                   "window.addEventListener('keydown', function(e) {if ((e.altKey && e.key=='ArrowLeft') || e.key=='BrowserBack') nav(e,'-'); else if ((e.altKey && e.key=='ArrowRight') || e.key=='BrowserForward') nav(e,'+');});"+
                   "var pbzoom="+StrF(View\Zoom, 2)+"; document.documentElement.style.zoom=pbzoom;"+
                   "function pbzoomset(v) {pbzoom=Math.min(3,Math.max(0.5,Math.round(v*100)/100)); document.documentElement.style.zoom=pbzoom; jsmessage('zm:'+pbzoom);}"+
                   "window.addEventListener('wheel', function(e) {if (e.ctrlKey) {e.preventDefault(); pbzoomset(e.deltaY<0 ? pbzoom*1.1 : pbzoom/1.1);}}, {passive:false});"+
                   "window.addEventListener('keydown', function(e) {if (e.ctrlKey && !e.altKey) {if (e.key=='+' || e.key=='=') {e.preventDefault(); pbzoomset(pbzoom*1.1);} else if (e.key=='-') {e.preventDefault(); pbzoomset(pbzoom/1.1);} else if (e.key=='0') {e.preventDefault(); pbzoomset(1);}}});"+
                   "var fv=function() {document.documentElement.style.setProperty('--vw', document.documentElement.clientWidth+'px');}; fv(); window.addEventListener('resize', fv);"+
                   "window.addEventListener('keydown', function(e) {if (e.key=='Escape') {e.preventDefault(); jsmessage('es:');}});"+
                   "</script>", #PB_String_CaseSensitive, 1, 1)
  SetGadgetItemText(Ui\Web, #PB_WebView_HtmlCode, Html$)
EndProcedure

; Folder of the source file of the current page.
Procedure.s PageFolder()
  If View\Page\UserLib$ <> ""
    ProcedureReturn Settings\UserLibPath$
  EndIf
  ProcedureReturn HelpSource\Root$ + LanguageFolder()
EndProcedure

; Collapses all the items of a TreeGadget (the call in Show() is commented, see there).
Procedure CollapseContents(Tree)
  Protected Count, Index

  If IsGadget(Tree) = 0
    ProcedureReturn
  EndIf
  Count = CountGadgetItems(Tree) - 1
  If Count < 1
    ProcedureReturn
  EndIf
  For Index = 0 To Count
    If GetGadgetItemState(Tree, Index) & #PB_Tree_Expanded
      SetGadgetItemState(Tree, Index, #PB_Tree_Collapsed)
    EndIf
  Next
EndProcedure

; Shows a page by name; "-" and "+" go back / forward in the history.
Procedure ShowPage(Page$)
  Protected HistoryPos

  If Len(Page$) <> 1 And FindMapElement(*PageByName(), Page$) = 0
    MessageRequester("PB Help", "not found : " + Page$)
    ProcedureReturn
  EndIf
  Select Page$
    Case "-"
      If ListIndex(History()) <= 0
        ProcedureReturn
      EndIf
      PreviousElement(History())
      Page$ = History()
    Case "+"
      If ListIndex(History()) >= ListSize(History()) - 1
        ProcedureReturn
      EndIf
      NextElement(History())
      Page$ = History()
    Default
      While NextElement(History())
        DeleteElement(History())
      Wend
      AddElement(History())
      History() = Page$
  EndSelect
  If FindMapElement(*PageByName(), Page$) = 0 ; page of another language, or removed (example page)
    ProcedureReturn
  EndIf
  If Page$ = View\PageName$
    ProcedureReturn
  EndIf
  View\PageName$ = Page$
  View\Page = *PageByName(Page$) ; (the old code got it from PbtoHtml)
  ShowHtml(PageHtmlHighlighted(Page$))
  HistoryPos = ListIndex(History())
  DisableGadget(Ui\Back, Bool(HistoryPos = 0))
  DisableGadget(Ui\Forward, Bool(HistoryPos = ListSize(History()) - 1))

  HideGadget(Ui\Edit, Bool(HelpSource\IsArchive And View\Page\UserLib$ = ""))

  If View\Page
    CompilerIf #Standalone ; in the IDE, do not take the focus of the editor
      SetActiveGadget(Ui\Contents)
    CompilerEndIf
    SetGadgetState(Ui\Contents, View\Page\ContentsRow)
  EndIf
EndProcedure

;- Examples

; IDE: real path of an example file (so the relative paths of its data work).
Procedure.s ExampleFile(Name$)
  Protected Index
  Protected Dir$

  For Index = 1 To 2
    If Index = 1
      Dir$ = HelpSource\Root$
    Else
      Dir$ = Settings\ExamplePath$
    EndIf
    If Dir$ = "" Or (Index = 1 And HelpSource\IsArchive)
      Continue
    EndIf
    If FileSize(Dir$ + "Examples/Sources/" + Name$) > 0
      ProcedureReturn Dir$ + "Examples/Sources/" + Name$
    EndIf
    If FileSize(Dir$ + "Examples/3D/" + Name$) > 0
      ProcedureReturn Dir$ + "Examples/3D/" + Name$
    EndIf
    If Index = 2
      If FileSize(Dir$ + "Sources/" + Name$) > 0
        ProcedureReturn Dir$ + "Sources/" + Name$
      EndIf
      If FileSize(Dir$ + "3D/" + Name$) > 0
        ProcedureReturn Dir$ + "3D/" + Name$
      EndIf
    EndIf
  Next
  ProcedureReturn ""
EndProcedure

; Closes the help: standalone window, or the callback of the IDE (gives the focus back to the editor).
Procedure CloseRequest()
  CompilerIf #Standalone
    PostEvent(#PB_Event_CloseWindow, Ui\Window, 0)
  CompilerElse
    If CloseCallback
      CloseCallback()
    EndIf
  CompilerEndIf
EndProcedure

; Shows an example file as a page of the help: the code with the Open / Copy / Run buttons.
Procedure ShowExamplePage(Name$)
  Protected PageName$ = "ex_" + LCase(Name$)
  Protected Path$, Code$, From$

  If FindMapElement(*PageByName(), PageName$) = 0
    CompilerIf Not #Standalone
      Path$ = ExampleFile(Name$)
    CompilerEndIf
    If Path$ <> ""
      Code$ = FileReadText(Path$, #False)
    Else
      Code$ = SourceReadText("Examples/Sources/" + Name$, #False)
      If Code$ = ""
        Code$ = SourceReadText("Examples/3D/" + Name$, #False)
      EndIf
    EndIf
    If Code$ = ""
      ProcedureReturn
    EndIf
    From$ = View\PageName$
    PageAddGenerated(PageName$, Name$, "@Code" + #LF$ + Code$ + #LF$ + "@EndCode" + #LF$)
    Pages()\ExampleFile$ = Name$
    Pages()\ContentsRow = -1 ; not in the contents
    If From$ <> ""
      Pages()\Navigation$ = "< " + PageLink(From$)
    EndIf
  EndIf
  ShowPage(PageName$)
EndProcedure

; Action sent by the page (javascript): lk link, ef example file shown as a page, zm zoom, es escape, co/cr/cc code open/run/copy, fo/fr/fc example file open/run/copy.
Procedure JsAction(Message$)
  Protected Position, Index
  Protected Path$, FileName$, Source$, Code$, Kind$, Value$

  Message$ = Mid(Message$, 3, Len(Message$) - 4)
  Kind$ = Left(Message$, 2)
  Value$ = Trim(Mid(Message$, 4))

  If Kind$ = "lk" ; ------------------------ link
    ShowPage(LCase(Value$))
  ElseIf Kind$ = "zm" ; ------------------------ page zoom changed: kept for the next pages
    View\Zoom = ValF(Value$)
    If View\Zoom < 0.5
      View\Zoom = 0.5
    ElseIf View\Zoom > 3
      View\Zoom = 3
    EndIf
  ElseIf Kind$ = "es" ; ------------------------ Escape
    CloseRequest()
  ElseIf Kind$ = "ef" ; ------------------------ example file: shown as a page of the help
    ShowExamplePage(Value$)
  ElseIf View\Page ; ------------------------ example
    If Left(Kind$, 1) = "c" And View\Page\ExampleFile$ <> "" ; buttons of an example page: the file, as for the lists of examples
      Kind$ = "f" + Mid(Kind$, 2)
      Value$ = View\Page\ExampleFile$
    EndIf
    Select Left(Kind$, 1)
      Case "c" ;----- code
        Source$ = View\Page\Source$
        For Index = 0 To Val(Value$)
          Position = FindString(Source$, "@Code", Position + 1)
        Next
        Code$ = StringBetween(Source$, "@Code", "@EndCode", Position - 5) ; !sos! bug caractere :exemple openxmldialog
        FileName$ = View\Page\Name$ + "_ex" + Value$ + ".pb"
      Case "f" ;----- file
        CompilerIf Not #Standalone
          Path$ = ExampleFile(Value$)
        CompilerEndIf
        If Path$ = ""
          Code$ = SourceReadText("Examples/Sources/" + Value$, #False)
          If Code$ = ""
            Code$ = SourceReadText("Examples/3D/" + Value$, #False)
          EndIf
        EndIf
        FileName$ = Value$
    EndSelect

    If Mid(Kind$, 2, 1) = "c" ; copy to the clipboard (the plain code)
      If Code$ = "" And Path$ <> ""
        Code$ = FileReadText(Path$, #False)
      EndIf
      If Code$ <> ""
        SetClipboardText(Code$)
      EndIf
      ProcedureReturn
    EndIf

    CompilerIf #Standalone
      If Code$ <> ""
        If FindString(Code$, "CreateThread", 1, #PB_String_NoCase)
          Code$ + " /THREAD"
        EndIf
        CompilerIf #PB_Compiler_OS = #PB_OS_Windows
          Code$ + " /XP /DPIAWARE"
        CompilerEndIf
        Path$ = GetTemporaryDirectory() + FileName$
        FileWriteText(Path$, Code$)
        Select Mid(Kind$, 2, 1)
          Case "o"
            RunProgram(#PB_Compiler_Home + "PureBasic", #DQUOTE$ + Path$ + #DQUOTE$, GetTemporaryDirectory(), #PB_Program_Hide)
          Case "r"
            RunProgram(#DQUOTE$ + #PB_Compiler_Home + "Compilers\pbcompiler" + #DQUOTE$, #DQUOTE$ + Path$ + #DQUOTE$, GetTemporaryDirectory(), #PB_Program_Hide)
        EndSelect
      EndIf
    CompilerElse ; IDE: loads in a new tab (and runs if requested)
      If OpenCodeCallback And (Path$ <> "" Or Code$ <> "")
        Code$ + #LF$ + "; IDE Options"
        If FindString(Code$, "CreateThread", 1, #PB_String_NoCase)
          Code$ + #LF$ + "; EnableThread"
        EndIf
        CompilerIf #PB_Compiler_OS = #PB_OS_Windows
          Code$ + #LF$ + "; EnableXP" + #LF$ + "; DPIAware"
        CompilerEndIf
        OpenCodeCallback(Path$, Code$, Bool(Mid(Kind$, 2, 1) = "r"))
      EndIf
    CompilerEndIf
  EndIf
EndProcedure

; Callback of the page (javascript): the page is blocked during the callback, so the action is deferred to the event loop.
Procedure JsMessage(Message$)
  LastElement(JsMessages())
  AddElement(JsMessages())
  JsMessages() = Message$
  PostEvent(#EventJsMessage, View\HostWindow, 0)
EndProcedure

CompilerIf #PB_Compiler_OS = #PB_OS_Windows
  ; Is WebView2 usable? (tested once, in an invisible window)
  Procedure WebViewAvailable()
    Static Result = -1
    Protected OldList, Window, Gadget

    If Result = -1
      Result = 1
      OldList = UseGadgetList(0)
      Window = OpenWindow(#PB_Any, 0, 0, 10, 10, "", #PB_Window_Invisible)
      If Window
        Gadget = WebViewGadget(#PB_Any, 0, 0, 10, 10)
        If Gadget
          FreeGadget(Gadget)
        Else
          Result = 0
        EndIf
        CloseWindow(Window)
      EndIf
      If OldList
        UseGadgetList(OldList)
      EndIf
    EndIf
    ProcedureReturn Result
  EndProcedure

  ; IE mode: the calls to jsmessage() arrive as a 'pbhelp:' url.
  Procedure Navigation(Gadget, Url$)
    If LCase(Left(Url$, 7)) = "pbhelp:"
      JsMessage("[" + #DQUOTE$ + URLDecoder(Mid(Url$, 8)) + #DQUOTE$ + "]") ; same format as the callback of the WebView
      ProcedureReturn #False
    EndIf
    ProcedureReturn #True
  EndProcedure
CompilerEndIf

; Runs the deferred javascript actions (event #EventJsMessage).
Procedure JsProcess()
  Protected Message$

  While FirstElement(JsMessages())
    Message$ = JsMessages()
    DeleteElement(JsMessages())
    JsAction(Message$)
  Wend
EndProcedure

;- Contents

; Adds a page to the contents tree. *Library <> 0: the page is a function of this library page (user library functions
; show their library). Returns nothing; the row of the page is the number of items before the call.
Procedure ContentsAdd(Level, Text$, *Page.PageInfo, IsUserLib = #False, *Library.PageInfo = 0)
  Protected Row = CountGadgetItems(Ui\Contents)

  If IsUserLib
    If *Page\UserLib$ = *Library\UserLib$
      If *Page\LibDest$ <> ""
        Text$ + " (" + *Page\LibDest$ + ")"
      EndIf
    Else
      Text$ + " (" + *Page\UserLib$ + ")"
    EndIf
  EndIf
  AddGadgetItem(Ui\Contents, -1, Text$, 0, Level)
  SetGadgetItemData(Ui\Contents, Row, *Page)
  If IsUserLib
    SetGadgetItemColor(Ui\Contents, Row, #PB_Gadget_FrontColor, Theme\UserLibColor) ; else color of the gadget (IDE theme)
  EndIf
EndProcedure

; (Re)loads the pages, fills the contents tree, shows the home page and builds the chips (the UI part of the old initFichier()).
Procedure PagesReload()
  Protected Level, Row
  Protected *Library.PageInfo, *SubPage.PageInfo
  Protected Text$, Link$
  NewList Outline$()

  View\PageName$ = ""
  If PagesLoad() = #False ; help source not found
    ClearGadgetItems(Ui\Contents)
    Text$ = "<html><head><style>" + Theme\Colors$ + Theme\Style$ + "</style></head><body><h2>" + Language(#TextGroup$, "Help") + "</h2>" +
            Language(#TextGroup$, "HelpNotFound") + " <br><br><b>" + HtmlEscape(HelpSource\Path$) + "</b>"
    If GetPathPart(ProgramFilename()) = GetTemporaryDirectory()
      Text$ + "<br><br><br>" + Language(#TextGroup$, "TmpSourceDir")
    EndIf
    Text$ + "</body></html>"
    ShowHtml(Text$)
    ProcedureReturn
  EndIf
  PagesOutline(Outline$())

  ClearGadgetItems(Ui\Contents)
  HideGadget(Ui\Contents, 1)
  ForEach Outline$()
    Text$ = StringField(Outline$(), 1, #TAB$)
    Link$ = StringField(Outline$(), 2, #TAB$)
    *Library = 0
    If Link$ = ""
      Level = 0
    Else
      Level = 1
      If FindMapElement(*PageByName(), Link$)
        *Library = *PageByName()
        *Library\ContentsRow = CountGadgetItems(Ui\Contents)
      EndIf
    EndIf
    ContentsAdd(Level, Text$, *Library)
    If *Library
      ForEach *Library\SubPages()
        *SubPage = *Library\SubPages()
        If *SubPage\ContentsRow = 0
          *SubPage\ContentsRow = CountGadgetItems(Ui\Contents)
        EndIf
        ContentsAdd(Level + 1, *SubPage\Title$, *SubPage, Bool(*SubPage\UserLib$ <> ""), *Library)
      Next
    EndIf
  Next
  HideGadget(Ui\Contents, 0)

  ShowPage("reference")
  ChipsBuild()
EndProcedure

;- Edit

; Edits the source of the current page.
Procedure EditPage()
  Protected Text$

  If View\Page = 0 Or View\Page\File$ = ""
    ProcedureReturn
  EndIf
  CompilerIf #Standalone
    RunProgram("notepad++.exe", #DQUOTE$ + PageFolder() + View\Page\File$ + #DQUOTE$ + " -p" + View\Page\Position, "")
  CompilerElse ; IDE: opens the file in a tab, at the line of the page
    If EditFileCallback
      Text$ = FileReadText(PageFolder() + View\Page\File$, #False)
      EditFileCallback(PageFolder() + View\Page\File$, CountString(Left(Text$, View\Page\Position), #LF$) + 1)
    EndIf
  CompilerEndIf
EndProcedure

;- Splitter (IDE)

; Width of the area of the help (IDE: root gadget of the dialog, standalone: client area of the window), 0 if not created.
Procedure RootWidth()
  CompilerIf #Standalone
    If IsWindow(Ui\Window)
      ProcedureReturn WindowWidth(Ui\Window, #PB_Window_InnerCoordinate)
    EndIf
  CompilerElse
    If IsGadget(Ui\Root)
      ProcedureReturn GadgetWidth(Ui\Root)
    EndIf
  CompilerEndIf
  ProcedureReturn 0
EndProcedure

; IDE: position of the splitter.
Procedure SplitSet(Position)
  Protected w, h

  SetGadgetState(Ui\Splitter, Position)
  CompilerIf #PB_Compiler_OS = #PB_OS_MacOS
    ; Cocoa: SetGadgetState() does not relayout the content of the panels of the dialog, a resize forces it
    If IsGadget(Ui\Root)
      w = GadgetWidth(Ui\Root)
      h = GadgetHeight(Ui\Root)
      ResizeGadget(Ui\Root, #PB_Ignore, #PB_Ignore, w, h - 1)
      ResizeGadget(Ui\Root, #PB_Ignore, #PB_Ignore, w, h)
    EndIf
  CompilerEndIf
EndProcedure

; IDE: width of the splitter bar, in screen coordinates (independent of the real parent of the splitter gadgets).
Procedure BarMeasure()
  Protected Width = GadgetX(Ui\Web, #PB_Gadget_ScreenCoordinate) - GadgetX(Ui\Splitter, #PB_Gadget_ScreenCoordinate) - GetGadgetState(Ui\Splitter)

  If Width > 0 And Width < 40
    View\BarWidth = Width
  EndIf ; else the size is not allocated yet (GTK)
EndProcedure

; IDE: contents hidden: the splitter bar is placed just at the left of the visible area.
Procedure ContentsPlace()
  Protected Width

  If View\ContentsVisible Or IsGadget(Ui\Splitter) = 0 Or RootWidth() = 0
    ProcedureReturn
  EndIf
  If GetGadgetState(Ui\Splitter) <> 0
    SetGadgetState(Ui\Splitter, 0)
  EndIf
  BarMeasure()
  Width = View\BarWidth
  If Width < 0
    Width = 8
  EndIf
  ResizeGadget(Ui\Splitter, -Width, #PB_Ignore, RootWidth() + Width, #PB_Ignore) ; the dialog places the splitter on the whole width of the root
EndProcedure

; IDE: shows or hides the contents at the left of the page.
Procedure ContentsShow(Visible)
  If IsGadget(Ui\Splitter) = 0
    ProcedureReturn
  EndIf
  View\ContentsVisible = Visible
  SetGadgetState(Ui\ToggleContents, Visible)
  If Visible
    SetGadgetAttribute(Ui\Splitter, #PB_Splitter_FirstMinimumSize, 20)
    HideGadget(Ui\Panel, 0)
    RefreshDialog(Ui\Dialog) ; places the splitter in the visible area
    If View\SplitPos <= 0 ; first display: a third of the width, but not too narrow
      View\SplitPos = RootWidth() / 3
      If View\SplitPos < 150
        View\SplitPos = RootWidth() / 2
      EndIf
    EndIf
    SplitSet(View\SplitPos)
  Else
    If GetGadgetState(Ui\Splitter) > 0
      View\SplitPos = GetGadgetState(Ui\Splitter)
    EndIf
    SetGadgetAttribute(Ui\Splitter, #PB_Splitter_FirstMinimumSize, 0)
    HideGadget(Ui\Panel, 1)
    ContentsPlace()
  EndIf
  ChipsPlace()
EndProcedure

;- Display mode, dark mode

; IDE: "in the tools panel" toggle (ON = tools panel, OFF = window). Notify = #False: only updates the button.
Procedure ToolsModeSet(Enable, Notify = #True)
  View\InToolsPanel = Bool(Enable)
  If IsGadget(Ui\ModeTools)
    SetGadgetState(Ui\ModeTools, View\InToolsPanel)
  EndIf
  If Notify And ModeCallback
    ModeCallback(View\InToolsPanel)
  EndIf
EndProcedure

; IDE: redraws the icons made by the module and re-assigns the toolbar icons (defined with the dialog).
Declare IconsRebuild()

; Dark mode: dark colors for the pages (they win over the colors of the IDE theme) and light icons on the toolbar.
; Can be called at any time: before the creation of the help, or while it is shown (the page is displayed again).
Procedure EnableDarkMode(Enable = #True)
  Theme\Dark = Bool(Enable)
  ColorsApply()
  CompilerIf Not #Standalone
    If IsGadget(Ui\Back)
      IconsRebuild()
    EndIf
  CompilerEndIf
  If IsGadget(Ui\Web) And View\PageName$ <> ""
    ShowHtml(PageHtmlHighlighted(View\PageName$))
  EndIf
EndProcedure

;- Events

; Timer of the host (1 s): reloads the help if the source of the current page was modified.
Procedure Timer()
  Protected Width
  Protected Name$

  ChipsPlace() ; catches splitter moves (there is no resize event)
  FiltersFit()
  If View\ContentsVisible = 0 And IsGadget(Ui\Splitter) ; the bar width is only known once the splitter is shown (GTK, Cocoa)
    Width = View\BarWidth
    BarMeasure()
    If View\BarWidth <> Width
      ContentsPlace()
    EndIf
  EndIf
  If View\Page And View\Page\File$ <> ""
    If GetFileDate(PageFolder() + View\Page\File$, #PB_Date_Modified) - View\EditDate >= 2
      View\EditDate = Date()
      Name$ = View\Page\Name$
      PagesReload()
      ShowPage(Name$)
    EndIf
  EndIf
EndProcedure

; Events of the gadgets of the help.
Procedure GadgetEvent(Gadget, Type)
  If Type = #PB_EventType_Change Or Type = #PB_EventType_LeftClick
    Select Gadget
      Case Ui\Contents
        If GetGadgetState(Ui\Contents) >= 0 And Type = #PB_EventType_Change
          View\Selected = GetGadgetItemData(Ui\Contents, GetGadgetState(Ui\Contents))
          If View\Selected
            ShowPage(View\Selected\Name$)
          EndIf
        EndIf
      Case Ui\ToggleContents
        ContentsShow(GetGadgetState(Ui\ToggleContents))
      Case Ui\ToggleFilters
        FiltersShow(GetGadgetState(Ui\ToggleFilters))
      Case Ui\ModeTools
        ToolsModeSet(GetGadgetState(Ui\ModeTools))
      Case Ui\Sticky
        CompilerIf #Standalone
          StickyWindow(Ui\Window, GetGadgetState(Ui\Sticky))
        CompilerEndIf
      Case Ui\Home
        ShowPage("reference")
      Case Ui\Back
        ShowPage("-")
      Case Ui\Forward
        ShowPage("+")

      Case Ui\Panel
        SetActiveGadget(Ui\Search)
      Case Ui\Search
        SearchChanged(Type)
      Case Ui\Results
        If GetGadgetState(Ui\Results) >= 0
          View\Selected = GetGadgetItemData(Ui\Results, GetGadgetState(Ui\Results))
          ShowPage(View\Selected\Name$)
        EndIf

      Case Ui\Edit
        EditPage()
      Case Ui\Language
        LanguageSet(GetGadgetText(Ui\Language))
        PagesReload()
      Case Ui\Os
        Settings\OsName$ = GetGadgetText(Ui\Os)
      Default
        ChipClick(Gadget)
    EndSelect
  EndIf
EndProcedure

;- Dialog

; Settings of the standalone tool (section [Help] of PBHelp.ini): window, splitter, toggles, zoom, mode, dark mode, help source, userlib folder.
; Write = #False reads them.
Procedure PrefsAccess(Write)
  Protected SplitPos

  OpenPreferences(GetCurrentDirectory() + "PBHelp.ini")
  PreferenceGroup("Help")
  If Write
    WritePreferenceLong("pX", WindowX(Ui\Window))
    WritePreferenceLong("py", WindowY(Ui\Window))
    WritePreferenceLong("dX", WindowWidth(Ui\Window))
    WritePreferenceLong("dy", WindowHeight(Ui\Window))
    SplitPos = View\SplitPos
    If View\ContentsVisible And GetGadgetState(Ui\Splitter) > 0
      SplitPos = GetGadgetState(Ui\Splitter)
    EndIf
    WritePreferenceLong("splitpos", SplitPos)
    WritePreferenceLong("contents", View\ContentsVisible)
    WritePreferenceLong("filters", View\FiltersVisible)
    WritePreferenceLong("sticky", GetGadgetState(Ui\Sticky))
    WritePreferenceFloat("zoom", View\Zoom)
    WritePreferenceLong("darkmode", Theme\Dark)
  Else
    Ui\WinX = ReadPreferenceLong("pX", 50)
    Ui\WinY = ReadPreferenceLong("py", 50)
    Ui\WinW = ReadPreferenceLong("dX", 800)
    Ui\WinH = ReadPreferenceLong("dy", 600)
    View\SplitPos = ReadPreferenceLong("splitpos", 0)
    Settings\StartContents = ReadPreferenceLong("contents", 0)
    Settings\StartFilters = ReadPreferenceLong("filters", 1)
    Settings\StartSticky = ReadPreferenceLong("sticky", 0)
    View\Zoom = ReadPreferenceFloat("zoom", 1.0)
    If View\Zoom < 0.5 Or View\Zoom > 3
      View\Zoom = 1.0
    EndIf
    Settings\DarkMode = ReadPreferenceLong("darkmode", #PB_Help_DarkMode)
    Settings\HelpPath$ = ReadPreferenceString("helpsource", "")
    Settings\UserLibPath$ = ReadPreferenceString("userlib", "")
  EndIf
  ClosePreferences()
EndProcedure

; Image to show on a toolbar button for an icon of the IDE theme: in dark mode the dark pixels are lightened
; (a copy is kept in AdaptedImage(), freed by Destroy()).
Procedure ToolbarIcon(Source)
  Protected Adapted, x, y, Color, HasAlpha, PixelAlpha

  If Theme\Dark = 0 Or IsImage(Source) = 0
    ProcedureReturn Source
  EndIf
  If FindMapElement(AdaptedImage(), Str(Source))
    If IsImage(AdaptedImage())
      ProcedureReturn AdaptedImage()
    EndIf
  EndIf
  Adapted = CopyImage(Source, #PB_Any)
  If Adapted = 0
    ProcedureReturn Source
  EndIf
  HasAlpha = Bool(ImageDepth(Adapted) = 32)
  If StartDrawing(ImageOutput(Adapted))
    DrawingMode(#PB_2DDrawing_AllChannels)
    For y = 0 To OutputHeight() - 1
      For x = 0 To OutputWidth() - 1
        Color = Point(x, y)
        PixelAlpha = 255
        If HasAlpha
          PixelAlpha = Alpha(Color)
        EndIf
        If PixelAlpha > 0 And Red(Color) < 90 And Green(Color) < 90 And Blue(Color) < 90 ; dark pixel: made light, same transparency
          Plot(x, y, RGBA(215, 215, 215, PixelAlpha))
        EndIf
      Next
    Next
    StopDrawing()
  EndIf
  AdaptedImage(Str(Source)) = Adapted
  ProcedureReturn Adapted
EndProcedure

; Gadget of a toolbar icon (see #Icon...).
Procedure IconGadget(Slot)
  Select Slot
    Case #IconContents
      ProcedureReturn Ui\ToggleContents
    Case #IconFilters
      ProcedureReturn Ui\ToggleFilters
    Case #IconBack
      ProcedureReturn Ui\Back
    Case #IconForward
      ProcedureReturn Ui\Forward
    Case #IconTools
      ProcedureReturn Ui\ModeTools
    Case #IconHome
      ProcedureReturn Ui\Home
    Case #IconEdit
      ProcedureReturn Ui\Edit
  EndSelect
  ProcedureReturn -1
EndProcedure

; Symbol drawn for a toolbar icon (the same as the text buttons of the standalone tool).
Procedure.s IconGlyph(Slot)
  Select Slot
    Case #IconContents
      ProcedureReturn Chr($2630)
    Case #IconFilters
      ProcedureReturn Chr($25BC)
    Case #IconBack
      ProcedureReturn Chr($25C0)
    Case #IconForward
      ProcedureReturn Chr($25B6)
    Case #IconTools
      ProcedureReturn Chr($25E7)
    Case #IconHome
      ProcedureReturn Chr($2302)
    Case #IconEdit
      ProcedureReturn Chr($270E)
  EndSelect
  ProcedureReturn ""
EndProcedure

; Draws a symbol in an image of Size x Size pixels: black (light theme) or light gray (dark mode), on a transparent background.
; The symbol is drawn black on white, then the gray levels become the transparency.
Procedure IconCreate(Glyph$, Size)
  Protected Image, Font, FontSize, Attempt, x, y, Done
  Protected GlyphWidth, GlyphHeight, Gray, ColorR
  
  Image = CreateImage(#PB_Any, Size, Size, 32, $FFFFFF)
  If Image = 0
    ProcedureReturn 0
  EndIf
  ColorR = 20
  If Theme\Dark
    ColorR = 230
  EndIf
  FontSize = Size / 2 + 2
  For Attempt = 1 To 10 ; the font size is reduced until the symbol fits
    Font = LoadFont(#PB_Any, #IconFontName$, FontSize)
    If Font = 0
      Break
    EndIf
    If StartDrawing(ImageOutput(Image))
      DrawingFont(FontID(Font))
      GlyphWidth = TextWidth(Glyph$)
      GlyphHeight = TextHeight(Glyph$)
      If (GlyphWidth <= Size And GlyphHeight <= Size) Or FontSize <= 6
        Box(0, 0, Size, Size, $FFFFFF)
        DrawText((Size - GlyphWidth) / 2, (Size - GlyphHeight) / 2, Glyph$, $000000, $FFFFFF)
        DrawingMode(#PB_2DDrawing_AllChannels)
        For y = 0 To Size - 1
          For x = 0 To Size - 1
            Gray = Red(Point(x, y))
            Plot(x, y, RGBA(ColorR, ColorR, ColorR, 255 - Gray))
          Next
        Next
        Done = #True
      EndIf
      StopDrawing()
    EndIf
    FreeFont(Font)
    If Done
      Break
    EndIf
    FontSize - 1
  Next
  ProcedureReturn Image
EndProcedure

; IDE: images of the toolbar buttons: drawn symbols (like the standalone tool), or the icons of the IDE theme when
; #PB_Help_ThemeIcons is #True (the ones the IDE did not give are drawn).
Procedure IconsPrepare()
  Protected Slot
  Protected Size = DesktopScaledX(16)

  If IsImage(Ui\ThemeImg[#IconBack])
    Size = ImageWidth(Ui\ThemeImg[#IconBack])
  EndIf
  For Slot = 0 To #IconEdit
    If #PB_Help_ThemeIcons And IsImage(Ui\ThemeImg[Slot])
      Ui\Img[Slot] = Ui\ThemeImg[Slot]
      Ui\OwnImg[Slot] = #False
    Else
      Ui\Img[Slot] = IconCreate(IconGlyph(Slot), Size)
      Ui\OwnImg[Slot] = #True
    EndIf
  Next
EndProcedure

; IDE: sets the images of all the toolbar buttons.
Procedure ToolbarApply()
  Protected Slot, Gadget, Image

  For Slot = 0 To #IconEdit
    Gadget = IconGadget(Slot)
    Image = Ui\Img[Slot]
    If IsGadget(Gadget) And IsImage(Image)
      If Ui\OwnImg[Slot] = #False
        Image = ToolbarIcon(Image) ; icon of the IDE theme: lightened in dark mode
      EndIf
      SetGadgetAttribute(Gadget, #PB_Button_Image, ImageID(Image))
    EndIf
  Next
EndProcedure

; The dark mode changed: the icons drawn by the module are drawn again with the right color, then the toolbar is updated.
Procedure IconsRebuild()
  Protected Slot
  Dim OldImg(#IconEdit)
  Dim OldOwn(#IconEdit)

  For Slot = 0 To #IconEdit
    OldImg(Slot) = Ui\Img[Slot]
    OldOwn(Slot) = Ui\OwnImg[Slot]
  Next
  IconsPrepare()
  ToolbarApply()
  For Slot = 0 To #IconEdit
    If OldOwn(Slot) And IsImage(OldImg(Slot))
      FreeImage(OldImg(Slot))
    EndIf
  Next
EndProcedure

; Standalone toolbar toggle button.
Procedure.s XmlToggle(Name$, Text$)
  ProcedureReturn "            <button name='" + Name$ + "' text='" + Text$ + "' flags='#PB_Button_Toggle' />"
EndProcedure

; Standalone toolbar button.
Procedure.s XmlButton(Name$, Text$)
  ProcedureReturn "            <button name='" + Name$ + "' text='" + Text$ + "' />"
EndProcedure

; IDE toolbar button (icon set later).
Procedure.s XmlButtonImage(Name$, Size, Flags$)
  ProcedureReturn "      <buttonimage name='" + Name$ + "' width='" + Size + "' height='" + Size + "' flags='" + Flags$ + "' />"
EndProcedure

; Creates the dialog: standalone window, or the gadgets of the IDE panel (the old initui()).
Procedure UiCreate()
  Protected Xml$, Tabs$, Index
  Protected ButtonSize = 28 ; button size: icon + margin

  LanguageSet(Settings\Language$)
  Tabs$ = "        <tab text='" + Language(#TextGroup$, "Contents") + "'>" +
          "          <Tree name='sommaire' flags='#PB_Tree_AlwaysShowSelection'/>" +
          "          </tab>" +
          "        <tab text='" + Language(#TextGroup$, "Search") + "'>" +
          "          <vbox expand='item:2'>" +
          "            <String name='rec' height='" + Str(#SearchHeight) + "'/>" +
          "            <ListView name='recliste'/>" +
          "            <scrollarea name='chips' height='" + Str(#ChipsHeight) + "' flags='#PB_ScrollArea_BorderLess'/>" +
          "            </vbox>" +
          "          </tab>"
  CompilerIf #Standalone
    Xml$ = "<window id='#PB_Any' name='aide' text='PureBasic' minwidth='500' minheight='400' margin='0' flags='#PB_Window_ScreenCentered | #PB_Window_SystemMenu | #PB_Window_SizeGadget | #PB_Window_MinimizeGadget | #PB_Window_MaximizeGadget'>" +
           "  <vbox expand='item:2'>" +
           "    <hbox expand='no' margin='4'>" +
           XmlToggle("sommairevisible", "&#9776;") +
           XmlToggle("filtres", "&#9660;") +
           XmlButton("prec", "&#9664;") +
           XmlButton("suiv", "&#9654;") +
           XmlButton("acc", "&#8962;") +
           "            <combobox name='langue' width='100' />" +
           "            <combobox name='os' width='100' />" +
           XmlButton("editer", "&#9998;") +
           "      </hbox>" +
           "    <splitter name='sep' flags='#PB_Splitter_Vertical' firstmin='0' secondmin='auto'>" +
           "      <panel name='onglet' invisible='yes'>" +
           Tabs$ +
           "        </panel>" +
           "      <WebView name='Web' />" +
           "      </splitter>" +
           "    <hbox expand='no' margin='4'>" +
           "      <checkbox name='sticky' text='" + Language(#TextGroup$, "ModeSticky") + "' />" +
           "      </hbox>" +
           "    </vbox>" +
           "  </window>"
  CompilerElse ; IDE: the toolbar is above, the contents (hidden by default) at the left of the page
    If IsImage(Ui\ThemeImg[#IconBack])
      ButtonSize = DesktopUnscaledX(ImageWidth(Ui\ThemeImg[#IconBack])) + 12
    EndIf
    Xml$ = "<window id='#PB_Any' name='aide' margin='0'>" +
           "  <vbox expand='item:2'>" +
           "    <hbox expand='no'>" +
           XmlButtonImage("sommairevisible", ButtonSize, "#PB_Button_Toggle") +
           XmlButtonImage("filtres", ButtonSize, "#PB_Button_Toggle") +
           XmlButtonImage("prec", ButtonSize, "") +
           XmlButtonImage("suiv", ButtonSize, "") +
           XmlButtonImage("modetools", ButtonSize, "#PB_Button_Toggle") +
           XmlButtonImage("acc", ButtonSize, "") +
           XmlButtonImage("editer", ButtonSize, "") +
           "      </hbox>" +
           "    <splitter name='sep' flags='#PB_Splitter_Vertical' firstmin='0' secondmin='auto'>" +
           "      <panel name='onglet' invisible='yes'>" +
           Tabs$ +
           "        </panel>" +
           "      <WebView name='Web' />" +
           "      </splitter>" +
           "    </vbox>" +
           "  </window>"
  CompilerEndIf

  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    View\IeMode = Bool(#ForceIEMode Or WebViewAvailable() = 0)
    If View\IeMode ; WebView2 not available: WebGadget (Internet Explorer), degraded display
      Xml$ = ReplaceString(Xml$, "<WebView name='Web' />", "<web name='Web' />")
      UseDialogWebGadget()
    EndIf
  CompilerEndIf
  UseDialogWebViewGadget()
  Ui\Xml = ParseXML(#PB_Any, Xml$)
  Ui\Dialog = CreateDialog(#PB_Any)
  CompilerIf #Standalone
    OpenXMLDialog(Ui\Dialog, Ui\Xml, "aide")
    Ui\Window = DialogWindow(Ui\Dialog)
  CompilerElse
    XmlDialogGadget(Ui\Dialog, Ui\Xml, "aide")
    Ui\Root = DialogGadget(Ui\Dialog, "aide")
  CompilerEndIf
  Ui\Panel = DialogGadget(Ui\Dialog, "onglet")
  Ui\Contents = DialogGadget(Ui\Dialog, "sommaire")
  DisableGadget(Ui\Contents, 0)
  Ui\Search = DialogGadget(Ui\Dialog, "rec")
  Ui\Results = DialogGadget(Ui\Dialog, "recliste")
  Ui\Chips = DialogGadget(Ui\Dialog, "chips")

  Ui\Back = DialogGadget(Ui\Dialog, "prec")
  Ui\Forward = DialogGadget(Ui\Dialog, "suiv")
  Ui\Home = DialogGadget(Ui\Dialog, "acc")
  Ui\Edit = DialogGadget(Ui\Dialog, "editer")
  Ui\ToggleContents = DialogGadget(Ui\Dialog, "sommairevisible")
  Ui\ToggleFilters = DialogGadget(Ui\Dialog, "filtres")
  CompilerIf #Standalone
    Ui\Sticky = DialogGadget(Ui\Dialog, "sticky")
    SetGadgetState(Ui\Sticky, Settings\StartSticky)
    StickyWindow(Ui\Window, Settings\StartSticky)
  CompilerElse
    Ui\ModeTools = DialogGadget(Ui\Dialog, "modetools")
  CompilerEndIf
  View\FiltersVisible = #True
  View\ContentsVisible = #False
  SetGadgetState(Ui\ToggleFilters, 1) ; pressed (ON) = the filters are shown
  SetGadgetState(Ui\ToggleContents, 0) ; not pressed (OFF) = the contents is hidden
  ToolsModeSet(View\InToolsPanel, #False)

  CompilerIf #Standalone
    Ui\Language = DialogGadget(Ui\Dialog, "langue")
    For Index = 1 To 3
      AddGadgetItem(Ui\Language, -1, StringField(#LanguageList$, Index, ","))
    Next
    SetGadgetText(Ui\Language, Settings\Language$)
    Ui\Os = DialogGadget(Ui\Dialog, "os")
    AddGadgetItem(Ui\Os, -1, "Windows")
    AddGadgetItem(Ui\Os, -1, "MacOS")
    AddGadgetItem(Ui\Os, -1, "Linux")
    SetGadgetText(Ui\Os, Settings\OsName$)
  CompilerElse ; the language and the OS are the ones of the IDE
    Ui\Language = -1
    Ui\Os = -1
    IconsPrepare() ; the icons the IDE did not give are drawn
    ToolbarApply()
    If ApplyColorsCallback
      ApplyColorsCallback(Ui\Contents)
      ApplyColorsCallback(Ui\Search)
      ApplyColorsCallback(Ui\Results)
    EndIf
    RefreshDialog(Ui\Dialog)
  CompilerEndIf
  GadgetToolTip(Ui\Back, Language(#TextGroup$, "Back"))
  GadgetToolTip(Ui\Forward, Language(#TextGroup$, "Forward"))
  GadgetToolTip(Ui\Home, Language(#TextGroup$, "Home"))
  GadgetToolTip(Ui\Edit, Language(#TextGroup$, "EditSource"))
  GadgetToolTip(Ui\ToggleContents, Language(#TextGroup$, "ToggleContents"))
  GadgetToolTip(Ui\ToggleFilters, Language(#TextGroup$, "ToggleFilters"))
  If IsGadget(Ui\ModeTools)
    GadgetToolTip(Ui\ModeTools, Language(#TextGroup$, "ModeTools"))
  EndIf

  Ui\Web = DialogGadget(Ui\Dialog, "web")
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    If View\IeMode
      SetGadgetAttribute(Ui\Web, #PB_Web_NavigationCallback, @Navigation())
    Else
      BindWebViewCallback(Ui\Web, "jsmessage", @JsMessage())
    EndIf
  CompilerElse
    BindWebViewCallback(Ui\Web, "jsmessage", @JsMessage())
  CompilerEndIf

  Ui\Splitter = DialogGadget(Ui\Dialog, "sep")
  SetGadgetState(Ui\Splitter, 0) ; contents hidden by default

  If HelpSource\IsArchive And IsGadget(Ui\Language)
    HideGadget(Ui\Language, 1)
    HideGadget(Ui\Os, 1)
  EndIf

  CompilerIf #Standalone
    ResizeWindow(Ui\Window, Ui\WinX, Ui\WinY, Ui\WinW, Ui\WinH)
  CompilerEndIf
EndProcedure

;- Standalone tool

; Standalone tool: window, event loop. The help source is the one of PBHelp.ini, else Help\Help.zip next to the program,
; else the one of the PureBasic folder; if none exists, the page shows the (translated) message "help not found".
Procedure Init(LanguageName$, SystemName$)
  Protected Event
  Protected Default$

  Settings\Language$ = LanguageName$
  Settings\OsName$ = SystemName$
  PrefsAccess(#False)
  EnableDarkMode(Settings\DarkMode)

  If FileSize(Settings\HelpPath$) <> -2 And LCase(GetExtensionPart(Settings\HelpPath$)) <> "zip" ; neither a folder nor a .zip
    Settings\HelpPath$ = GetPathPart(ProgramFilename()) + "Help/Help.zip"
    If FileSize(Settings\HelpPath$) <= 0
      Default$ = GetPathPart(#PB_Compiler_File) + "Help/Help.zip" ; development: the sources folder
      If FileSize(Default$) <= 0
        Default$ = #PB_Compiler_Home + "Help/Help.zip"
      EndIf
      If FileSize(Default$) > 0
        Settings\HelpPath$ = Default$
      EndIf
    EndIf
  EndIf
  SourceOpen(Settings\HelpPath$)

  UiCreate()
  View\HostWindow = Ui\Window
  BindEvent(#EventJsMessage, @JsProcess(), View\HostWindow)
  AddWindowTimer(Ui\Window, 0, 1000)
  AddKeyboardShortcut(Ui\Window, #PB_Shortcut_Escape, #MenuEscape)
  PagesReload()
  View\Selected = View\Page
  View\EditDate = Date()
  ContentsPlace() ; contents hidden: the page takes the whole window
  If Settings\StartContents
    ContentsShow(#True)
  EndIf
  If Settings\StartFilters = 0
    FiltersShow(#False)
  EndIf

  Repeat
    Event = WaitWindowEvent()
    If EventWindow() = Ui\Window
      Select Event
        Case #PB_Event_Gadget
          GadgetEvent(EventGadget(), EventType())
        Case #PB_Event_Timer
          Timer()
        Case #PB_Event_SizeWindow
          ContentsPlace()
          ChipsPlace()
          FiltersFit()
        Case #PB_Event_Menu
          If EventMenu() = #MenuEscape
            Event = #PB_Event_CloseWindow
          EndIf
      EndSelect
    EndIf
  Until Event = #PB_Event_CloseWindow
  PrefsAccess(#True)
EndProcedure

;- IDE interface

; IDE: language, OS, help source (folder or .zip), user libraries folder and IDE folder of the examples.
Procedure Setup(LanguageName$, SystemName$, Source$, UserLibSource$, ExampleSource$)
  Settings\Language$ = LanguageName$
  Settings\OsName$ = SystemName$
  SourceOpen(Source$)
  Settings\UserLibPath$ = UserLibSource$
  Settings\ExamplePath$ = ExampleSource$
EndProcedure

; IDE: toolbar images (PureBasic images) and example icons (png in base64; "" = default icon). The last parameters are optional
; (icons of the filters, copy and "tools panel"). They are only used if #PB_Help_ThemeIcons is #True, otherwise the toolbar
; icons are drawn from symbols.
Procedure SetImages(Back, Forward, Home, Edit, Index, Open$, Run$, Filters = 0, Copy$ = "", ModeTools = 0)
  Ui\ThemeImg[#IconBack] = Back
  Ui\ThemeImg[#IconForward] = Forward
  Ui\ThemeImg[#IconHome] = Home
  Ui\ThemeImg[#IconEdit] = Edit
  Ui\ThemeImg[#IconContents] = Index
  Ui\ThemeImg[#IconFilters] = Filters
  Ui\ThemeImg[#IconTools] = ModeTools
  If Open$ <> ""
    Theme\IconOpen$ = "<img src='data:image/png;base64," + Open$ + "'>"
  EndIf
  If Run$ <> ""
    Theme\IconRun$ = "<img src='data:image/png;base64," + Run$ + "'>"
  EndIf
  If Copy$ <> ""
    Theme\IconCopy$ = "<img src='data:image/png;base64," + Copy$ + "'>"
  EndIf
EndProcedure

; IDE: Css$ = ":root {--bg:...}" (see Theme\Colors$), UserLibColor: user libraries in the contents.
Procedure SetColors(Css$, UserLibColor = $008800)
  Theme\ColorsCustom$ = Css$
  Theme\Custom = #True
  ColorsApply() ; (the dark mode, if enabled, wins)
  Theme\UserLibColor = UserLibColor
EndProcedure

; IDE: creates the help in the current gadget list.
Procedure Create(Window)
  View\HostWindow = Window
  ClearList(History())
  UiCreate()
  BindEvent(#EventJsMessage, @JsProcess(), View\HostWindow)
  PagesReload()
  View\Selected = View\Page
  View\EditDate = Date()
EndProcedure

; IDE: the help is shown in the tools panel (1) or in a window (0); only updates the toggle button.
Procedure SetMode(InToolsPanel)
  ToolsModeSet(InToolsPanel, #False)
EndProcedure

; IDE: frees the dialog.
Procedure Destroy()
  Protected Index

  UnbindEvent(#EventJsMessage, @JsProcess(), View\HostWindow)
  ClearList(JsMessages())
  If IsDialog(Ui\Dialog)
    FreeDialog(Ui\Dialog)
  EndIf
  If IsXML(Ui\Xml)
    FreeXML(Ui\Xml)
  EndIf
  Ui\Dialog = 0
  Ui\Xml = 0
  Ui\Root = 0
  Ui\ToggleContents = -1
  View\ContentsVisible = 0
  View\Page = 0
  View\Selected = 0
  For Index = 0 To #IconEdit
    If Ui\OwnImg[Index] And IsImage(Ui\Img[Index])
      FreeImage(Ui\Img[Index])
    EndIf
    Ui\Img[Index] = 0
    Ui\OwnImg[Index] = #False
  Next
  ForEach AdaptedImage()
    If IsImage(AdaptedImage())
      FreeImage(AdaptedImage())
    EndIf
  Next
  ClearMap(AdaptedImage())
  If Ui\ChipFont And IsFont(Ui\ChipFont)
    FreeFont(Ui\ChipFont)
    Ui\ChipFont = 0
  EndIf
  ClearList(Chips()) ; the chip buttons are freed with the dialog
  Ui\Chips = 0
EndProcedure

; IDE: resizes the help to the size of its panel.
Procedure Resize(Width, Height)
  If IsGadget(Ui\Root)
    ResizeGadget(Ui\Root, 0, 0, Width, Height) ; relayouts the dialog, which places the splitter on the whole width
    ContentsPlace()
    ChipsPlace()
    FiltersFit()
  EndIf
EndProcedure

; IDE: shows a page if it exists (contextual help F1). Returns #False if the page does not exist.
Procedure Show(Page$)
  Page$ = LCase(Page$)
  If FindMapElement(*PageByName(), Page$) = 0
    ProcedureReturn #False
  EndIf

  ; Open question: collapse the whole contents tree before showing the page requested with F1?
  ; - Collapsed: only the branch of the requested page is open, so every F1 gives the same clean view.
  ; - Not collapsed (current behaviour): the branches opened by previous F1 stay open for the whole session.
  ;CollapseContents(Ui\Contents)

  ShowPage(Page$)
  If IsGadget(Ui\Panel)
    SetGadgetState(Ui\Panel, 0) ; F1: back to the Contents tab, where the page is selected in the tree
  EndIf
  ProcedureReturn #True
EndProcedure
