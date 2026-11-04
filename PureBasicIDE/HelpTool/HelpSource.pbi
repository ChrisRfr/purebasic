; ----------------------------------------------------------------------------
;---------- Source ---------
; ----------------------------------------------------------------------------
; Access to the help source (folder or .zip) and small disk helpers.
; Included inside Module pbhelp (EnableExplicit is active).
; Names in the source are relative to the help root and use "/" (ie: "English/Reference/reference.txt").

; ----------------------------------------------------------------------------
;- Disk helpers
; ----------------------------------------------------------------------------

; Reads a whole UTF-8 text file (BOM removed). Returns "" if it can't be read.
Procedure.s FileReadText(Path$, ShowError = #True)
  Protected File, Text$

  File = ReadFile(#PB_Any, Path$, #PB_UTF8 | #PB_File_SharedRead)
  If File = 0
    If ShowError
      MessageRequester("Error loading :", "file : " + Path$)
    EndIf
    ProcedureReturn ""
  EndIf
  ReadStringFormat(File) ; skips the BOM
  Text$ = ReadString(File, #PB_UTF8 | #PB_File_IgnoreEOL)
  CloseFile(File)
  ProcedureReturn Text$
EndProcedure

; Writes a UTF-8 text file (replaces an existing one). Returns #True if done.
Procedure FileWriteText(Path$, Text$)
  Protected File

  If FileSize(Path$) >= 0
    DeleteFile(Path$)
  EndIf
  File = CreateFile(#PB_Any, Path$, #PB_UTF8)
  If File = 0
    ProcedureReturn #False
  EndIf
  WriteString(File, Text$)
  CloseFile(File)
  ProcedureReturn #True
EndProcedure

; Creates a folder and its parents. Returns #True if the folder exists afterwards.
Procedure DirectoryCreateTree(Dir$)
  Dir$ = RTrim(ReplaceString(Dir$, "\", "/"), "/")
  If Dir$ = "" Or FileSize(Dir$) = -2
    ProcedureReturn #True
  EndIf
  DirectoryCreateTree(GetPathPart(Dir$))
  ProcedureReturn CreateDirectory(Dir$)
EndProcedure

; Recursive part of DirectoryListFiles(). Extensions$ is already normalized (",txt,png," or ",,"),
; BaseLength is the length of the starting folder (0 = this call is the first one).
Procedure DirectoryListRecursive(List Files$(), Dir$, Extensions$, BaseLength)
  Protected Directory, IsDirectory
  Protected Name$

  If Right(Dir$, 1) <> "/"
    Dir$ + "/"
  EndIf
  If BaseLength = 0
    BaseLength = Len(Dir$)
  EndIf
  Directory = ExamineDirectory(#PB_Any, Dir$, "")
  If Directory = 0
    ProcedureReturn
  EndIf
  While NextDirectoryEntry(Directory)
    Name$ = DirectoryEntryName(Directory)
    If Name$ = "." Or Name$ = ".."
      Continue
    EndIf
    IsDirectory = Bool(DirectoryEntryType(Directory) = #PB_DirectoryEntry_Directory)
    If IsDirectory
      DirectoryListRecursive(Files$(), Dir$ + Name$, Extensions$, BaseLength)
    ElseIf Extensions$ = ",," Or FindString(Extensions$, "," + LCase(GetExtensionPart(Name$)) + ",")
      AddElement(Files$())
      Files$() = Mid(Dir$ + Name$, BaseLength + 1)
    EndIf
  Wend
  FinishDirectory(Directory)
EndProcedure

; Lists the files of a disk folder and its subfolders, relative to Dir$.
; Extensions$ = "txt" or "txt,png" ("" = all files).
Procedure DirectoryListFiles(List Files$(), Dir$, Extensions$ = "")
  ClearList(Files$())
  DirectoryListRecursive(Files$(), Dir$, "," + LCase(Extensions$) + ",", 0)
EndProcedure

; ----------------------------------------------------------------------------
;- Help source (folder or .zip)
; ----------------------------------------------------------------------------

; Language folder of the help source ("English/").
Procedure.s LanguageFolder()
  ProcedureReturn Settings\Language$ + "/"
EndProcedure

; Reads the list of the files of the archive (name -> uncompressed size).
Procedure SourceReadEntries()
  ClearMap(HelpSource\EntrySize())
  If ExaminePack(HelpSource\Pack)
    While NextPackEntry(HelpSource\Pack)
      If PackEntryType(HelpSource\Pack) = #PB_Packer_File
        HelpSource\EntrySize(PackEntryName(HelpSource\Pack)) = PackEntrySize(HelpSource\Pack, #PB_Packer_UncompressedSize)
      EndIf
    Wend
  EndIf
EndProcedure

; Closes the current source.
Procedure SourceClose()
  If HelpSource\IsArchive
    ClosePack(HelpSource\Pack)
  EndIf
  HelpSource\IsArchive = #False
  HelpSource\Pack = 0
  ClearMap(HelpSource\EntrySize())
EndProcedure

; Opens a help source: a .zip archive or a folder. If the archive can't be opened, the path is used as a folder.
Procedure SourceOpen(Path$)
  SourceClose()
  HelpSource\Path$ = Path$
  If LCase(GetExtensionPart(Path$)) = "zip" And FileSize(Path$) > 0
    HelpSource\Root$ = Left(Path$, Len(Path$) - 4)
    UseZipPacker()
    HelpSource\Pack = OpenPack(#PB_Any, Path$)
    If HelpSource\Pack
      HelpSource\IsArchive = #True
      SourceReadEntries()
    EndIf
  Else
    HelpSource\Root$ = Path$
  EndIf
  If Right(HelpSource\Root$, 1) <> "/" And Right(HelpSource\Root$, 1) <> "\"
    HelpSource\Root$ + "/"
  EndIf
EndProcedure

; Reads a text file of the source (UTF-8, BOM removed in both cases). Returns "" if it doesn't exist.
Procedure.s SourceReadText(Name$, ShowError = #True)
  Protected *Memory, Size
  Protected Text$

  If HelpSource\IsArchive = #False
    ProcedureReturn FileReadText(HelpSource\Root$ + Name$, ShowError)
  EndIf

  If FindMapElement(HelpSource\EntrySize(), Name$) = 0
    If ShowError
      MessageRequester("Error loading :", "file : " + Name$)
    EndIf
    ProcedureReturn ""
  EndIf
  Size = HelpSource\EntrySize()
  *Memory = AllocateMemory(Size + 2) ; +2: string terminator for PeekS()
  If *Memory = 0
    ProcedureReturn ""
  EndIf
  UncompressPackMemory(HelpSource\Pack, *Memory, Size, Name$)
  Text$ = PeekS(*Memory, -1, #PB_UTF8)
  FreeMemory(*Memory)
  If Left(Text$, 1) = Chr($FEFF) ; PeekS keeps the BOM (the old code did not remove it for archives)
    Text$ = Mid(Text$, 2)
  EndIf
  ProcedureReturn Text$
EndProcedure

; Reads a binary file of the source into a new memory block (to free with FreeMemory()). Returns 0 if it doesn't exist.
Procedure SourceReadBinary(Name$)
  Protected *Memory, Size, File

  If HelpSource\IsArchive
    If FindMapElement(HelpSource\EntrySize(), Name$) = 0
      ProcedureReturn 0
    EndIf
    Size = HelpSource\EntrySize()
    *Memory = AllocateMemory(Size)
    If *Memory
      UncompressPackMemory(HelpSource\Pack, *Memory, Size, Name$)
    EndIf
  Else
    File = ReadFile(#PB_Any, HelpSource\Root$ + Name$)
    If File = 0
      ProcedureReturn 0
    EndIf
    Size = Lof(File)
    *Memory = AllocateMemory(Size)
    If *Memory
      ReadData(File, *Memory, Size)
    EndIf
    CloseFile(File)
  EndIf
  ProcedureReturn *Memory
EndProcedure

; Lists the files of Dir$ (ends with "/", relative to the source root) and its subfolders, relative to Dir$.
; Extensions$ = "txt" or "txt,png" ("" = all files). Archive entries come in the order of the entry map, as before.
Procedure SourceList(List Files$(), Dir$, Extensions$ = "")
  Protected DirLength = Len(Dir$)
  Protected Name$

  Extensions$ = "," + LCase(Extensions$) + ","
  ClearList(Files$())
  If HelpSource\IsArchive = #False
    DirectoryListRecursive(Files$(), HelpSource\Root$ + Dir$, Extensions$, 0)
    ProcedureReturn
  EndIf

  ForEach HelpSource\EntrySize()
    Name$ = MapKey(HelpSource\EntrySize())
    If Left(Name$, DirLength) = Dir$ And (Extensions$ = ",," Or FindString(Extensions$, "," + LCase(GetExtensionPart(Name$)) + ","))
      AddElement(Files$())
      Files$() = Mid(Name$, DirLength + 1)
    EndIf
  Next
EndProcedure
