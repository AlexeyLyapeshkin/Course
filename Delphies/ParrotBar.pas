unit ParrotBar;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ComCtrls, StdCtrls;

type
  TParrotPB = class(TForm)
    ProgressBar: TProgressBar;
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  ParrotPB: TParrotPB;

implementation

{$R *.dfm}

end.
