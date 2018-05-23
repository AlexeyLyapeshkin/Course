unit ParrotMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Menus, ExtCtrls, jpeg;

const
  SizeOfBuffer = 4096;

type
  TParrot = class(TForm)
    OpenDialog1: TOpenDialog;
    BackgroundOf: TImage;
    MainMenuOf: TMainMenu;
    CreateArch: TMenuItem;
    DeArch: TMenuItem;
    Help: TMenuItem;
    Settings: TMenuItem;
    OutText: TMemo;
    OpenDialog2: TOpenDialog;
    procedure CreateArchClick(Sender: TObject);
    procedure DeArchClick(Sender: TObject);
    procedure SettingsClick(Sender: TObject);
    procedure HelpClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Parrot: TParrot;
  FileIn, FileEx: file;

implementation

uses
  ParrotBar, ParrotSettings;
{$R *.dfm}

type
  {Дерево, хранит символ, его "вес" и код. Так же хранит ссылки на левую и правую веточки }
  TPNode = ^PNode;

  PNode = record
    Symbol: Byte;
    Weight: Integer;
    Code: string;
    left, right: TPNode;
  end;
  {Массив таких деревьев. Нужен для создания заголовка файла}

  BytesWithStat = array[0..255] of TPNode;
  {Объект, необходимый для создания заголовка и инициализации переменных}

  TWeightTable = object
    MainArray: BytesWithStat;
    ByteCount: byte;
    procedure Create;
    procedure Inc(i: Byte);
  end;

{-------------------------------------------------------------------------------
  Процедура: TWeightTable.Create
  Автор:    Алексей
  Дата:  2018.05.13
  Входные параметры: Нет
  Результат:    Инициализация таблицы встречаемости
-------------------------------------------------------------------------------}
procedure TWeightTable.Create;
var
  i: Byte;
begin
  ByteCount := 255;
  for i := 0 to ByteCount do
  begin
    New(MainArray[i]);
    with MainArray[i]^ do
    begin
      Symbol := i;
      Weight := 0;
      left := nil;
      right := nil;
    end;
  end;
end;

{-------------------------------------------------------------------------------
  Процедура: TWeightTable.Inc
  Автор:    Алексей
  Дата:  2018.05.13
  Входные параметры: i: Byte - Байт, встречаемость которого мы увеличиваем
  Назначение :   увеличить встречаемость байта
-------------------------------------------------------------------------------}
procedure TWeightTable.Inc(i: Byte);
begin
  MainArray[i]^.Weight := MainArray[i]^.Weight + 1;
end;

type
  TFileName_ = object
    Name: string;
    FSize: Integer;
    FStat: TWeightTable;
    Node: TPNode;
    function ArcName: string;
    function DeArcName: string;
    function FSizeWithoutHead: Integer;
  end;

function TFileName_.ArcName: string;
var
  i: Integer;
  name_: string;
const
  Exten = 'Loss';
begin
  name_ := name;
  i := Length(name_);

  while (i > 0) and not (name_[i] in ['/', '\', '.']) do
  begin
    Dec(i);

  end;

  if (i = 0) or (name_[i] in ['/', '\']) then
    ArcName := name_ + '.' + Exten
  else if name_[i] = '.' then
  begin
    name_[i] := '.';
    ArcName := name_ + '.' + Exten;
  end;
end;

function TFileName_.DeArcName: string;
var
  i: Integer;
  Name_: string;
const
  dot = '.';
  Exten = 'Loss';
begin
  Name_ := Name;
  if pos(dot + Exten, Name_) = 0 then
  begin
    ShowMessage('Имя архива должно заканчиваться на ' + dot + Exten);
    Application.Terminate;
  end
  else
  begin
    i := Length(Name_);
    while (i > 0) and (Name_[i] <> '.') do
    begin
      Dec(i);

    end;
    if i = 0 then
    begin
      Name_ := copy(Name_, 1, pos(dot + Exten, Name_) - 1);
      if Name_ = '' then
      begin
        ShowMessage('Неверное имя архива.');
        Application.Terminate;
      end
      else
        DeArcName := Name_;
    end
    else
    begin
      Name_[i] := '.';
      Delete(Name_, pos(dot + Exten, Name_), 5);
      DeArcName := Name_;
    end;
  end;
end;

function TFileName_.FSizeWithoutHead: Integer;
begin
  FSizeWithoutHead := FileSize(FileIn) - 4 - 1 - (FStat.ByteCount + 1) * 5;
end;

procedure SortMainArray(var a: BytesWithStat; LengthOfMass: byte);
var
  i, j: Byte;
  b: TPNode;
begin
  if LengthOfMass <> 0 then
    for j := 0 to LengthOfMass - 1 do
    begin
      for i := 0 to LengthOfMass - 1 do
      begin
        if a[i]^.Weight < a[i + 1]^.Weight then
        begin
          b := a[i];
          a[i] := a[i + 1];
          a[i + 1] := b;
        end;

      end;

    end;
end;

procedure DeleteNode(Root: TPNode);
begin

  if Root <> nil then
  begin
    DeleteNode(Root^.left);
    DeleteNode(Root^.right);
    Dispose(Root);
    Root := nil;
  end;
end;

procedure CreateNode(var Root: TPNode; MainArray: BytesWithStat; last: byte);
var
  Node: TPNode;
begin
  if last <> 0 then
  begin
    SortMainArray(MainArray, last);
    new(Node);
    Node^.Weight := MainArray[last - 1]^.Weight + MainArray[last]^.Weight;
    Node^.left := MainArray[last - 1];
    Node^.right := MainArray[last];
    MainArray[last - 1] := Node;
    if last = 1 then
    begin
      Root := Node;
    end
    else
    begin
      CreateNode(Root, MainArray, last - 1);
    end;
  end
  else
    Root := MainArray[last];

end;

var
  ArchFile: TFileName_;

procedure CharStatictic(fname: string);
var
  f: file;
  i, j: Integer;
  buf: array[1..SizeOfBuffer] of Byte;
  countbuf, lastbuf: Integer;
begin
  AssignFile(f, fname);
  try
    Reset(f, 1);
    ArchFile.FStat.create;
    ArchFile.FSize := FileSize(f);
    countbuf := FileSize(f) div SizeOfBuffer;
    lastbuf := FileSize(f) mod SizeOfBuffer;
    for i := 1 to countbuf do
    begin
      BlockRead(f, buf, SizeOfBuffer);
      for j := 1 to SizeOfBuffer do
      begin
        ArchFile.FStat.inc(buf[j]);

      end;

    end;
    if lastbuf <> 0 then
    begin
      BlockRead(f, buf, lastbuf);
      for j := 1 to lastbuf do
      begin
        ArchFile.FStat.inc(buf[j]);

      end;

    end;
    CloseFile(f);
  except
    ShowMessage('Файл не доступен (Скорее всего занят каким-то другим приложением).')
  end;
end;

function Found(Node: TPNode; i: byte): Boolean;
begin

  if (Node = nil) then
    Found := False
  else
  begin
    if ((Node^.left = nil) or (Node^.right = nil)) and (Node^.Symbol = i) then
      Found := True
    else
      Found := Found(Node^.left, i) or Found(Node^.right, i);
  end;
end;

function HuffCodeHelp(Node: TPNode; i: Byte): string;
begin

  if (Node = nil) then
    HuffCodeHelp := '+'
  else
  begin
    if (Found(Node^.left, i)) then
      HuffCodeHelp := '0' + HuffCodeHelp(Node^.left, i)
    else
    begin
      if Found(Node^.right, i) then
        HuffCodeHelp := '1' + HuffCodeHelp(Node^.right, i)
      else
      begin
        if (Node^.left = nil) and (Node^.right = nil) and (Node^.Symbol = i) then
          HuffCodeHelp := '+'
        else
          HuffCodeHelp := '';
      end;
    end;
  end;
end;

function HuffCode(Node: TPNode; i: Byte): string;
var
  s: string;
begin
  s := HuffCodeHelp(Node, i);
  s := s;
  if (s = '+') then
    HuffCode := '0'
  else
    HuffCode := Copy(s, 1, length(s) - 1);
end;

procedure WriteInFile(var buffer: string);
var
  i, j: Integer;
  k: Byte;
  buf: array[1..2 * SizeOfBuffer] of byte;
begin
  i := Length(buffer) div 8;
  for j := 1 to i do
  begin
    buf[j] := 0;
    for k := 1 to 8 do
    begin
      if buffer[(j - 1) * 8 + k] = '1' then
        buf[j] := buf[j] or (1 shl (8 - k));

    end;

  end;
  BlockWrite(FileEx, buf, i);
  Delete(buffer, 1, i * 8);
end;

procedure WriteInTFileName_(var buffer: string);
var
  a, k: byte;
begin
  WriteInFile(buffer);
  if length(buffer) >= 8 then
    ShowMessage('С буффером что-то не так...')
  else if Length(buffer) <> 0 then
  begin
    a := $FF;
    for k := 1 to Length(buffer) do
      if buffer[k] = '0' then
        a := a xor (1 shl (8 - k));
    BlockWrite(FileEx, a, 1);
  end;
end;

type
  Integer_ = array[1..4] of Byte;

procedure IntegerToByte(i: Integer; var mass: Integer_);
var
  a: Integer;
  b: ^Integer_;
begin
  b := @a;
  a := i;
  mass := b^;
end;

procedure ByteToInteger(mass: Integer_; var i: Integer);
var
  a: ^Integer;
  b: Integer_;
begin
  a := @b;
  b := mass;
  i := a^;
end;

procedure CreateHead;
var
  b: Integer_;
  i: Byte;
begin
  IntegerToByte(ArchFile.FSize, b);
  BlockWrite(FileEx, b, 4);

  BlockWrite(FileEx, ArchFile.FStat.ByteCount, 1);

  for i := 0 to ArchFile.FStat.ByteCount do
  begin
    BlockWrite(FileEx, ArchFile.FStat.MainArray[i]^.Symbol, 1);
    IntegerToByte(ArchFile.FStat.MainArray[i]^.Weight, b);
    BlockWrite(FileEx, b, 4);
  end;
end;

const
  MaxCount = 4096;

type
  buffer_ = object
    ArrOfByte: array[1..MaxCount] of Byte;
    ByteCount: Integer;
    GeneralCount: Integer;
    procedure CreateBuf;
    procedure InsertByte(a: Byte);
    procedure FlushBuf;
  end;

procedure buffer_.CreateBuf;
begin
  ByteCount := 0;
  GeneralCount := 0;
end;

procedure buffer_.InsertByte(a: Byte);
begin
  if GeneralCount < ArchFile.FSize then
  begin
    inc(ByteCount);
    inc(GeneralCount);
    ArrOfByte[ByteCount] := a;
    if ByteCount = MaxCount then
    begin
      BlockWrite(FileEx, ArrOfByte, ByteCount);
      ByteCount := 0;
    end;
  end;
end;

procedure Buffer_.FlushBuf;
begin
  if ByteCount <> 0 then
    BlockWrite(FileEx, ArrOfByte, ByteCount);
end;

procedure CreateDeArc;
var
  i, j: Integer;
  k: Byte;
  Buf: array[1..SizeOfBuffer] of Byte;
  CountBuf, LastBuf: Integer;
  MainBuffer: buffer_;
  CurrentPoint: TPNode;
begin
  CountBuf := ArchFile.FSizeWithoutHead div SizeOfBuffer;
  LastBuf := ArchFile.FSizeWithoutHead mod SizeOfBuffer;
  MainBuffer.CreateBuf;
  CurrentPoint := ArchFile.Node;
  ParrotPB.ProgressBar.Min := 1;
  ParrotPB.ProgressBar.Max := CountBuf;
  ParrotPB.Visible := True;
  for i := 1 to CountBuf do
  begin
    ParrotPB.ProgressBar.Position := i;
    BlockRead(FileIn, Buf, SizeOfBuffer);
    for j := 1 to SizeOfBuffer do
    begin
      for k := 1 to 8 do
      begin
        if (Buf[j] and (1 shl (8 - k))) <> 0 then
          CurrentPoint := CurrentPoint^.right
        else
          CurrentPoint := CurrentPoint^.left;

        if (CurrentPoint^.left = nil) or (CurrentPoint^.right = nil) then
        begin
          MainBuffer.InsertByte(CurrentPoint^.Symbol);
          CurrentPoint := ArchFile.Node;
        end;

      end;

    end;
  end;
  ParrotPB.Visible := False;
  if LastBuf <> 0 then
  begin
    BlockRead(FileIn, Buf, LastBuf);
    for j := 1 to LastBuf do
    begin
      for k := 1 to 8 do
      begin
        if (Buf[j] and (1 shl (8 - k))) <> 0 then
          CurrentPoint := CurrentPoint^.right
        else
          CurrentPoint := CurrentPoint^.left;

        if (CurrentPoint^.left = nil) or (CurrentPoint^.right = nil) then
        begin
          MainBuffer.InsertByte(CurrentPoint^.Symbol);
          CurrentPoint := ArchFile.Node;
        end;

      end;

    end;
  end;
  MainBuffer.FlushBuf;
end;

procedure ReadHead;
var
  b: Integer_;
  SymbolSt: Integer;
  count_, SymbolId, i: Byte;
begin
  try
    BlockRead(FileIn, b, 4);
    ByteToInteger(b, ArchFile.FSize);

    BlockRead(FileIn, count_, 1);
    ArchFile.FStat.create;
    ArchFile.FStat.ByteCount := count_;
    for i := 0 to ArchFile.FStat.ByteCount do
    begin
      BlockRead(FileIn, SymbolId, 1);
      ArchFile.FStat.MainArray[i]^.Symbol := SymbolId;
      BlockRead(FileIn, b, 4);
      ByteToInteger(b, SymbolSt);
      ArchFile.FStat.MainArray[i]^.Weight := SymbolSt;
    end;
    CreateNode(ArchFile.Node, ArchFile.FStat.MainArray, ArchFile.FStat.ByteCount);
    CreateDeArc;
    DeleteNode(ArchFile.Node);

  except
    ShowMessage('С архивом что-то не так...');
  end;
end;

procedure ExtractFile;
begin
  AssignFile(FileIn, ArchFile.Name);
  AssignFile(FileEx, ArchFile.DeArcName);
  try
    Reset(FileIn, 1);
    Rewrite(FileEx, 1);

    ReadHead;

    Closefile(FileIn);
    Closefile(FileEx);

    ShowMessage('Файл успешно разархивирован.');
  except
    ShowMessage('Ошибка в извлечении файла.');
  end;
end;

procedure CreateArchiv;
var
  buffer: string;
  ArrOfStr: array[0..255] of string;
  i, j: Integer;
  buf: array[1..SizeOfBuffer] of Byte;
  CountBuf, LastBuf: Integer;
begin

  AssignFile(FileIn, ArchFile.Name);
  AssignFile(FileEx, ArchFile.ArcName);
  try
    Reset(FileIn, 1);
    Rewrite(FileEx, 1);
    for i := 0 to 255 do
      ArrOfStr[i] := '';
    for i := 0 to ArchFile.FStat.ByteCount do
    begin
      ArrOfStr[ArchFile.FStat.MainArray[i]^.Symbol] := ArchFile.FStat.MainArray[i]^.Code;

    end;
    CountBuf := ArchFile.FSize div SizeOfBuffer;
    LastBuf := ArchFile.FSize mod SizeOfBuffer;
    buffer := '';
    CreateHead;
    ParrotPB.ProgressBar.Min := 1;
    ParrotPB.ProgressBar.Max := CountBuf;
    ParrotPB.Visible := True;
    for i := 1 to CountBuf do
    begin
      ParrotPB.ProgressBar.Position := i;
      BlockRead(FileIn, buf, SizeOfBuffer);
      for j := 1 to SizeOfBuffer do
      begin
        buffer := buffer + ArrOfStr[buf[j]];
        if Length(buffer) > 8 * SizeOfBuffer then
          WriteInFile(buffer);

      end;
    end;
    ParrotPB.Visible := False;
    if LastBuf <> 0 then
    begin
      BlockRead(FileIn, buf, LastBuf);
      for j := 1 to LastBuf do
      begin
        buffer := buffer + ArrOfStr[buf[j]];
        if Length(buffer) > 8 * SizeOfBuffer then
          WriteInFile(buffer);

      end;
    end;
    WriteInTFileName_(buffer);
    CloseFile(FileIn);
    CloseFile(FileEx);
    ShowMessage('Файл успешно заархивирован.')
  except
    ShowMessage('Ошибка создания архива.');
  end;
end;

procedure CreateFile;
var
  i: Byte;
begin
  with ArchFile do
  begin
    SortMainArray(FStat.MainArray, FStat.ByteCount);

    i := 0;
    while (i < FStat.ByteCount) and (FStat.MainArray[i]^.Weight <> 0) do
    begin
      Inc(i);
    end;

    if FStat.MainArray[i]^.Weight = 0 then
      Dec(i);

    FStat.ByteCount := i;
    CreateNode(Node, FStat.MainArray, FStat.ByteCount);

    for i := 0 to FStat.ByteCount do
      FStat.MainArray[i]^.Code := HuffCode(Node, FStat.MainArray[i]^.Symbol);

    CreateArchiv;

    DeleteNode(Node);

    ArchFile.FStat.Create;
  end;
end;

procedure RunEncodeHaff(FileName_: string);
begin
  ArchFile.Name := FileName_;
  CharStatictic(ArchFile.Name);
  CreateFile;
end;

procedure RunDecodeHaff(FileName_: string);
begin
  ArchFile.name := FileName_;
  ExtractFile;
end;


procedure TParrot.CreateArchClick(Sender: TObject);
begin
  OutText.Visible := false;
  OpenDialog1.Filter := 'Любые файлы|';
  if OpenDialog1.Execute then
  begin
    RunEncodeHaff(OpenDialog1.FileName);
  end;
  if ParrotSet.CheckBox2.checked then
    DeleteFile(OpenDialog1.Filename);
end;

procedure TParrot.DeArchClick(Sender: TObject);
begin
  OutText.Visible := false;
  OpenDialog1.Filter := 'Архив(.Loss)|*.Loss';
  if OpenDialog1.Execute then
  begin
    RunDecodeHaff(OpenDialog1.FileName);
  end;
  if ParrotSet.CheckBox2.checked then
    DeleteFile(OpenDialog1.Filename);
end;

procedure TParrot.SettingsClick(Sender: TObject);
begin
  OutText.Visible := false;
  ParrotSet.Visible := True;
end;

procedure TParrot.HelpClick(Sender: TObject);
begin
  OutText.Visible := True;
end;

procedure TParrot.FormCreate(Sender: TObject);
var
  f: TextFile;
  line: string;
begin
  OutText.Clear;
  OutText.Visible := false;
  AssignFile(f, 'Help.LossHelp');
  Reset(f);
  while not (Eof(f)) do
  begin
    readln(f, line);
    OutText.Lines.Add(line);
  end;
  CloseFile(f);
end;

end.

