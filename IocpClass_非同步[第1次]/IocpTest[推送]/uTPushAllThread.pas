unit uTPushAllThread;

//推送线程示例.与 TPushThread 不同,这是在一个线程中推送数据给全部客户端

interface

uses
  Classes,
  iocpInterfaceClass, Windows, uThreadLock,
  forms;

type
  //推送线程
  TPushAllThread = class(TThread)
  private
    { Private declarations }
  protected
    procedure Execute; override;
  public
    iocpServer:TIocpClass;
    threadLock:TThreadLock;

    //Socket: TSocket;
    //OuterFlag: Integer;
    clientList:TList;
  end;

implementation

uses IocpTestMain;

{ Important: Methods and properties of objects in visual components can only be
  used in a method called using Synchronize, for example,

      Synchronize(UpdateCaption);

  and UpdateCaption could look like,

    procedure TPushThread.UpdateCaption;
    begin
      Form1.Caption := 'Updated in a thread';
    end; }

{ TPushAllThread }

procedure TPushAllThread.Execute;
var
  //data:AnsiString;
  data:TMemoryStream;
  t:TTestClass;

  Socket: TSocket;
  OuterFlag: Integer;

  i:Integer;
  sleepCount:Integer;//发送了多个后睡眠一下,以免占用太多 cpu

begin
  //data := 'init.初始化数据'#13#10;
  data := TMemoryStream.Create;
  sleepCount := 0;


  //t := TTestClass(OuterFlag);

  while not Application.Terminated do
  begin
    //if t.exit then Break;

    //if t.data<>'' then data := 'recv.接收数据:' + t.data + #13#10;

    //--------------------------------------------------
    //取得要发送的数据
    threadLock.Lock();
    try
      if GPushData.Size = 0 then Continue;//没有数据就不发送了

      data.Clear();
      data.WriteBuffer(GPushData.memory^, GPushData.Size);

    finally
      threadLock.UnLock();
    end;

    //--------------------------------------------------

    iocpServer.threadLock.Lock();
    try
      for i := 0 to clientList.Count-1 do
      begin
        t := TTestClass(clientList.Items[i]);
        OuterFlag := Integer(t);
        Socket := t.Socket;
        
        if t.exit then Continue;

        //iocpServer.SendDataSafe(Socket, PChar(data), Length(data), OuterFlag);
        iocpServer.SendDataSafe(Socket, data.Memory, data.Size, OuterFlag);

        Inc(sleepCount);
        if sleepCount > 600 then
        begin
          sleepCount := 0;
          Sleep(1);
        end;

      end;
    finally
      iocpServer.threadLock.UnLock()
    end;

    //iocpServer.SendDataSafe(Socket, PChar(data), Length(data), OuterFlag);

    sleep(1000);
  end;

end;

end.
 
