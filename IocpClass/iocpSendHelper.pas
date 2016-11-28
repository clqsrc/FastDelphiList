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
    FParentConnect:TObject;

  public
    //每个连接只用一个,简化 iocp 的内存管理
    FPerIoData : LPPER_IO_OPERATION_DATA;
    //因为发送的 periodata 一般是要自己释放的,所以释放时要标志一下,接收也有可能会
    PerIoData_IsFree:Boolean;

    
    SendMemory:TMemoryStream;
    //FMemory:TMemoryStream;
    //OuterFlag:Integer;//传出外部连接标志//为兼容原有 iocp 接口,作用类似于线程函数中传递的参数
    //创建助手时取得的,因为启用助手功能的话助手会占用 OuterFlag, 这样必须有一个地方保存外部传递进来的 OuterFlag
    socket:TSocket;
    threadLock:TThreadLock;//线程锁,外部传入的,不要自己生成

    // 2015/5/8 14:39:57 是否绑定了 iocp ,如果没有的话就是只能先加入到缓冲区中,绑定后再手工触发发送
    isBindIocp:Boolean;
    atSend:Boolean;//是否正在发送

    // 2015/5/12 11:04:38 每次都清空效率太低,还是先记录一下
    BytesTransferred_Total:Integer;

    constructor Create(parentConnect:TObject); //override;
    destructor Destroy; override;

    //用 PerIoData 的列表会导致 iocp 过程太过复杂了,应当放到外层应用,这主要是因为以前没有可靠的 socket 列表来管理连接
    //现在改成放到一个 内存流 中就行了,当然这样有个问题就是当要发送多个大文件时会移动大量的内存,不过大文件本来也不应该一次全部装载
    //添加到发送缓冲中
    procedure AddSendBuf(buf:PAnsiChar; buflen:Integer);
    //取下一个要发送的数据要填充 io 结构//BytesTransferred 是当前发送成功的字节数,其实照目前的算法就是 DATA_BUFSIZE
    function IoDataGetNext(PerIoData : LPPER_IO_OPERATION_DATA; BytesTransferred:Integer):Boolean;
    //缓冲区中的发送出去
    procedure DoSendBuf(Socket: TSocket);

  end;



//生成一个发送用的 io 结构
//function MakeSendHelperIoData(Socket: TSocket; buf:PChar; bufLen:Integer; OuterFlag:Integer):LPPER_IO_OPERATION_DATA;

//设置第一个包的 io 数据结构
//procedure IoDataGetFirst(PerIoData : LPPER_IO_OPERATION_DATA);
//取下一个要发送的数据要填充 io 结构//BytesTransferred 是当前发送成功的字节数,其实照目前的算法就是 DATA_BUFSIZE
//function IoDataGetNext(PerIoData : LPPER_IO_OPERATION_DATA; BytesTransferred:Integer):Boolean;

//一个帮助函数,只能用在基于 iocp 类的地方
//procedure SendData(Socket: TSocket; buf: PChar; bufLen: Integer; OuterFlag: Integer);



implementation

uses iocpInterfaceClass, iocpRecvHelper;



//取下一个要发送的数据要填充 io 结构//BytesTransferred 是当前发送成功的字节数,其实照目前的算法就是 DATA_BUFSIZE
function TSendHelper.IoDataGetNext(PerIoData : LPPER_IO_OPERATION_DATA; BytesTransferred:Integer):Boolean;
var
  curDataPoint:PChar;//当前要发送的数据的位置
  remainlen:Integer;//剩余的数据长度
  //buf:PChar;
  //bufLen:Integer;
begin
  Result := False;
  
  //--------------------------------------------------
  //先清空已经发送的数据
  BytesTransferred_Total := BytesTransferred_Total + BytesTransferred;

  //每次都清空效率太低了,从目前的网络和cpu来看,1M清理一次是比较合适的
  //if BytesTransferred_Total>1*1024*1024 then //大文件时仍然够呛
  if (BytesTransferred_Total>1*1024*1024)and(BytesTransferred_Total > SendMemory.Size div 2) then //加个折半算法能提高 4 倍左右
  begin
    //ClearData_Fun(self.SendMemory, BytesTransferred);//发送大文件时,这个效率太低了
    ClearData_Fun(self.SendMemory, BytesTransferred_Total);//发送大文件时,这个效率太低了
    BytesTransferred_Total := 0;

    //不清除的话会和原来的 iocp 性能很接近,但不清除就要记住各个分包,逻辑太复杂


  end;
  //Sleep(100);//sleep 并不能加强性能.目前测试能加强通用性的参数为
  //1. DATA_BUFSIZE,默认为 1K ,可以加到和 windows一样的 4k,不过加到 1M的话提高并不明显;
  //2. BytesTransferred_Total 处理流程的加入对于 20m 左右的文件效果非常明显,但对 100M 后的还要有其他调整才行;
  //3. g_IOCP_Synchronize_Event 参数对于 http 大文件的下载几乎没有影响(比较令人吃惊);
  //对于长连接来说 BytesTransferred_Total 就够了,对于下载来说 DATA_BUFSIZE 就提高了 50%
  //对下载来说,不考虑 cpu 的话 BytesTransferred_Total 加大也能极大的发送性能
  //所以比较好的方式是根据要发送的包大小动态修改 DATA_BUFSIZE 要不为 1K ,要不为 1M,简单明白
  //对于目前用的长连接来说, 1M 的BytesTransferred_Total 加 1K 的 DATA_BUFSIZE 性能就非常好了
  //--------------------------------------------------


  //self.SendMemory.Position := 0;
  self.SendMemory.Position := BytesTransferred_Total;

  //FPerIoData.BufLen := SendMemory.Read(FPerIoData.Buf, DATA_BUFSIZE);
  PerIoData.BufLen := SendMemory.Read(PerIoData.Buf, DATA_BUFSIZE);

  if PerIoData.BufLen<1 then Exit;//Result := False;//没读取到数据

  //--------------------------------------------------

  //if bufLen>DATA_BUFSIZE then bufLen := DATA_BUFSIZE;

  //CopyMemory(@PerIoData.Buf, buf, bufLen);

  ZeroMemory(@PerIoData.Overlapped, sizeof(OVERLAPPED));//每次都要重置吗?
  //PerIoData.BytesSEND := 0;//每次都要重置
  //PerIoData.BytesRECV := 0;
  PerIoData.BufInfo.len := PerIoData.BufLen;//bufLen;//1024;//每次都要重置
  PerIoData.BufInfo.buf := @PerIoData.Buf;//其实这次不重置也可以

  Result := True;

end;

{ TSendHelper }

// 2015/5/8 9:44:33 创建一个可重复使用的发送 iodata 这样即可加强性能,还可以判断是否有数据正在发送
//生成一个发送用的 io 结构
function CreateSendHelperIoData(Socket: TSocket):LPPER_IO_OPERATION_DATA;
var
  PerIoData : LPPER_IO_OPERATION_DATA;//这里是自己用的临时变量

begin
  result := nil;

  //创建一个“单IO数据结构”其中将 PerIoData.OpCode 设置成1。说明此“单IO数据结构”是用来发送的。
  PerIoData := LPPER_IO_OPERATION_DATA(IocpAlloc(sizeof(PER_IO_OPERATION_DATA)));
  if (PerIoData = nil) then
  begin
    MessageBox(0, 'GlobalAlloc', '服务器内部错误(GlobalAlloc)', 0); //没有取得内存
    exit;
  end;

  ZeroMemory(PerIoData, sizeof(PER_IO_OPERATION_DATA));

  ZeroMemory(@PerIoData.Overlapped, sizeof(OVERLAPPED));
  //PerIoData.BytesSEND := 0;
  //PerIoData.BytesRECV := 0;
  //PerIoData.DataBuf.len := bufLen;//1024;//后面取包函数会赋值的
  //PerIoData.DataBuf.buf := @PerIoData.Buf;//后面取包函数会赋值的
  PerIoData.OpCode := 1;//标志,发送用的
  PerIoData.Socket := Socket;//用做关键字的话,放这里更安全
  //PerIoData.OuterFlag := OuterFlag;
  //PerIoData.ExtInfo := Integer(pack);//ExtInfo;


  result := PerIoData;

end;




constructor TSendHelper.Create(parentConnect:TObject);
begin
  inherited Create;

  FParentConnect := parentConnect;

  atSend := False;
  isBindIocp := False;
  //sendDataList := TList.Create;
  SendMemory := TMemoryStream.Create;

  BytesTransferred_Total := 0;

  //iocp 数据在这里创建,但并不在这里销毁,原因是有可能在接收事件中发现关闭而提前释放了 self 自身//所以释放时只设置标志,让发送用的 iocp 数据自己销毁
  FPerIoData := CreateSendHelperIoData(0{Socket}{, 0{OuterFlag});
  FPerIoData.atWork := 0;
  FPerIoData.conFree := 0;

  PerIoData_IsFree := False;
  //TConnectClass(FParentConnect).iocpClass.perIoDataList.Add(Integer(FPerIoData), 0);//把生成的 periodata 都记录下来

end;

destructor TSendHelper.Destroy;
var
  i:Integer;
begin

  if PerIoData_IsFree = False then
  begin
    FPerIoData.conFree := 1; //告诉 iocp 中的,自己先走了..让它自己释放内存//因为是线程同步的,所以操作非关键数据无妨

    //if FPerIoData.atWork = 0 then
    //if FPerIoData.atWork <> 1 then //发送失败时为 999
    if (FPerIoData.atWork = 0)or(FPerIoData.atWork = 999) then //发送失败时为 999
    begin
      PerIoData_IsFree := True;

      //TConnectClass(FParentConnect).iocpClass.perIoDataList.Remove(Integer(FPerIoData));//把生成的 periodata 都记录下来

      IocpFree(FPerIoData, 3);//不在 iocp 中的就可以直接释放了
      FPerIoData := nil;

    end
    else
    begin //test 直接检查看看//确实不能这样,据说是要放在 GetQueuedCompletionStatus 之后
//      if CheckPerIoDataComplete(FPerIoData) then
//      begin
//        PerIoData_IsFree := True;
//
//        //TConnectClass(FParentConnect).iocpClass.perIoDataList.Remove(Integer(FPerIoData));//把生成的 periodata 都记录下来
//
//        IocpFree(FPerIoData, 4);//不在 iocp 中的就可以直接释放了
//        FPerIoData := nil;
//      end;
    end;

  end;


  //sendDataList.Free;

  SendMemory.Clear;
  SendMemory.Free;

  inherited;
end;


//添加到发送缓冲中
procedure TSendHelper.AddSendBuf(buf:PAnsiChar; buflen:Integer);
begin
  //注意写入的方式最后不能是指针
  //SendMemory.Position := SendMemory.Size;
  SendMemory.Seek(0, soFromEnd); //确实有问题,千万不能少
  SendMemory.WriteBuffer(buf^, bufLen{, connect.Iocp_OuterFlag});

end;

//缓冲区中的发送出去
procedure TSendHelper.DoSendBuf(Socket: TSocket);
begin
  //FPerIoData := CreateSendHelperIoData(Socket, OuterFlag);

  if atSend = True then Exit;  //正在发送
  if IoDataGetNext(FPerIoData, 0) = False then Exit;   //没有包了

  atSend := True;

  FPerIoData.Socket := Socket;
  //FPerIoData.OuterFlag := OuterFlag;
  SendBuf(Socket, FPerIoData);


end;


end.
