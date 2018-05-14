unit Settings;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls;

type
  TForm2 = class(TForm)
  CheckBox2: TCheckBox;
    OpenDialog3: TOpenDialog;
    ChangeParrot: TButton;
    procedure ChangeParrotClick(Sender: TObject);
  private
    { Private declarations }
  public

    { Public declarations }
  end;

var
  Form2: TForm2;
    BackFile: string;


implementation

{$R *.dfm}


procedure TForm2.ChangeParrotClick(Sender: TObject);
begin
 if OpenDialog3.Execute then BackFile:=Opendialog3.filename;
end;

end.
