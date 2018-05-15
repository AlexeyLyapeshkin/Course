program ParrotArchivator;

uses
  Forms,
  ParrotMain in 'ParrotMain.pas' {Parrot},
  ParrotBar in 'ParrotBar.pas' {Form1},
  ParrotSettings in 'ParrotSettings.pas' {Form2};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TParrot, Parrot);
  Application.CreateForm(TForm1, Form1);
  Application.CreateForm(TForm2, Form2);
  Application.Run;
end.
