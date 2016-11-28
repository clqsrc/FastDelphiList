unit iocpSendHelper;

//上层应用包的发送助手函数
//为兼容原有 iocp 接口//也是为了能知道一个上层包全部发送后的情况
{
1.为了让上层应用知道ta要求发送的一个包什么时候完成了.
2.让上层应用知道是哪一个包发送完成了.(所以需要保留包的原始信息,这样的话我们在拆
  分成 iocp 包是就不再申请新的内存了,直接在原有包数据中划分出指针即可.这样同时
  还提高了性能)
}

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  winsock2,WinSock,ComCtrls,Contnrs, iocpInterface,
  uThreadLock,
  Math,
  Dialogs;

type
  //SendDataSafe 使用的数据结构
  TSendHelper = class(TObject)
  private

  public
    //FMemory:TMemoryStream;
    //OuterFlag:Integer;//传出外部连接标志//为兼容原有 iocp 接口,作用类似于线程函数中传递的参数
    //创建助手时取得的,因为启用助手功能的话助手会占用 OuterFlag, 这样必须有一个地方保存外部传递进来的 OuterFlag
    socket:TSocket;
    sendDataList:TList;//要发送的数据列表,每个就是 MakeSendHelperIoData 后的 PerIoData, 即只生成而还未发送
    threadLock:TThreadLock;//线程锁,外部传入的,不要自己生成

    constructor Create; //override;
    destructor Destroy; override;

    function PopSendData(var PerIoData : LPPER_IO_OPERATION_DATA):Boolean;//取出一个要发送的数据 FIFO 规则

  end;
  
type
  //对应 io 包的 ExtInfo 
  PSendPack = ^TSendPack;
  TSendPack = record//只是在程序中传递,没有过网络,所以不用压缩结构了
    Data:pchar;         //数据指针
    DataLen:Integer;    //数据长度
    SendLen:Integer;    //已经发送的长度
  end;

//生成一个发送用的 io 结构
function MakeSendHelperIoData(Socket: TSocket; buf:PChar; bufLen:Integer; OuterFlag:Integer):LPPER_IO_OPERATION_DATA;
//释放 io 结构
procedure FreeSendHelperIoData(PerIoData : LPPER_IO_OPERATION_DATA);

//设置第一个包的 io 数据结构
procedure IoDataGetFirst(PerIoData : LPPER_IO_OPERATION_DATA);
//取下一个要发送的数据要填充 io 结构//BytesTransferred 是当前发送成功的字节数,其实照目前的算法就是 DATA_BUFSIZE
function IoDataGetNext(PerIoData : LPPER_IO_OPERATION_DATA; BytesTransferred:Integer):Boolean;

//一个帮助函数,只能用在基于 iocp 类的地方
procedure SendData(Socket: TSocket; buf: PChar; bufLen: Integer; OuterFlag: Integer);



implementation

procedure SendData(Socket: TSocket; buf: PChar; bufLen: Integer; OuterFlag: Integer);
var
  PerIoData : LPPER_IO_OPERATION_DATA;
begin
  //SendBuf(Socket, buf, bufLen, OuterFlag, );
  PerIoData := MakeSendHelperIoData(Socket, buf, bufLen, OuterFlag);

  if PerIoData=nil then Exit;

  SendBuf(Socket, PerIoData);

end;

//生成一个发送用的 io 结构
function MakeSendHelperIoData(Socket: TSocket; buf:PChar; bufLen:Integer; OuterFlag:Integer):LPPER_IO_OPERATION_DATA;
var
    PerIoData : LPPER_IO_OPERATION_DATA;//这里是自己用的临时变量
    SendBytes:DWORD;
    Flags:DWORD;
    userData:PChar;
    pack:PSendPack;
begin
    result := nil;

    //--------------------------------------------------
    //1.先复制外部数据
    userData := PChar(GlobalAlloc(GPTR, bufLen));//因为是生成了一个副本,所以需要 iocp 自行删除,同时上层应用可以立即释放资源
    if (userData = nil) then
    begin
      MessageBox(0, 'GlobalAlloc', '服务器内部错误', 0);
      exit;
    end;
    CopyMemory(userData, buf, bufLen);

    //--------------------------------------------------
    //2.生成扩展信息
    pack := PSendPack(GlobalAlloc(GPTR, SizeOf(TSendPack)));//这个也需要 iocp 自行删除
    if (pack = nil) then
    begin
      MessageBox(0, 'GlobalAlloc', '服务器内部错误(GlobalAlloc)', 0);
      exit;
    end;
    pack.Data := userData;
    pack.DataLen := bufLen;
    pack.SendLen := 0;

    //--------------------------------------------------

    //创建一个“单IO数据结构”其中将 PerIoData.OpCode 设置成1。说明此“单IO数据结构”是用来发送的。
    PerIoData := LPPER_IO_OPERATION_DATA(GlobalAlloc(GPTR, sizeof(PER_IO_OPERATION_DATA)));
    if (PerIoData = nil) then
    begin
      MessageBox(0, 'GlobalAlloc', '服务器内部错误(GlobalAlloc)', 0);
      exit;
    end;

    //if bufLen>DATA_BUFSIZE then Exit;//不能超过 iocp 缓冲大小//每次只发送一部分,所以现在可以超过缓冲区大小

    ZeroMemory(@PerIoData.Overlapped, sizeof(OVERLAPPED));
    PerIoData.BytesSEND := 0;
    PerIoData.BytesRECV := 0;
    //PerIoData.DataBuf.len := bufLen;//1024;//后面取包函数会赋值的
    //PerIoData.DataBuf.buf := @PerIoData.Buf;//后面取包函数会赋值的
    PerIoData.OpCode := 1;//标志,发送用的
    PerIoData.Socket := Socket;//用做关键字的话,放这里更安全
    PerIoData.OuterFlag := OuterFlag;
    PerIoData.ExtInfo := Integer(pack);//ExtInfo;
    Flags := 0;

    //--------------------------------------------------
    IoDataGetFirst(PerIoData);//取第一个包

    //--------------------------------------------------
    {
    //用此“单IO数据结构”来发送Acceptsc套接字的数据。
    //if (WSARecv(Acceptsc, @(PerIoData.DataBuf), 1, @RecvBytes, @Flags,@(PerIoData.Overlapped), nil) = SOCKET_ERROR) then
    if (WSASend(Socket, @(PerIoData.DataBuf), 1, @SendBytes, Flags, @(PerIoData.Overlapped), nil) = SOCKET_ERROR) then
    begin
       if (WSAGetLastError() <> ERROR_IO_PENDING) then
       begin
          exit;
       end
    end;
    }

    result := PerIoData;
end;

//释放 io 结构
procedure FreeSendHelperIoData(PerIoData : LPPER_IO_OPERATION_DATA);
var
  pack:PSendPack;

begin
  if PerIoData.OpCode = 0 then Exit;//接收缓冲是没有扩展数据的

  //--------------------------------------------------
  //取扩展信息
  pack := PSendPack(PerIoData.ExtInfo);//这个也需要 iocp 自行删除
  if (pack = nil) then
  begin
     exit;
  end;
  //--------------------------------------------------


  //GlobalFree(DWORD(PerIoData));//不用删除 io 结构本身,原有的 iocp 架构已经删除了,只需要删除扩展数据//不,还是统一删除吧

  GlobalFree(DWORD(pack.Data));
  GlobalFree(DWORD(pack));

  GlobalFree(DWORD(PerIoData));

end;

//设置第一个包的 io 数据结构
procedure IoDataGetFirst(PerIoData : LPPER_IO_OPERATION_DATA);
var
    pack:PSendPack;
begin
    //--------------------------------------------------
    //取扩展信息
    pack := PSendPack(PerIoData.ExtInfo);//这个也需要 iocp 自行删除
    if (pack = nil) then
    begin
       exit;
    end;
    //--------------------------------------------------

    //不能超过 iocp 缓冲大小
    //if pack.DataLen>DATA_BUFSIZE then PerIoData.DataBuf.len := DATA_BUFSIZE;

    PerIoData.DataBuf.len := Min(pack.DataLen, DATA_BUFSIZE);
    PerIoData.DataBuf.buf := pack.Data;

    ZeroMemory(@PerIoData.Overlapped, sizeof(OVERLAPPED));
    PerIoData.BytesSEND := 0;
    PerIoData.BytesRECV := 0;
//    PerIoData.DataBuf.len := bufLen;//1024;
//    PerIoData.DataBuf.buf := @PerIoData.Buf;
//    PerIoData.OpCode := 1;//标志,发送用的
//    PerIoData.Socket := Socket;//用做关键字的话,放这里更安全
//    PerIoData.OuterFlag := OuterFlag;
//    PerIoData.ExtInfo := ExtInfo;

    //--------------------------------------------------
    //填充数据
    //不用再复制,直接使用上层应用的 CopyMemory(PerIoData.DataBuf.buf, buf, bufLen);
    PerIoData.BufLen := pack.DataLen;//pack.DataLen - pack.SendLen;//bufLen;
    //--------------------------------------------------
end;


//取下一个要发送的数据要填充 io 结构//BytesTransferred 是当前发送成功的字节数,其实照目前的算法就是 DATA_BUFSIZE
function IoDataGetNext(PerIoData : LPPER_IO_OPERATION_DATA; BytesTransferred:Integer):Boolean;
var
  pack:PSendPack;
  curDataPoint:PChar;//当前要发送的数据的位置
  remainlen:Integer;//剩余的数据长度
begin
  result := False;

  //--------------------------------------------------
  //取扩展信息
  pack := PSendPack(PerIoData.ExtInfo);//这个也需要 iocp 自行删除
  if (pack = nil) then
  begin
     exit;
  end;

  pack.SendLen := pack.SendLen + BytesTransferred;
  curDataPoint := pack.Data + pack.sendLen;
  remainlen := pack.DataLen - pack.SendLen;

  //没有要发送的包了,即全部发送完成了
  if remainlen <= 0 then
  begin
    remainlen := 0;//安全起见
    result := False;
    Exit;
  end;
  //--------------------------------------------------

  //不能超过 iocp 缓冲大小
  //if pack.DataLen>DATA_BUFSIZE then PerIoData.DataBuf.len := DATA_BUFSIZE;

  PerIoData.DataBuf.len := Min(remainlen, DATA_BUFSIZE);
  PerIoData.DataBuf.buf := curDataPoint;

  ZeroMemory(@PerIoData.Overlapped, sizeof(OVERLAPPED));
  PerIoData.BytesSEND := 0;
  PerIoData.BytesRECV := 0;
//    PerIoData.DataBuf.len := bufLen;//1024;
//    PerIoData.DataBuf.buf := @PerIoData.Buf;
//    PerIoData.OpCode := 1;//标志,发送用的
//    PerIoData.Socket := Socket;//用做关键字的话,放这里更安全
//    PerIoData.OuterFlag := OuterFlag;
//    PerIoData.ExtInfo := ExtInfo;

  //--------------------------------------------------
  //填充数据
  //不用再复制,直接使用上层应用的 CopyMemory(PerIoData.DataBuf.buf, buf, bufLen);
  PerIoData.BufLen := pack.DataLen - pack.SendLen;//bufLen;
  //--------------------------------------------------

  result := True;
  
end;

{ TSendHelper }

constructor TSendHelper.Create;
begin
  sendDataList := TList.Create;
  
end;

destructor TSendHelper.Destroy;
var
  i:Integer;
  PerIoData: LPPER_IO_OPERATION_DATA;
begin
  for i := 0 to sendDataList.Count-1 do
  begin
    PerIoData := sendDataList[i];
    //GlobalFree(DWORD(PerIoData));
    FreeSendHelperIoData(PerIoData);

  end;

  sendDataList.Free;

  inherited;
end;

function TSendHelper.PopSendData(
  var PerIoData: LPPER_IO_OPERATION_DATA): Boolean;
begin
  Result := False;
  if sendDataList.Count = 0 then Exit;

  PerIoData := sendDataList[0];
  sendDataList.Delete(0);

  Result :=True;
end;

end.
