program ParrotArchivator;

uses
  Forms,
  ParrotMain in 'ParrotMain.pas' {Parrot},
  ParrotBar in 'ParrotBar.pas' {ParrotPB},
  ParrotSettings in 'ParrotSettings.pas' {ParrotSet};

{$R *.res}

begin
  Application.Initialize;
  Application.Title := 'Parrot Archivator';
  Application.CreateForm(TParrot, Parrot);
  Application.CreateForm(TParrotPB, ParrotPB);
  Application.CreateForm(TParrotSet, ParrotSet);
  Application.Run;
end.
