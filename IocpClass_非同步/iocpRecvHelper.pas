unit iocpRecvHelper;

//类似于 iocpSendHelper,这个是用于接收
{
目的是:
1. 让上层应用知道整个接收过程中取得的完整数据.
2. 让上层应用可以决定什么时候算是一个包结束了.这时上层应用可以删除已经收到的数据
   包(不能一直保留,因长连接情况下公很快写满,所以在数据多到一定程度时应当异常).
}

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  winsock2,WinSock,ComCtrls,Contnrs, //iocpInterface,
  uThreadLock,
  Math,
  Dialogs;

type
  TRecvHelper = class(TObject)
  private
    // 2015/4/2 14:20:49 加一个调试标志,用于内存异常时检查是否是非常内存
    iDebugTag:Byte;

  public
    FMemory:TMemoryStream;
    OuterFlag:Integer;//传出外部连接标志//为兼容原有 iocp 接口,作用类似于线程函数中传递的参数
    //创建助手时取得的,因为启用接收助手功能的话助手会占用 OuterFlag, 这样必须有一个地方保存外部传递进来的 OuterFlag
    
    constructor Create; //override;
    destructor Destroy; override;


    procedure OnRecv(Socket: TSocket; buf:PChar; bufLen:Integer);//接收缓冲
    //清空已接收的数据//dataLen 是已处理的数据长度,需要从缓冲区中删除这么多,上层应用应当判断已经接收的数据中是否有多个包
    //应当尽可能的处理多个包然后删除掉已处理过的数据长度
    class procedure ClearData(helper:TRecvHelper; dataLen:Integer);
  end;

implementation

{ TRecvHelper }

//辅助函数,清空用掉的部分数据,和服务器端的代码是一样的
//class procedure TThreadSafeSocket.ClearData(var FMemory:TMemoryStream; dataLen:Integer);
procedure ClearData_Fun(var FMemory:TMemoryStream; dataLen:Integer);
var
  tmp:TMemoryStream;
  p:PAnsiChar;
  clearSize:Integer;
begin
  if (dataLen<=0) or (dataLen>FMemory.Size) then Exit;

  if (dataLen = FMemory.Size) then//全部用完的话清空就行了
  begin
    FMemory.Clear;
    Exit;
  end;

  clearSize := FMemory.Size - dataLen;
  if (clearSize > 200 * 1024 * 1024) then
  begin
    MessageBox(0, PChar('释放长度异常 [' + IntToStr(dataLen) + ']'), '', 0);
    FMemory.Clear;
    Exit;
  end;

  tmp := TMemoryStream.Create;


//  helper.FMemory.Seek(dataLen, soBeginning);//没用这样仍是保存全部
  FMemory.SaveToStream(tmp);

  //p := PAnsiChar(FMemory.Memory);
  p := PAnsiChar(tmp.Memory);
  p := p + dataLen;

  //tmp.WriteBuffer(p, helper.FMemory.Size - dataLen);//奇怪有异常
  //tmp.WriteBuffer(p^, FMemory.Size - dataLen);//注意这里 指针的用法

  FMemory.Clear;
  FMemory.WriteBuffer(p^, tmp.Size - dataLen);//注意这里 指针的用法


//  FMemory.Free;
//  FMemory := tmp;
  tmp.Free;
end;

class procedure TRecvHelper.ClearData(helper: TRecvHelper; dataLen:Integer);
var
  tmp:TMemoryStream;
  p:PAnsiChar;
begin
  ClearData_Fun(helper.FMemory, dataLen);
  {
  if (dataLen<=0) or (dataLen>helper.FMemory.Size) then Exit;

  if (dataLen = helper.FMemory.Size) then//全部用完的话清空就行了
  begin
    helper.FMemory.Clear;
    Exit;
  end;

  tmp := TMemoryStream.Create;


//  helper.FMemory.Seek(dataLen, soBeginning);//没用这样仍是保存全部
  helper.FMemory.SaveToStream(tmp);//不行这样保存了两次

  p := PAnsiChar(helper.FMemory.Memory);
  p := p + dataLen;

  //tmp.WriteBuffer(p, helper.FMemory.Size - dataLen);//奇怪有异常
  tmp.WriteBuffer(p^, helper.FMemory.Size - dataLen);//注意这里 指针的用法


  helper.FMemory.Free;
  helper.FMemory := tmp;
  }
end;

constructor TRecvHelper.Create;
begin
  inherited;
  
  FMemory:=TMemoryStream.Create;//接收缓冲
  FMemory.SetSize(1024);// 2015/4/7 14:55:33 test 预分配内存能行吗?
  FMemory.SetSize(0);// 2015/4/7 14:55:33 test 预分配内存能行吗?
  iDebugTag := 111; // 2015/4/2 14:22:04 加一个调试标志,用于内存异常时检查是否是非常内存
end;

destructor TRecvHelper.Destroy;
begin
  FMemory.Free;

  inherited;
end;

procedure TRecvHelper.OnRecv(Socket: TSocket; buf: PChar; bufLen: Integer);
begin
  FMemory.Seek(0, soFromEnd);//确保跳到缓冲区最末尾

  //注意不能是 FMemory.WriteBuffer(buf, bufLen); 就是说参数不能是指针,也许内部又转了一次指针?
  FMemory.WriteBuffer(buf^, bufLen);

  if FMemory.Size > 1024 * 1024 * 2 then
  begin
    MessageBox(0, '单个连接从客户端接收了太多数据而未处理', '服务器内部错误', 0);

//    raise Exception.Create('接收处理异常. '#13#10
//      + '单个连接从客户端接收了太多数据而未处理,请在 OnRecvData 事件中判断接收完一个完整数据包后,'#13#10
//      + '调用 TRecvHelper.ClearData(helper) 清空已接收的数据!');

  end;

end;

end.
 
