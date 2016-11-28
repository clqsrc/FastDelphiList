program iocptest;

uses
  Forms,
  IocpTestMain in 'IocpTestMain.pas' {Form1},
  iocpInterface in '..\iocpInterface.pas',
  iocpInterfaceClass in '..\iocpInterfaceClass.pas',
  iocpRecvHelper in '..\iocpRecvHelper.pas',
  iocpSendHelper in '..\iocpSendHelper.pas',
  uFastHashSocketQueue in '..\uFastHashSocketQueue.pas',
  uFastQueue in '..\uFastQueue.pas',
  uThreadLock in '..\uThreadLock.pas',
  WinSock2 in '..\Winsock2.pas',
  uTPushAllThread in 'uTPushAllThread.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
