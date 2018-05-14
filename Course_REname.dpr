program Course_REname;

uses
  Forms,
  HuffmanArch in 'HuffmanArch.pas' {Parrot},
  progressBarForArch in 'progressBarForArch.pas' {Form1},
  Settings in 'Settings.pas' {Form2};

{$R *.res}

begin
  Application.Initialize;
  Application.Title := 'Parrot Arhiv';
  Application.CreateForm(TParrot, Parrot);
  Application.CreateForm(TForm1, Form1);
  Application.CreateForm(TForm2, Form2);
  Application.Run;
end.
