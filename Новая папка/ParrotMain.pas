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
  {Объект, необходимый для создания заголовка и инициализации переменных, также для подсчета статистики}

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
{фнкция создания имени сжатого файла по имени исходного файла}
function TFileName_.ArcName: string;
var
  i: Integer;
  name_: string;
const
  Exten = 'Loss';
begin
  name_ := name;
  ArcName := name_ + '.' + Exten;
end;

{функция создания имени исходного файла по имени сжатого файла}
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
      Delete(Name_, pos(dot + Exten, Name_), 5);
      DeArcName := Name_;
    end;
  end;
end;
{функция вычисления размера файла без заголовка для разжатия}
function TFileName_.FSizeWithoutHead: Integer;
begin
  FSizeWithoutHead := FileSize(FileIn) - 4 - 1 - (FStat.ByteCount + 1) * 5;
   {FileSize - стандартная функция, возвращающая размера файла в  байтах,
   отнимаем 4 - потому что размер исходного файла записывается в 4 байтах,
   1 байт на количество уникальных символов, и еще минус длина таблицы}
end;

{обычная сортировка перестановки; соритруем по убыванию частоты символа}
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

{процедура очистки дерева}
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

{процедура создания дерева кодирования}
procedure CreateNode(var Root: TPNode; MainArray: BytesWithStat; last: byte);
var
  Node: TPNode;  {элемент дерева}
begin
  if last <> 0 then                 {пока длина массива не ноль}
  begin
    SortMainArray(MainArray, last); {соритруем}
    new(Node);
    Node^.Weight := MainArray[last - 1]^.Weight + MainArray[last]^.Weight;{присваиваем весу нового узла вес двух его родителей}
    Node^.left := MainArray[last - 1];   {оставляем ссылку на левого родителя}
    Node^.right := MainArray[last];    {оставляем ссылку на правого родителя}
    MainArray[last - 1] := Node;      {помещаем на место предпоследнего элемента
     новый узел, зачищая последние два}
    if last = 1 then
    begin
      Root := Node;{ если остался один узел, то делаем его корнем}
    end
    else
    begin
      CreateNode(Root, MainArray, last - 1); {если нет, то рекурсивно вызываем
      создание дерева дальше}
    end;
  end
  else
    Root := MainArray[last]; {если ддина изначально была 0, то есть в файле был один символ (чередовался), то сразу задаем корень из этого элемента }

end;

var
  ArchFile: TFileName_; {сжимаемый файл}

{процедура подсчета статистика для байтов, встречающихся в файле хотя бы 1 раз}
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
    ArchFile.FStat.create;{инициализирую статистику}
    ArchFile.FSize := FileSize(f);
    countbuf := FileSize(f) div SizeOfBuffer;{количество целых буферов}
    lastbuf := FileSize(f) mod SizeOfBuffer;{остаточный буфер}
    for i := 1 to countbuf do
    begin
      BlockRead(f, buf, SizeOfBuffer);{читаю из файла в буфер 4Кб символов}
      for j := 1 to SizeOfBuffer do
      begin
        ArchFile.FStat.inc(buf[j]);{подсчет статистикки байтов}

      end;

    end;
    {дособираю статистику не целого буфера}
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

{Функция HuffCodeHelp вызывает данную функцию с параметрами: левый потомок и символ, если символ есть в вызванной ветке, то фаунд возвращает True; если нет, то False}
function Found(Node: TPNode; i: byte): Boolean;
begin

  if (Node = nil) then
    Found := False{если дерево пустое, то false}
  else
  begin
    if ((Node^.left = nil) or (Node^.right = nil)) and (Node^.Symbol = i) then
      Found := True {Если в дереве один узел, то он найден}
    else
      Found := Found(Node^.left, i) or Found(Node^.right, i);{Если не один узел, то ищем рекурсивно}
  end;
end;

{функция для создания кодов хаффмана}
function HuffCodeHelp(Node: TPNode; i: Byte): string;
begin

  if (Node = nil) then
    HuffCodeHelp := '+' {если в дереве пусто, возвращаем символ +}
  else
  begin
    if (Found(Node^.left, i)) then
      HuffCodeHelp := '0' + HuffCodeHelp(Node^.left, i){если найдено в левом, то записываем в код 0, и идем дальше}
    else
    begin
      if Found(Node^.right, i) then
        HuffCodeHelp := '1' + HuffCodeHelp(Node^.right, i){если найдено в правом, то записываем в код 1, и идем дальше}
      else
      begin
        if (Node^.left = nil) and (Node^.right = nil) and (Node^.Symbol = i) then
          HuffCodeHelp := '+' {если символ найден, то записываем в конец кода символ +}
        else
          HuffCodeHelp := ''; {если нет, то ничего не пишем}
      end;
    end;
  end;
end;

{эта функция вызывает прошлую, но еще и учитывает тот случай, когда у нас один единственный символ}
function HuffCode(Node: TPNode; i: Byte): string;
var
  s: string;
begin
  s := HuffCodeHelp(Node, i);
  s := s;
  if (s = '+') then
    HuffCode := '0'
  else
    HuffCode := Copy(s, 1, length(s) - 1); {если все хорошо, то удаляем = из конца кода}
end;

{процедура записи в файл; перевод строки с байтами в биты}
procedure WriteInFile(var buffer: string);
var
  i, j: Integer;
  k: Byte;
  buf: array[1..2 * SizeOfBuffer] of byte;
begin
  i := Length(buffer) div 8; {узнаю количество целых байтов}
  for j := 1 to i do
  begin
    buf[j] := 0; {зануляю текущий элемент буфера}
    for k := 1 to 8 do {тут начинается работа с битами}
    begin
      if buffer[(j - 1) * 8 + k] = '1' then {если в входящем буфере первым байтом встречается
       единичка, то с помощью логического сдвига влево единцы и логической оперцаии "или" мы записываем в первый бит байта выходящего буфера единицу}

        buf[j] := buf[j] or (1 shl (8 - k));

    end;

  end;
  BlockWrite(FileEx, buf, i);
  Delete(buffer, 1, i * 8);{удаляю уже записанные байты}
end;

{процедура записиси в файл, но уже с учетом остаточной цепочки байт (<8)}
procedure WriteInTFileName_(var buffer: string);
var
  a, k: byte;
begin
  WriteInFile(buffer);{записываем целые байты}
  if length(buffer) >= 8 then
    ShowMessage('С буффером что-то не так...')
  else if Length(buffer) <> 0 then
  begin
    a := $FF;{делаем в текущем выходном буфере все 1 (11111111)}
    for k := 1 to Length(buffer) do
      if buffer[k] = '0' then
        a := a xor (1 shl (8 - k)); {если во входящем буфере с байтами
         встречаются 0, то мы их записываем в соответвующие биты выходящего
          буфера с помощью оперцаии xor и логического сдвига влево}
    BlockWrite(FileEx, a, 1);
  end;
end;

type
  Integer_ = array[1..4] of Byte;
{структура данных, необходимы для побайтовой записи в файл}
procedure IntegerToByte(i: Integer; var mass: Integer_);
var
  a: Integer;
  b: ^Integer_;
begin
  b := @a;{соединяю адрес переменной а с b}
  a := i;{в а помещаю значение типа integer}
  mass := b^;{разыменовываю b и соединяю результат с mass}
end;

{}
procedure ByteToInteger(mass: Integer_; var i: Integer);
var
  a: ^Integer;
  b: Integer_;
begin
  a := @b;{соединяем адрес переменной b c a}
  b := mass;{b присваиваю значение массива}
  i := a^;{разыменовываю а и соединяю результат с i}

end;

{процедура создания заголовка файла}
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

{инициализация перенных}
procedure buffer_.CreateBuf;
begin
  ByteCount := 0;
  GeneralCount := 0;
end;

{процедура вставки разжатых файлов в файл}
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

{запись остаточных байтов в файл}
procedure Buffer_.FlushBuf;
begin
  if ByteCount <> 0 then
    BlockWrite(FileEx, ArrOfByte, ByteCount);
end;

{процедцра создания разжатого файла}
procedure CreateDeArc;
var
  i, j: Integer;
  k: Byte;
  Buf: array[1..SizeOfBuffer] of Byte;
  CountBuf, LastBuf: Integer;
  MainBuffer: buffer_;
  CurrentPoint: TPNode;
begin
  CountBuf := ArchFile.FSizeWithoutHead div SizeOfBuffer;{считаю количесвто целых буферов по 4кб}
  LastBuf := ArchFile.FSizeWithoutHead mod SizeOfBuffer;{считаю остаточные байты}
  MainBuffer.CreateBuf;{инициализирую буфер}
  CurrentPoint := ArchFile.Node;{устанавливаю указатель на корень дерева распаковки}
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
        {в каждом байте я просматриваю биты, если встречаю единичку - иду по
        дереву направо, нет - налево. Когда дохожу до символа, то запускаю вставку
         разжатых байтов в файл; тоже самое происходит и для остаточнх байтов}
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

{процедура чтения заголовка сжатого файла}
procedure ReadHead;
var
  b: Integer_;
  SymbolSt: Integer;
  count_, SymbolId, i: Byte;
begin
  try
    BlockRead(FileIn, b, 4);
    ByteToInteger(b, ArchFile.FSize);
    {считываю размер исходного файла}

    BlockRead(FileIn, count_, 1);{считываю длину таблицы}
    ArchFile.FStat.create;{инциализирую статистику}
    ArchFile.FStat.ByteCount := count_;
    for i := 0 to ArchFile.FStat.ByteCount do
    begin
      BlockRead(FileIn, SymbolId, 1);
      ArchFile.FStat.MainArray[i]^.Symbol := SymbolId;{первый байт - символ, следующие за ним 4 байта - встречаемость и так до конца файла}
      BlockRead(FileIn, b, 4);
      ByteToInteger(b, SymbolSt);
      ArchFile.FStat.MainArray[i]^.Weight := SymbolSt;
    end;
    CreateNode(ArchFile.Node, ArchFile.FStat.MainArray, ArchFile.FStat.ByteCount);{строю дерево кодирования Хаффмана}
    CreateDeArc;{разжимаю файл}
    DeleteNode(ArchFile.Node);{зачищаю дерево}

  except
    ShowMessage('С архивом что-то не так...');
  end;
end;

{внешняя процедура разжатия файла}
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

{процедура создания сжатого файла}
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
    for i := 0 to 255 do{инициализирую массив кодов}
      ArrOfStr[i] := '';
    for i := 0 to ArchFile.FStat.ByteCount do
    begin
      ArrOfStr[ArchFile.FStat.MainArray[i]^.Symbol] := ArchFile.FStat.MainArray[i]^.Code;
      {помещаю в массив строк коды Хаффмана, соответсвующие символам}
    end;
    CountBuf := ArchFile.FSize div SizeOfBuffer;{количество целых буферов, которые
    будут в сжимаемом файле}
    LastBuf := ArchFile.FSize mod SizeOfBuffer;{остаток этих байт}
    buffer := '';
    CreateHead;{создаю заголовок}
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
        if Length(buffer) > 8 * SizeOfBuffer then {8 * 4096 - это количество в битах;
        если будет превышена данная длина, то нужно записыать буфер в файл}
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
    WriteInTFileName_(buffer);{остаточная цепочка}
    CloseFile(FileIn);
    CloseFile(FileEx);
    ShowMessage('Файл успешно заархивирован.')
  except
    ShowMessage('Ошибка создания архива.');
  end;
end;

{внешняя процедура создания сжатого файла}
procedure CreateFile;
var
  i: Byte;
begin
  with ArchFile do
  begin
    SortMainArray(FStat.MainArray, FStat.ByteCount);{соритрую масив}

    i := 0;
    while (i < FStat.ByteCount) and (FStat.MainArray[i]^.Weight <> 0) do
    begin
      Inc(i);{тут я ищу количество задействованных байтов}
    end;

    if FStat.MainArray[i]^.Weight = 0 then
      Dec(i);{уменьшаю на один, чтобы попасть на последний элемент}

    FStat.ByteCount := i;
    CreateNode(Node, FStat.MainArray, FStat.ByteCount);{строю дерево кодирования Хаффмана}

    for i := 0 to FStat.ByteCount do
      FStat.MainArray[i]^.Code := HuffCode(Node, FStat.MainArray[i]^.Symbol);
      {загоняю в таблицу коды Хаффмана}

    CreateArchiv;{создаю заголовок и записываю поток сжатых байтов в файл}

    DeleteNode(Node);{зачищаю дерево}

    ArchFile.FStat.Create;{зачищаю таблицу}
  end;
end;

{конечная процедура по созаднию сжимаемого файла, с учетом имени выбранного файла}
procedure RunEncodeHaff(FileName_: string);
begin
  ArchFile.Name := FileName_;
  CharStatictic(ArchFile.Name);
  CreateFile;
end;

{конечная процедура по созданию разжатого файла, с учетом имени}
procedure RunDecodeHaff(FileName_: string);
begin
  ArchFile.name := FileName_;
  ExtractFile;
end;

{реакция программы на нажатие кнопки меню "Сжать файл"}
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

{реакция программы на нажатие кнопки меню "Разжать файл"}
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

{реакция программы на нажатие кнопки меню "Настройки"}
procedure TParrot.SettingsClick(Sender: TObject);
begin
  OutText.Visible := false;
  ParrotSet.Visible := True;
end;

{реакция программы на нажатие кнопки меню "Помощь"}
procedure TParrot.HelpClick(Sender: TObject);
begin
  OutText.Visible := True;
end;

{создание интерфейса помощи}
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

