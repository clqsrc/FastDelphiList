program htest1;

uses
  Forms,
  htestmain1 in 'htestmain1.pas' {Form1},
  uHashList in 'uHashList.pas',
  uLinkList in 'uLinkList.pas',
  uLinkListFun in 'uLinkListFun.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
