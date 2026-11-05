; --------------------------------------------------------------------------------------------
;  Copyright (c) Fantaisie Software. All rights reserved.
;  Dual licensed under the GPL and Fantaisie Software licenses.
;  See LICENSE and LICENSE-FANTAISIE in the project root for license information.
; --------------------------------------------------------------------------------------------

; Cross-platform help tool: reads the documentation sources (.txt, DocMaker format) directly
; and renders them in a WebViewGadget.
;
; When this file is compiled directly (main file), it runs as a standalone tool (own window,
; PBHelp.ini settings). When included in the IDE, it's embedded in the tools panel via XmlDialogGadget().

; HOW IT WORKS
;   Source   : the help is a folder or a Help.zip (read in memory): one .txt per library/guide, DocMaker format.
;   Pages    : each @Function and each library/guide file becomes a page; some pages are generated
;              (osspecific, commandindex, pbconstants). The contents tree comes from the "reference" page.
;   Parser   : a page is converted from DocMaker to html (tags table, @OS blocks, examples buttons) and shown in the WebView.
;   Search   : ranked search in the titles and sources, filtered by library chips.
;   Ui       : Dialog (XML) with the tabs Contents / Search and the toolbar; the zoom, mouse buttons and Escape are handled
;              by the page itself (javascript -> jsmessage() -> deferred in the event loop).
;   Texts    : Language("HelpTool", Key$), the translations are in the HelpTool block of each language (Catalog).

DeclareModule pbhelp
  #Standalone = #PB_Compiler_IsMainFile

  ; Callbacks used by the IDE to load/run the examples and edit the help sources
  Prototype ProtoOpenCode(File$, Code$, Run) ; File$ is a real file to load, or Code$ is the code to put in a new tab
  Prototype ProtoEditFile(File$, Line)
  Prototype ProtoApplyColors(Gadget) ; IDE colors/font for the contents tree and the search gadgets
  Prototype.s ProtoColorCode(Code$)  ; IDE syntax highlighting of an example: returns the html code (special characters escaped)
  Prototype ProtoClose()             ; Escape in the help: give the focus back to the editor
  Prototype ProtoMode(InToolsPanel)  ; toggle button "in the tools panel": 1 = tools panel, 0 = window
  Prototype.s ProtoLanguage(Group$, Key$) ; IDE: text of the language files (Language()), instead of the built-in translations
  Global OpenCodeCallback.ProtoOpenCode, EditFileCallback.ProtoEditFile, ApplyColorsCallback.ProtoApplyColors, ColorCodeCallback.ProtoColorCode, CloseCallback.ProtoClose, ModeCallback.ProtoMode, LanguageCallback.ProtoLanguage

  Declare Init(LanguageName$, SystemName$)
  Declare.s BuildHelpFolder(Source$, Destination$)
  Declare.s BuildHelpZip(Source$, Destination$)
  Declare.s CheckSources(Source$)
  Declare.s ConvertSources(Folder$)

  ; IDE embedding
  Declare Setup(LanguageName$, SystemName$, Source$, UserLibSource$, ExampleSource$)
  Declare SetImages(Back, Forward, Home, Edit, Index, Open$, Run$, Filters = 0, Copy$ = "", ModeTools = 0)
  Declare SetColors(Css$, UserLibColor = $008800)
  Declare Create(Window)
  Declare Destroy()
  Declare SetMode(InToolsPanel)
  Declare EnableDarkMode(Enable = #True)
  Declare Resize(Width, Height)
  Declare GadgetEvent(Gadget, Type)
  Declare Timer()
  Declare Show(Page$)
EndDeclareModule

Module pbhelp
  EnableExplicit
  
  IncludePath "HelpTool" ; the includes are in the subfolder HelpTool
  XIncludeFile "HelpConfig.pbi"
  XIncludeFile "HelpCatalog.pbi"
  XIncludeFile "HelpText.pbi"
  XIncludeFile "HelpSource.pbi"
  XIncludeFile "HelpRender.pbi"
  XIncludeFile "HelpParser.pbi"
  XIncludeFile "HelpPages.pbi"
  XIncludeFile "HelpBuild.pbi"
  XIncludeFile "HelpSearch.pbi"
  XIncludeFile "HelpUi.pbi"
  IncludePath ""

  DisableExplicit
EndModule

; Dark colors for the pages of the help (standalone or IDE).
Procedure Help_EnableDarkMode(Enable = #True)
  pbhelp::EnableDarkMode(Enable)
EndProcedure

  
CompilerIf #PB_Compiler_IsMainFile

  ;Debug pbhelp::CheckSources(#PB_Compiler_Home + "Help/Help.zip")
  ;pbhelp::ConvertSources("<documentation sources folder>")

  ; HelpTool --init <helpsourcepath> <helpdestinationpath>
  ;   builds the help folder used by the help tool from the documentation sources (the 'Documentation' folder)
  ; HelpTool --initzip <helpsourcepath> <helpdestinationzip>
  ;   same, but builds a zip archive (ie: 'Help/Help.zip', the default help source of the IDE)
  If ProgramParameter(0)="--init" Or ProgramParameter(0)="--initzip"
    If CountProgramParameters()<>3
      Errors$ = "Usage: HelpTool --init <helpsourcepath> <helpdestinationpath>"+#LF$+
                "       HelpTool --initzip <helpsourcepath> <helpdestinationzip>"+#LF$
    ElseIf ProgramParameter(0)="--initzip"
      Errors$ = pbhelp::BuildHelpZip(ProgramParameter(1), ProgramParameter(2))
    Else
      Errors$ = pbhelp::BuildHelpFolder(ProgramParameter(1), ProgramParameter(2))
    EndIf
    If Errors$ <> ""
      If OpenConsole()
        ConsoleError(RTrim(Errors$, #LF$))
      EndIf
      End 1
    EndIf
    End
  EndIf
  
  ; Choose default language for the standalone HelpTool
  pbhelp::Init("French", "Windows") 
  ;pbhelp::Init("German", "Windows")
  ;pbhelp::Init("English", "Windows")
  
CompilerElse

  UsePNGImageEncoder()

  Global HelpToolSource$, Backup_HelpToolSource$


  Procedure.s HelpTool_DefaultSource()
    ProcedureReturn PureBasicPath$ + "Help" + #Separator + "Help.zip"
  EndProcedure


  Procedure.s HelpTool_Language(Source$)
    Select UCase(CurrentLanguage$)
      Case "FRANCAIS"
        Language$ = "French"
      Case "DEUTSCH"
        Language$ = "German"
      Default
        Language$ = "English"
    EndSelect

    ; Fallback to english if the help isn't available in the IDE language
    If Right(Source$, 1) <> "/" And Right(Source$, 1) <> "\"
      Source$ + #Separator
    EndIf
    If FileSize(Source$) = -2 And FileSize(Source$ + Language$) <> -2
      Language$ = "English"
    EndIf

    ProcedureReturn Language$
  EndProcedure


  Procedure.s HelpTool_ImageBase64(Image)
    If IsImage(Image)
      *Buffer = EncodeImage(Image, #PB_ImagePlugin_PNG)
      If *Buffer
        Result$ = Base64Encoder(*Buffer, MemorySize(*Buffer))
        FreeMemory(*Buffer)
      EndIf
    EndIf

    ProcedureReturn Result$
  EndProcedure


  Procedure.s HelpTool_HtmlColor(Color)
    ProcedureReturn "#" + RSet(Hex(Red(Color)), 2, "0") + RSet(Hex(Green(Color)), 2, "0") + RSet(Hex(Blue(Color)), 2, "0")
  EndProcedure


  ; Mix Color1 with Color2 (Ratio = 0.0 -> Color1, 1.0 -> Color2)
  ;
  Procedure HelpTool_MixColor(Color1, Color2, Ratio.f)
    ProcedureReturn RGB(Red(Color1)   + (Red(Color2)   - Red(Color1))   * Ratio,
                        Green(Color1) + (Green(Color2) - Green(Color1)) * Ratio,
                        Blue(Color1)  + (Blue(Color2)  - Blue(Color1))  * Ratio)
  EndProcedure


  ; Examples syntax highlighting, with the IDE highlighting engine
  ;
  Global *HelpTool_HtmlBuffer, HelpTool_HtmlSize, HelpTool_HtmlLength

  Procedure HelpTool_HtmlWrite(*Text.Ascii, Length, Escape)
    If HelpTool_HtmlLength + Length * 5 > HelpTool_HtmlSize ; worst case: every char escaped as "&amp;"
      HelpTool_HtmlSize = (HelpTool_HtmlLength + Length * 5) * 2
      *HelpTool_HtmlBuffer = ReAllocateMemory(*HelpTool_HtmlBuffer, HelpTool_HtmlSize, #PB_Memory_NoClear)
    EndIf

    *Output = *HelpTool_HtmlBuffer + HelpTool_HtmlLength
    *TextEnd = *Text + Length
    While *Text < *TextEnd
      If Escape And *Text\a = '<'
        PokeS(*Output, "&lt;", -1, #PB_Ascii|#PB_String_NoZero) : *Output + 4
      ElseIf Escape And *Text\a = '>'
        PokeS(*Output, "&gt;", -1, #PB_Ascii|#PB_String_NoZero) : *Output + 4
      ElseIf Escape And *Text\a = '&'
        PokeS(*Output, "&amp;", -1, #PB_Ascii|#PB_String_NoZero) : *Output + 5
      Else
        PokeA(*Output, *Text\a) : *Output + 1
      EndIf
      *Text + 1
    Wend
    HelpTool_HtmlLength = *Output - *HelpTool_HtmlBuffer
  EndProcedure

  Procedure HelpTool_HtmlWriteTag(Tag$)
    *Tag = Ascii(Tag$)
    HelpTool_HtmlWrite(*Tag, MemorySize(*Tag) - 1, #False)
    FreeMemory(*Tag)
  EndProcedure

  ; The buffer is UTF-8, written byte by byte, so a token can't split a multi-byte character
  ;
  Procedure HelpTool_ColorCodeCallback(*StringStart, Length, *Color, IsBold, TextChanged)
    Style = *Color
    If Style >= #STYLE_FirstIssue ; issue highlighting in comments (ie: 'TODO')
      Style = 3
    EndIf

    If Style > 1 And Style <= 16
      HelpTool_HtmlWriteTag("<span class='s" + Str(Style) + "'>")
      HelpTool_HtmlWrite(*StringStart, Length, #True)
      HelpTool_HtmlWriteTag("</span>")
    Else
      HelpTool_HtmlWrite(*StringStart, Length, #True)
    EndIf
  EndProcedure

  Procedure.s HelpTool_ColorCode(Code$)
    *Buffer = UTF8(Code$)
    If *Buffer
      HelpTool_HtmlLength = 0
      HighlightingEngine(*Buffer, MemorySize(*Buffer) - 1, 0, @HelpTool_ColorCodeCallback(), #False, #True) ; no case correction
      FreeMemory(*Buffer)
      If *HelpTool_HtmlBuffer
        Result$ = PeekS(*HelpTool_HtmlBuffer, HelpTool_HtmlLength, #PB_UTF8|#PB_ByteLength)
      EndIf
    EndIf

    ProcedureReturn Result$
  EndProcedure

  DataSection
    HelpTool_StyleColors: ; Color for the Scintilla styles 1 to 16 (see SetUpHighlightingColors())
    Data.l #COLOR_NormalText, #COLOR_BasicKeyword, #COLOR_Comment, #COLOR_Constant, #COLOR_String, #COLOR_PureKeyword, #COLOR_ASMKeyword, #COLOR_Operator
    Data.l #COLOR_Structure, #COLOR_Number, #COLOR_Pointer, #COLOR_Separator, #COLOR_Label, #COLOR_CustomKeyword, #COLOR_Module, #COLOR_BadBrace
  EndDataSection


  ; Build the help page colors (CSS variables) from the current editor color scheme
  ;
  Procedure.s HelpTool_ThemeColors()
    Background = Colors(#COLOR_GlobalBackground)\DisplayValue
    Text       = Colors(#COLOR_NormalText)\DisplayValue

    ; Title bar: current line color when it's used, or a darker/lighter shade of the background
    If Colors(#COLOR_CurrentLine)\Enabled And Colors(#COLOR_CurrentLine)\DisplayValue <> Background
      TitleBackground = Colors(#COLOR_CurrentLine)\DisplayValue
    Else
      TitleBackground = HelpTool_MixColor(Background, Text, 0.12)
    EndIf

    ; Tables are a bit brighter than the page on light themes (like the original white), and a bit lighter on dark themes
    If (Red(Background) + Green(Background) + Blue(Background)) / 3 >= 128
      TableBackground = HelpTool_MixColor(Background, $FFFFFF, 0.7)
      ColorScheme$ = "light"
    Else
      TableBackground = HelpTool_MixColor(Background, Text, 0.06)
      ColorScheme$ = "dark"
    EndIf

    ; 'color-scheme' is needed, or the webview uses the OS theme for the scrollbars and buttons (dark scrollbars on a light page)
    Css$ = ":root {color-scheme: " + ColorScheme$ + "; "
    Css$ + "--bg:"       + HelpTool_HtmlColor(Background) + "; "
    Css$ + "--text:"     + HelpTool_HtmlColor(Text) + "; "
    Css$ + "--titlebg:"  + HelpTool_HtmlColor(TitleBackground) + "; "
    Css$ + "--codebg:"   + HelpTool_HtmlColor(HelpTool_MixColor(Background, Text, 0.07)) + "; "
    Css$ + "--tablebg:"  + HelpTool_HtmlColor(TableBackground) + "; "
    Css$ + "--optbg:"    + HelpTool_HtmlColor(HelpTool_MixColor(TableBackground, Text, 0.07)) + "; "
    Css$ + "--border:"   + HelpTool_HtmlColor(HelpTool_MixColor(Background, Text, 0.25)) + "; "
    Css$ + "--notebg:"   + HelpTool_HtmlColor(HelpTool_MixColor(Background, RGB(255, 136, 0), 0.5)) + "; " ; orange note (platform-specific functions, errors), readable with the theme text color
    Css$ + "--link:"     + HelpTool_HtmlColor(Colors(#COLOR_BasicKeyword)\DisplayValue) + "; "
    Css$ + "--constant:" + HelpTool_HtmlColor(Colors(#COLOR_Constant)\DisplayValue) + "; "
    Css$ + "--function:" + HelpTool_HtmlColor(Colors(#COLOR_PureKeyword)\DisplayValue) + "; "
    Css$ + "--keyword:"  + HelpTool_HtmlColor(Colors(#COLOR_BasicKeyword)\DisplayValue) + "; "
    Css$ + "--userlib:"  + HelpTool_HtmlColor(Colors(#COLOR_CustomKeyword)\DisplayValue) + ";}"

    ; Examples syntax highlighting (see HelpTool_ColorCode()): one class per Scintilla style (see SetUpHighlightingColors())
    If EnableColoring
      Restore HelpTool_StyleColors
      For Style = 1 To 16
        Read.l ColorIndex
        Css$ + " pre.ex .s" + Str(Style) + " {color:" + HelpTool_HtmlColor(Colors(ColorIndex)\DisplayValue) + ";"
        If EnableKeywordBolding And (Style = 2 Or Style = 14)
          Css$ + " font-weight:bold;"
        EndIf
        Css$ + "}"
      Next Style
    EndIf

    ProcedureReturn Css$
  EndProcedure


  ; Called by the help when 'Load' or 'Run' is clicked on an example
  ;
  ; Texts of the help tool: the [HelpTool] section of the language files of the IDE.
  Procedure.s HelpTool_Text(Group$, Key$)
    ProcedureReturn Language(Group$, Key$)
  EndProcedure

  ; Escape in the help: gives the focus back to the editor (to complete in the IDE: ie SetActiveGadget() of the active source).
  Procedure HelpTool_Close()

  EndProcedure


  ; Toggle button "in the tools panel" of the help (1 = show the help in the tools panel, 0 = in a window): to complete in the IDE.
  Procedure HelpTool_Mode(InToolsPanel)

  EndProcedure


  Procedure HelpTool_OpenCode(File$, Code$, Run)

    If File$ ; Real example file: load it directly, so relative paths to its data are working
      If LoadSourceFile(File$) = 0
        ProcedureReturn
      EndIf

    Else ; Code snippet: put it in a new source
      TempFile$ = GetTemporaryDirectory() + "PB_HelpExample.pb"
      File = CreateFile(#PB_Any, TempFile$, #PB_UTF8)
      If File = 0
        ProcedureReturn
      EndIf
      WriteStringFormat(File, #PB_UTF8)
      WriteString(File, Trim(Code$, #LF$))
      CloseFile(File)

      NewSource("", #False)
      LoadTempFile(TempFile$)
      DeleteFile(TempFile$)
      UpdateSourceStatus(1)
      HistoryEvent(*ActiveSource, #HISTORY_Create)
    EndIf

    If Run And *ActiveSource And *ActiveSource <> *ProjectInfo
      ForceDebugger = 0   ; use the source file setting
      ForceNoDebugger = 0
      CompileRun(#False)
    EndIf

  EndProcedure


  ; Called by the help when 'Edit' is clicked, to edit the help source of the current page
  ;
  Procedure HelpTool_EditFile(File$, Line)
    If LoadSourceFile(File$) And *ActiveSource And IsEqualFile(*ActiveSource\FileName$, File$)
      ChangeActiveLine(Line, -5)
    EndIf
  EndProcedure


  ; Display the given help page in the tool, opening the tool if needed (Page$ is a page name or a path as used
  ; in the html help, ie: "2DDrawing/Box.html"). Displays the home page and returns #False if the page doesn't exist
  ;
  Procedure HelpTool_DisplayPage(Page$)
    ActivateTool("HelpTool") ; switches to the tool, or opens it in its own window if it's not in the tools panel
    If HelpToolOpen = #False
      ProcedureReturn #False
    EndIf

    Page$ = ReplaceString(Page$, "\", "/")
    Name$ = LCase(GetFilePart(Page$, #PB_FileSystem_NoExtension))
    If Name$ = ""
      Name$ = "reference"
    ElseIf Name$ = "index" ; library index page: "2DDrawing/index.html"
      Name$ = "lib_" + LCase(GetFilePart(RTrim(GetPathPart(Page$), "/")))
    EndIf

    If pbhelp::show(Name$)
      ProcedureReturn #True
    EndIf

    pbhelp::show("reference")
    ProcedureReturn #False
  EndProcedure


  CompilerIf #CompileWindows = 0 ; Windows has its own version, which also handles the API, ASM and user libraries help (WindowsHelp.pb)

    Procedure DisplayHelp(CurrentWord$)
      If CurrentWord$ = ""
        Page$ = ""
      ElseIf CheckPureBasicKeyWords(CurrentWord$) <> ""
        Page$ = CheckPureBasicKeyWords(CurrentWord$)
      Else
        Page$ = CurrentWord$ ; command name, which is the page name in the help tool
      EndIf

      HelpTool_DisplayPage(Page$)
    EndProcedure

  CompilerEndIf


  Procedure HelpTool_Timer()
    pbhelp::timer()
  EndProcedure


  Procedure Help_CreateFunction(*Entry.ToolsPanelEntry)

    Source$ = HelpToolSource$
    If Source$ = ""
      Source$ = HelpTool_DefaultSource()
    EndIf

    CompilerIf #CompileWindows
      OS$ = "Windows"
    CompilerElseIf #CompileLinux
      OS$ = "Linux"
    CompilerElse
      OS$ = "MacOS"
    CompilerEndIf

    pbhelp::OpenCodeCallback = @HelpTool_OpenCode()
    pbhelp::EditFileCallback = @HelpTool_EditFile()
    pbhelp::ColorCodeCallback = @HelpTool_ColorCode()
    pbhelp::CloseCallback = @HelpTool_Close()
    pbhelp::ModeCallback = @HelpTool_Mode()
    pbhelp::LanguageCallback = @HelpTool_Text()
    ; User libraries in the contents tree: same color as in the help pages, when the tree uses the IDE colors
    If (*Entry\IsSeparateWindow = 0 Or NoIndependentToolsColors = 0) And ToolsPanelUseColors
      UserLibColor = Colors(#COLOR_CustomKeyword)\DisplayValue
    Else
      UserLibColor = $008800
    EndIf
    If *Entry\IsSeparateWindow = 0 Or NoIndependentToolsColors = 0
      pbhelp::ApplyColorsCallback = @ToolsPanel_ApplyColors()
    Else
      pbhelp::ApplyColorsCallback = 0
    EndIf
    pbhelp::setcolors(HelpTool_ThemeColors(), UserLibColor)
    CompilerIf Defined(DisplayDarkMode, #PB_Variable) ; IDE option [Global] DisplayDarkMode of PureBasic.prefs
      pbhelp::EnableDarkMode(DisplayDarkMode)
    CompilerEndIf
    pbhelp::setimages(#IMAGE_Help_Back, #IMAGE_Help_Forward, #IMAGE_Help_Home, #IMAGE_Help_Edit, #IMAGE_Help_Index, HelpTool_ImageBase64(#IMAGE_Help_LoadCode), HelpTool_ImageBase64(#IMAGE_Help_RunCode))
    pbhelp::setup(HelpTool_Language(Source$), OS$, Source$, PureBasicPath$ + "PureLibraries" + #Separator + "UserLibraries" + #Separator, PureBasicPath$ + "Examples" + #Separator)

    If *Entry\IsSeparateWindow
      pbhelp::create(*Entry\ToolWindowID)
    Else
      pbhelp::create(#WINDOW_Main)
    EndIf

    ; Reload the help when its source is modified (help edition)
    AddWindowTimer(#WINDOW_Main, #TIMER_HelpTool, 1000)
    BindEvent(#PB_Event_Timer, @HelpTool_Timer(), #WINDOW_Main, #TIMER_HelpTool)

    HelpToolOpen = #True

  EndProcedure

  Procedure Help_DestroyFunction(*Entry.ToolsPanelEntry)

    RemoveWindowTimer(#WINDOW_Main, #TIMER_HelpTool)
    UnbindEvent(#PB_Event_Timer, @HelpTool_Timer(), #WINDOW_Main, #TIMER_HelpTool)
    pbhelp::destroy()

    HelpToolOpen = #False

  EndProcedure


  Procedure Help_ResizeHandler(*Entry.ToolsPanelEntry, PanelWidth, PanelHeight)

    pbhelp::resize(PanelWidth, PanelHeight)

  EndProcedure

  Procedure Help_EventHandler(*Entry.ToolsPanelEntry, EventGadgetID)

    pbhelp::gadgetevent(EventGadgetID, EventType())

  EndProcedure


  Procedure Help_PreferenceLoad(*Entry.ToolsPanelEntry)

    PreferenceGroup("HelpTool")
    HelpToolSource$ = ReadPreferenceString("HelpSource", "")

  EndProcedure


  Procedure Help_PreferenceSave(*Entry.ToolsPanelEntry)

    PreferenceComment("")
    PreferenceGroup("HelpTool")
    WritePreferenceString("HelpSource", HelpToolSource$)

  EndProcedure


  Procedure Help_PreferenceStart(*Entry.ToolsPanelEntry)

    ; Use the backup variable during the PReferences changing
    Backup_HelpToolSource$ = HelpToolSource$

  EndProcedure


  Procedure Help_PreferenceApply(*Entry.ToolsPanelEntry)

    ; put the backup variable back
    HelpToolSource$ = Backup_HelpToolSource$

  EndProcedure



  Procedure Help_PreferenceCreate(*Entry.ToolsPanelEntry)

    y = 10

    TextGadget(#GADGET_Preferences_HelpSourceText, 10, y, 300, 25, Language("Help","HelpSource"))
    GetRequiredSize(#GADGET_Preferences_HelpSourceText, @Width, @Height)
    ResizeGadget(#GADGET_Preferences_HelpSourceText, 10, y, 300, Height)
    y + Height + 5

    ButtonGadget(#GADGET_Preferences_HelpSourceBrowse, 0, 0, 0, 0, "...")
    GetRequiredSize(#GADGET_Preferences_HelpSourceBrowse, @Width, @Height)
    StringGadget(#GADGET_Preferences_HelpSource, 10, y, 300-Width-5, Height, Backup_HelpToolSource$)
    ResizeGadget(#GADGET_Preferences_HelpSourceBrowse, 310-Width, y, Width, Height)

  EndProcedure


  Procedure Help_PreferenceDestroy(*Entry.ToolsPanelEntry)

    Backup_HelpToolSource$ = GetGadgetText(#GADGET_Preferences_HelpSource)

  EndProcedure


  Procedure Help_PreferenceEvents(*Entry.ToolsPanelEntry, EventGadgetID)

    If EventGadgetID = #GADGET_Preferences_HelpSourceBrowse
      Path$ = GetGadgetText(#GADGET_Preferences_HelpSource)
      If Path$ = ""
        Path$ = HelpTool_DefaultSource()
      EndIf
      If LCase(GetExtensionPart(Path$)) = "zip" ; help archive: start in its folder
        Path$ = GetPathPart(Path$)
      EndIf

      Path$ = PathRequester(Language("Help","HelpSource"), Path$)
      If Path$
        SetGadgetText(#GADGET_Preferences_HelpSource, Path$)
      EndIf
    EndIf

  EndProcedure

  Procedure Help_PreferenceChanged(*Entry.ToolsPanelEntry, IsConfigOpen)

    If IsConfigOpen
      If HelpToolSource$ <> GetGadgetText(#GADGET_Preferences_HelpSource)
        ProcedureReturn 1
      EndIf

    Else
      If HelpToolSource$ <> Backup_HelpToolSource$
        ProcedureReturn 1
      EndIf

    EndIf

    ProcedureReturn 0
  EndProcedure


  ;- Initialisation code
  ; This will make this Tool available to the editor
  ;
  Help_VT.ToolsPanelFunctions

  Help_VT\CreateFunction      = @Help_CreateFunction()
  Help_VT\DestroyFunction     = @Help_DestroyFunction()
  Help_VT\ResizeHandler       = @Help_ResizeHandler()
  Help_VT\EventHandler        = @Help_EventHandler()
  Help_VT\PreferenceLoad      = @Help_PreferenceLoad()
  Help_VT\PreferenceSave      = @Help_PreferenceSave()
  Help_VT\PreferenceStart     = @Help_PreferenceStart()
  Help_VT\PreferenceApply     = @Help_PreferenceApply()
  Help_VT\PreferenceCreate    = @Help_PreferenceCreate()
  Help_VT\PreferenceDestroy   = @Help_PreferenceDestroy()
  Help_VT\PreferenceEvents    = @Help_PreferenceEvents()
  Help_VT\PreferenceChanged   = @Help_PreferenceChanged()


  AddElement(AvailablePanelTools())

  AvailablePanelTools()\FunctionsVT          = @Help_VT
  AvailablePanelTools()\NeedPreferences      = 1 ; the help source is stored in the "HelpTool" group
  AvailablePanelTools()\NeedConfiguration    = 1
  AvailablePanelTools()\PreferencesWidth     = 320
  AvailablePanelTools()\PreferencesHeight    = 80
  AvailablePanelTools()\NeedDestroyFunction  = 1
  AvailablePanelTools()\ToolID$              = "HelpTool"
  AvailablePanelTools()\PanelTitle$          = "HelpToolShort"
  AvailablePanelTools()\ToolName$            = "HelpToolLong"

CompilerEndIf
