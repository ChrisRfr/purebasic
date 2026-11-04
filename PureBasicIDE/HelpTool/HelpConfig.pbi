; ----------------------------------------------------------------------------
;---------- Config ---------
; ----------------------------------------------------------------------------
; Constants, structures and state shared by the files of module pbhelp.
; Included inside Module pbhelp (EnableExplicit is active).
;
; The constants are kept here so that HelpTool stays standalone. When the tool is integrated in the IDE,
; the constants (and the custom events) move to Common.pb.

#LanguageList$    = "English,French,German" ; help languages (the translation blocks of HelpCatalog.pbi also have Italian, Spanish, Russian)
#TextGroup$       = "HelpTool"              ; [HelpTool] section of the translations (Editor.catalog in the IDE)
#IdentifierChars$ = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_" ; characters of a function or constant name

#PB_Help_DarkMode = #True  ; dark colors for the pages (can be changed at any time with EnableDarkMode()). Will become a preference.
#PB_Help_ThemeIcons = #False ; IDE: #False = toolbar icons drawn from symbols (black, light in dark mode; like the standalone tool), #True = icons of the IDE theme
#PB_Helpsample_Image = #False ; example buttons: #True = icons with a tooltip, #False = text buttons (Copy, Open, Run). Will become a preference.

#EventJsMessage = #PB_Event_FirstCustomValue + 500 ; WebView callback actions are deferred to the event loop
#MenuEscape     = 1                                ; standalone: Escape closes the help
#ChipsHeight    = 150   ; height of the chips area (it scrolls only if the chips do not fit)
#SearchHeight   = 26    ; height of the search string (logical pixels)
#GroupReference$ = "Reference" ; chip for the pages outside a library
CompilerSelect #PB_Compiler_OS
  CompilerCase #PB_OS_Windows
    #ChipFontName$ = "Segoe UI"      ; Windows: IDE default Font, size 10 -> chips 8  or a little smaller 7
    #ChipFontSize  = 8
  CompilerCase #PB_OS_MacOS
    #ChipFontName$ = "Lucida Grande" ; MacOS:   IDE default Font, size 13 -> chips 10 or a little smaller 9
    #ChipFontSize  = 10
  CompilerDefault
    #ChipFontName$ = "DejaVu Sans"   ; Linux:   IDE default Font, size 10 -> chips 8 or a little smaller 7
    #ChipFontSize  = 8
CompilerEndSelect
#ForceIEMode    = #False ; Windows: #True to test the degraded mode (WebGadget/Internet Explorer) even if WebView2 is available

; State of the help source: a folder, or a .zip archive read in memory.
Structure HelpSourceState
  Path$              ; path as given (folder or .zip)
  Root$              ; folder with a trailing "/" (for a .zip: its path without ".zip", only a virtual folder)
  IsArchive.i
  Pack.i             ; pack number, valid when IsArchive
  Map EntrySize.i()  ; archive files: name -> uncompressed size
EndStructure

; Settings given by the IDE (setup()) or by the standalone tool.
Structure SettingsState
  Language$          ; "English", "French" or "German"
  OsName$            ; "Windows", "Linux" or "MacOS"
  UserLibPath$       ; folder of the user libraries help files ("" = none)
  ExamplePath$       ; IDE folder that contains Examples/ ("" = none)
  HelpPath$          ; standalone: help source (PBHelp.ini)
  StartContents.i    ; standalone: contents shown at start (PBHelp.ini)
  StartFilters.i     ; standalone: filters (chips) shown at start
  StartSticky.i      ; standalone: window always on top
  DarkMode.i         ; standalone: dark colors
EndStructure

; One help page: a library, a guide, a function or a generated page.
Structure PageInfo
  Title$             ; title shown in the page and in the contents
  Name$              ; lowercase key (function name, "lib_<file>", "reference"...)
  File$              ; source file, relative to the language folder (or to the userlib folder)
  Position.l         ; position of the page in its source file
  Source$            ; DocMaker source of the page
  Navigation$        ; "< previous | library index | next >" line of the function pages
  List SubPages.i()  ; library page: pointers to its function pages
  ContentsRow.w      ; row of the page in the contents tree
  UserLib$           ; user library file name ("" = PureBasic page)
  LibDest$           ; user library: library the function is attached to
  Group$             ; library of the page (search chips)
  ExampleFile$       ; example pages: name of the example file ("" for the other pages)
EndStructure

; One DocMaker tag and its html.
Structure TagInfo
  Html$              ; html code, may contain $p1 $p2 $lg $ex $im $ose
  Param.b            ; 1: function parameter, 2: optional parameter, 3: end of the parameters
  Title.b            ; 1: title level tag (the line feeds around it are ignored)
  Pre.w              ; 1: opens <pre>, -1: closes </pre>
EndStructure

; Page style and example buttons (replaced by the IDE theme, see HelpRender.pbi).
Structure ThemeState
  Colors$            ; CSS variables in use
  ColorsLight$       ; built-in light palette
  ColorsDark$        ; built-in dark palette
  Dark.i             ; #True: dark palette selected
  ColorsCustom$      ; colors given by the IDE (SetColors)
  Custom.i           ; #True: the IDE gave colors
  Style$             ; CSS
  UserLibColor.i     ; color of the user libraries in the contents tree
  IconOpen$          ; html of the "open example" button
  IconRun$           ; html of the "run example" button
  IconCopy$          ; html of the "copy example" button
EndStructure

; Toolbar icons (index of Ui\Img[]).
Enumeration ToolbarIcon
  #IconContents
  #IconFilters
  #IconBack
  #IconForward
  #IconTools
  #IconHome
  #IconEdit
EndEnumeration

CompilerSelect #PB_Compiler_OS ; font that has the symbols of the toolbar icons
  CompilerCase #PB_OS_Windows
    #IconFontName$ = "Segoe UI Symbol"
  CompilerCase #PB_OS_MacOS
    #IconFontName$ = "Apple Symbols"
  CompilerDefault
    #IconFontName$ = "DejaVu Sans"
CompilerEndSelect

; One search chip (one per library, plus All).
Structure ChipInfo
  Name$
  Caption$
  Gadget.i
  Width.l
  IsAll.b            ; 1 = the All chip
EndStructure

; One search result with its sort key (rank + title).
Structure ResultInfo
  Key$
  *Page.PageInfo
EndStructure

; Gadgets, images and window of the user interface.
Structure UiState
  Dialog.i
  Xml.i
  Window.i           ; standalone window
  Root.i             ; IDE: root gadget of the dialog
  Panel.i            ; tabs (contents, search)
  Contents.i         ; contents tree
  Search.i           ; search string
  Results.i          ; search results list
  Chips.i            ; scroll area of the chips (owned by the dialog)
  Web.i
  Back.i
  Forward.i
  Home.i
  Edit.i
  Language.i         ; standalone combo boxes
  Os.i
  Splitter.i
  ToggleContents.i   ; IDE toggle buttons
  ToggleFilters.i
  ModeTools.i        ; IDE: toggle "in the tools panel" (ON) / "in a window" (OFF)
  Sticky.i           ; standalone: check box "always on top"
  ThemeImg.i[7]      ; toolbar images given by the IDE theme (SetImages), index = #Icon...
  Img.i[7]           ; toolbar images in use
  OwnImg.i[7]        ; #True: the image was drawn by the module (freed by Destroy)
  ChipFont.i
  ChipHeight.i
  WinX.i
  WinY.i
  WinW.i
  WinH.i
EndStructure

; State of the displayed page.
Structure ViewState
  PageName$          ; name of the page displayed
  *Page.PageInfo     ; page displayed
  *Selected.PageInfo
  Zoom.f             ; page zoom (Ctrl+wheel or Ctrl +/-), kept for the next pages
  IeMode.i           ; Windows: WebView2 not available, degraded display in a WebGadget (Internet Explorer)
  ContentsVisible.i  ; IDE: contents shown
  FiltersVisible.i   ; chips shown
  FiltersMargin.i    ; space under the chips (to give the freed height to the results list when they are hidden)
  InToolsPanel.i     ; IDE: shown in the tools panel (1) or in a window (0)
  SplitPos.i         ; IDE: splitter position
  BarWidth.i         ; IDE: splitter bar width (-1: not measured yet)
  EditDate.q
  HostWindow.i       ; window that contains the help (deferred events)
EndStructure

Global HelpSource.HelpSourceState
Global Settings.SettingsState
Global Theme.ThemeState
Global Ui.UiState
Global View.ViewState
Global NewList History.s()               ; pages shown (back / forward)
Global NewList JsMessages.s()            ; javascript messages waiting for the event loop
Global NewList Chips.ChipInfo()          ; search chips
Global NewMap AdaptedImage.i()          ; dark mode: lightened copy of an icon of the IDE (key = image number)

Global NewList Pages.PageInfo()          ; all the pages
Global NewMap *PageByName.PageInfo()     ; page by lowercase name
Global NewMap UserLibDest$()            ; user library function (lowercase) -> library it is attached to
Global NewMap Tags.TagInfo()             ; DocMaker tags (lowercase) -> html
Global NewMap OsInfo$()                 ; OSSpecificFunctions.txt: function (lowercase) -> supported OS information
Global ParserErrors$                     ; errors found by the last PageToHtml()
