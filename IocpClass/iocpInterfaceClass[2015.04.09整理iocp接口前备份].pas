unit iocpInterfaceClass;

//iocp 的单独放在这里.
//封装成 delphi 类的,因为添加了 delphi 一些特有的东西,有可能性能下降一些.
//注意:原始的 iocp 在 socket 关闭后仍然会发生 "数据发送完成" 这样的事件,这样就难于决定什么时候释放资源
//为方便起见调用者应当在连接事件中分配资源,在关闭事件中释放资源,在这之外发生的事件由 iocp 实现类过滤掉
//但实现类要保证连接和关闭事件必须成对出现,并且只产生一次.

//内部资源分配/释放原则:
//"单句柄数据结构"与接收的"单IO数据结构"都对一个连接只产生一次,并且同时产生同时释放
//发送用的"单IO数据结构"自己释放,并且在事件中不要使用 "单句柄数据结构" 中的内容,需要用到的 socket 句柄
//直接在生成时附带.这样就可以避免资源释放的混乱.

// 2015/4/3 15:52:10 外部调用问题比较多,先弄一个统一加锁的版本让其形成类似于 indy 的单线程情况,以后有要求再做性能切换

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  winsock2,
  //IdWinSock2,
  //WinSock,

  ComCtrls,Contnrs, iocpInterface, iocpRecvHelper,
  uThreadLock,
  //Contnrs,//TQueue 性能不行
  uFastQueue,uFastHashSocketQueue,
  Dialogs;

type
  TSocket = Cardinal;//u_int;//clq //c 语言原型里的确是无符号的//TSocket 兼容性修正//IdWinSock2 中有误

type
  //连接到达
  TOnSocketConnectProc = procedure (Socket: TSocket; var OuterFlag:Integer{供外部设置连接标志}) of object;
  //接收一块完成
  TOnRecvProc = procedure (Socket: TSocket; buf:PChar; bufLen:Integer; OuterFlag:Integer) of object;

  //与 TOnRecvProc 相同,但可以得到整个通信过程中的完整数据,TOnRecvProc 中只是当前收到的块
  //必须返回 useDataLen(在此事件处理/使用了多个字节的数据,iocp 框架类会清除这部分,否则 iocp 框架类会保留太多的接收数据)
  TOnRecvDataProc = procedure (Socket: TSocket; buf:PChar; bufLen:Integer; OuterFlag:Integer; var useDataLen:Integer) of object;
  //发送一块完成//与接收不同的是,这个是全部发送才产生一次事件
  TOnSendProc = procedure (Socket: TSocket; OuterFlag:Integer) of object;
  //发送一个上层应用包完成//与 TOnSendProc 不同的是,这个是一个上层应用包全部发送才产生一次事件
  //TOnSendOverProc = procedure (Socket: TSocket; OuterFlag:Integer) of object;
  //关闭客户端 socket 时
  TOnSocketCloseProc = procedure (Socket: TSocket; OuterFlag:Integer) of object;


type
  //封装 iocp 的类
  TIocpClass = class(TObject)
  private

  public
    //Count:Integer;//test
    //Count2:Integer;//test
    ListenPort:Integer;
    threadLock:TThreadLock;
    acceptLock:TThreadLock;
    acceptList:TFastQueue;//接收的 socket 列表
    socketList:TFastHashSocketQueue;//连接的 socket 管理列表,目前只用于判断某个 socket 是否已经释放
    //ckeyList:TFastHashSocketQueue;//完成端口的关键字列表

    //--------------------------------------------------
    //SendDataSafe 使用的数据结构
    sendDataList:TList;//要发送的数据列表,每个就是 MakeSendHelperIoData 后的 PerIoData, 即只生成而还未发送
    sendSocketList:TFastHashSocketQueue;//正在发送的 socket 管理列表,目前只能于判断某个 socket 是否处于发送状态,如果是则要等待后再发送
    sendLock:TThreadLock;

    //--------------------------------------------------

    OnRecv:TOnRecvProc;
    OnClose:TOnSocketCloseProc;
    OnSend:TOnSendProc;
    OnConnect:TOnSocketConnectProc;
    OnRecvData:TOnRecvDataProc;//特殊事件

    //触发事件的各函数
    procedure DoConnect(Socket: TSocket; var OuterFlag:Integer); //virtual;
    procedure DoRecv(Socket: TSocket; buf:PChar; bufLen:Integer; OuterFlag:Integer); //virtual;
    procedure DoSend(Socket: TSocket; OuterFlag:Integer); //virtual;
    procedure DoClose(Socket: TSocket; OuterFlag:Integer); //virtual;


    procedure StartService();
    procedure InitSock;

    //function TDHTCPIOCP.SendData(const ConnFlag: Cardinal; pLink: PNewDataLink;
    //const LinkCount: Byte;const Flag: Integer;const pErr:PInteger): Integer;

    //完成端口发送//兼容接口
    procedure SendData(Socket: TSocket; buf: PChar; bufLen: Integer; OuterFlag: Integer);

    //线程安全的同步发送,调用者不需要考虑同步问题,简单地直接调用就行了
    //iocpSendHelper.SendData 在同时发送两组数据时是会相互混淆的,
    //要有一个同步的方式,如果调用者自己进行了同步则可继续使用 SendData
    procedure SendDataSafe(Socket: TSocket; buf: PChar; bufLen: Integer; OuterFlag: Integer);

    //发送下一块,只能是内部调用
    procedure SendDataSafe_Next(Socket: TSocket);

    //--------------------------------------------------
    //方便性的函数

    //用于在 OnRecvData 取 buf 为字符串,因为没有 #0 结尾直接将 buf 当做字符串是很危险的
    function GetBufString_OnRecvData(buf: PChar; bufLen: Integer):string;


    //--------------------------------------------------

  end;

  //工作线程
  TServerWorkerThread = class(TThread)
  private
    procedure Run;
    procedure Synchronize_OnRecv;
    procedure Synchronize_OnSend;
    procedure Synchronize_OnClose;
    { Private declarations }
  protected
    procedure Execute; override;
  public
    iocpClass:TIocpClass;

    threadLock:TThreadLock;

    // 2015/4/3 8:38:17 换一个名字,以免调试时混乱
    //OnRecv:TOnRecvProc;
    //OnClose:TOnSocketCloseProc;
    //OnSend:TOnSendProc;

    OnRecv_thread:TOnRecvProc;
    OnClose_thread:TOnSocketCloseProc;
    OnSend_thread:TOnSendProc;

    CompletionPort : THandle;

    //调用同步事件
  end;

  //创建及接收 socket 线程
  TAcceptThread = class(TThread)
  private
    procedure CreateServer;
    { Private declarations }
  protected
    procedure Execute; override;
  public
    iocpClass:TIocpClass;
    threadLock:TThreadLock;
    acceptLock:TThreadLock;
    acceptList:TFastQueue;//接收的 socket 列表

    OnConnect_thread:TOnSocketConnectProc;

    CompletionPort : THandle;
  end;

  //为加快 accept 的过程,从 TAcceptThread 分离出来
  TAcceptFastThread = class(TThread)
  private
    procedure Synchronize_OnConnect;
    { Private declarations }
  protected
    procedure Execute; override;
  public
    CompletionPort : THandle;
    iocpClass:TIocpClass;
    threadLock:TThreadLock;
    acceptLock:TThreadLock;
    acceptList:TFastQueue;//接收的 socket 列表
    Listensc : THandle;//test

    OnConnect_thread:TOnSocketConnectProc;

  end;



var
  g_IOCP_Synchronize_Event:Boolean = True; // 2015/4/3 8:46:06 是否使用 Synchronize 的方式调用事件函数//对于界面操作比较多的时使用;对发生要求非常高的地方禁用


//--------------------------------------------------
//方便性的函数

//用于在 OnRecvData 取 buf 为字符串,因为没有 #0 结尾直接将 buf 当做字符串是很危险的
function GetBufString(buf: PChar; bufLen: Integer):string;

//--------------------------------------------------


implementation

uses iocpSendHelper, uLogFile;

//uses uThreadLock;

//用于在 OnRecvData 取 buf 为字符串,因为没有 #0 结尾直接将 buf 当做字符串是很危险的
function GetBufString(buf: PChar; bufLen: Integer):string;
begin
  SetLength(Result, 0);//这样安全点
  SetLength(Result, bufLen);
  CopyMemory(@Result[1], buf, bufLen);
end;



//创建服务
procedure TAcceptThread.CreateServer;
var
  i:Integer;
  Acceptsc:Integer;
  PerHandleData : LPPER_HANDLE_DATA;//这个应该是可更改的
  sto:sockaddr_in;
  Listensc :Integer;
  LocalSI:TSystemInfo;
  CompletionPort : THandle;

  thread:TServerWorkerThread;
  //OuterFlag:Integer;
  threadFast:TAcceptFastThread;


begin

  InitSock();

  //创建一个完成端口。
  CompletionPort := CreateIOCompletionPort(INVALID_HANDLE_VALUE,0,0,0);

  //根据CPU的数量创建CPU*2数量的工作者线程。
  GetSystemInfo(LocalSI);
  for i:=0 to LocalSI.dwNumberOfProcessors * 2 -1 do
  begin
      {
      //delphi 要用 BeginThread 代替 CreateThread
      //hThread := CreateThread(nil, 0, @ServerWorkerThread, Pointer(CompletionPort),0, ThreadID);
      //奇怪,这里不能用 BeginThread,否则 cpu 会非常高(调用等细节不同,算了,用 CreateThread 好了)
      IsMultiThread := TRUE;//用这个后也可以用 CreateThread
      hThread := CreateThread(nil, 0, @ServerWorkerThread, Pointer(CompletionPort),0, ThreadID);
      if (hThread = 0) then
      begin
          Exit;
      end;
      CloseHandle(hThread);
      }
      thread := TServerWorkerThread.Create(True);
      thread.CompletionPort := CompletionPort;
      
      thread.iocpClass := Self.iocpClass;

      //这些变量最好是直接赋值不要经过 iocpClass,这样更安全
      thread.threadLock := iocpClass.threadLock;
      thread.OnRecv_thread     := iocpClass.DoRecv;//OnRecv;
      thread.OnClose_thread    := iocpClass.DoClose;//OnClose;
      thread.OnSend_thread     := iocpClass.DoSend;//OnSend;

      thread.Resume;

  end;

  //--------------------------------------------------
  //创建 accept 处理线程
  threadFast := TAcceptFastThread.Create(True);
  threadFast.CompletionPort := CompletionPort;
  threadFast.iocpClass := Self.iocpClass;
  threadFast.Listensc := Listensc;//test,可以在另一个线程中使用吗

  //这些变量最好是直接赋值不要经过 iocpClass,这样更安全
  threadFast.threadLock := iocpClass.threadLock;
  threadFast.acceptLock := iocpClass.acceptLock;
  threadFast.acceptList := iocpClass.acceptList;
  threadFast.OnConnect_thread := iocpClass.DoConnect;//OnConnect;
  threadFast.Resume;

  //--------------------------------------------------


  //创建一个套接字，将此套接字和一个端口绑定并监听此端口。
  Listensc:=WSASocket(AF_INET,SOCK_STREAM,0,Nil,0,WSA_FLAG_OVERLAPPED);
  if Listensc=SOCKET_ERROR then
  begin
       closesocket(Listensc);
       WSACleanup();
  end;
  sto.sin_family:=AF_INET;
  sto.sin_port := htons(iocpClass.ListenPort);//htons(5500);
  sto.sin_addr.s_addr:=htonl(INADDR_ANY);
  if bind(Listensc,@sto,sizeof(sto))=SOCKET_ERROR then
  begin
      closesocket(Listensc);
  end;
  //listen(Listensc,20);         SOMAXCONN
  //listen(Listensc, SOMAXCONN);
  //listen(Listensc, $7fffffff);//WinSock2.SOMAXCONN);
  listen(Listensc, 1);//WinSock2.SOMAXCONN);// 2015/4/3 15:03:26 太大的话其实也是有问题的,会导致程序停止响应时客户端仍然可以连接上,并且大量的占用

  //--------------------------------------------------
  while (TRUE) do
  begin
    //当客户端有连接请求的时候，WSAAccept函数会新创建一个套接字Acceptsc。这个套接字就是和客户端通信的时候使用的套接字。
    Acceptsc:= WSAAccept(Listensc, nil, nil, nil, 0);


    //判断Acceptsc套接字创建是否成功，如果不成功则退出。
    if (Acceptsc= SOCKET_ERROR) then
    begin
      Sleep(1);
      Continue;

      // 2015/4/7 14:03:50 不一定要退出,有可能是内存暂时性不足
      //closesocket(Listensc);
      //exit;
    end;

    //--------------------------------------------------
    //用另外的线程处理 onconnect 事件的话有一个问题,就是 onconnect 事件有可能会在 onrecv 事件后发生//应该也不会,因为 CreateIoCompletionPort 还没调用

    try
      acceptLock.Lock('acceptLock.Lock');//很简单,不用 try 了// 2015/4/3 13:48:29  还是要的,因为 lock 本身分异常
      acceptList.Write(Acceptsc);
    finally
      acceptLock.UnLock;
    end;
    //acceptList.Read(Acceptsc);

    Continue;

  end;

end;



procedure TIocpClass.DoClose(Socket: TSocket; OuterFlag: Integer);
var
  helper:TRecvHelper;
  tmp:Pointer;
begin

  {$ifndef EXCEPT_DEBUG}//调试异常的情况下屏蔽
  try
  {$endif}
    //close 事件比较特殊,已经加锁了//threadLock.Lock;//线程引发的,必须锁定

    try
      if socketList.GetItem(Socket, tmp) = False then
      begin
        //MessageBox(0, '一个 socket 重复关闭释放!', '内部服务器错误', 0);//这种情况下未连接就关闭时很多
        Exit;
      end;

      helper := TRecvHelper(OuterFlag);
      OuterFlag := helper.OuterFlag;//恢复占用的外部标识


      if Assigned(OnClose) then OnClose(Socket, OuterFlag);//必须在 free 前调用

      socketList.DeleteItem(Socket);//记录


      helper.Free;

    finally
    //close 事件比较特殊,已经加锁了//  threadLock.UnLock;
    end;

  {$ifndef EXCEPT_DEBUG}//调试异常的情况下屏蔽
  except//必须用 except 去掉异常,否则后面的数据接收不响应
  end;
  {$endif}


end;

procedure TIocpClass.DoConnect(Socket: TSocket; var OuterFlag: Integer);
var
  helper:TRecvHelper;
  sendHelper:TSendHelper;
  PerIoData : LPPER_IO_OPERATION_DATA;
  tmp:Pointer;
begin


  //事件中都加了这但加 except 后性能下降比较厉害

  //特别是在 accept 表现得特别明显,我的机器发送 1000 个连接原来是全部接收的现在只接收了 600 个,所以 onconnet 事件里不要用 except 异常,并且用户事件中也要快速通过.


  {$ifndef EXCEPT_DEBUG}//调试异常的情况下屏蔽
  try
  {$endif}

    try
      //threadLock.Lock('TIocpClass.DoConnect');//线程引发的,必须锁定


      //--------------------------------------------------
      //因为 iocp 断开过程中并没有释放发送助手,所以要有个地方释放,而连接的地方更简洁有效
      try
        sendLock.Lock('sendLock.Lock');

        LogFile('debug 0: sendLock.Lock;');


        sendHelper := nil;
        //有正在发送的话
        if sendSocketList.GetItem(Socket, Pointer(sendHelper)) = True{False} then
        begin
          //释放还保存着的所有 iocp 数据包
          //if helper = nil then helper := TSendHelper.Create;
          while sendHelper.PopSendData(PerIoData) = True do
          begin
            FreeSendHelperIoData(PerIoData);  //发送包释放方式
          end;

          //重置发送句柄,将 socket 回收,实际使用中发现 socket 相同的值重复使用的概率非常高
          begin
            sendSocketList.DeleteItem(Socket);
            sendHelper.Free;
          end;

        end;

      finally
        sendLock.UnLock;
      end;
      //--------------------------------------------------

      LogFile('debug 1: sendLock.UnLock;');


      if Assigned(OnConnect) then OnConnect(Socket, OuterFlag);

      LogFile('debug 2: OnConnect(Socket, OuterFlag);');


      if socketList.GetItem(Socket, tmp)
      then LogFile('上次的关闭还未完成. ' + IntToStr(Socket))
      else socketList.SetItem(Socket, nil);//记录,要判断一下原来的是否存在,否则就是重复设置 socket 了会报错的

      helper := TRecvHelper.Create;
      helper.OuterFlag := OuterFlag;

      //注意,这里改写了 OuterFlag, 所以在其他事件中要恢复过来
      OuterFlag := Integer(helper);


    finally
      //threadLock.UnLock;
      //LogFile('debug 3: threadLock.UnLock;');
    end;
    LogFile('debug 4: end;');

  {$ifndef EXCEPT_DEBUG}//调试异常的情况下屏蔽
  except//必须用 except 去掉异常,否则后面的数据接收不响应
  end;
  {$endif}

end;

procedure TIocpClass.DoRecv(Socket: TSocket; buf: PChar; bufLen: Integer; OuterFlag: Integer);
var
  helper:TRecvHelper;
  useDataLen:Integer;

begin

  {$ifndef EXCEPT_DEBUG}//调试异常的情况下屏蔽
  try
  {$endif}

    try
      //threadLock.Lock('TIocpClass.DoRecv');//线程引发的,必须锁定

      helper := TRecvHelper(OuterFlag);
      OuterFlag := helper.OuterFlag;//恢复占用的外部标识

      //这里有问题,会导致后面的recv不产生 iocp 事件,看一下可能是有内存越界等
      if Assigned(OnRecv) then OnRecv(Socket, buf, bufLen, OuterFlag);

      //test
//      if helper.FMemory.Size > 1024 * 1024 * 1 then
//      begin
//        MessageBox(0, '单个连接从客户端接收了太多数据而未处理', '服务器内部错误', 0);
//      end;

      helper.OnRecv(Socket, buf, bufLen, OuterFlag);

      useDataLen := 0;
      //注意这里传入全部数据
      if Assigned(OnRecvData)
      then OnRecvData(Socket, helper.FMemory.Memory, helper.FMemory.Size, OuterFlag, useDataLen)
      else useDataLen := bufLen;//没有用户事件的话就全部清理掉好了

      //TRecvHelper.ClearData(helper, 2);//test
      //清除用户在事件中处理过了的数据
      TRecvHelper.ClearData(helper, useDataLen);



    finally
      //threadLock.UnLock;
    end;

  {$ifndef EXCEPT_DEBUG}//调试异常的情况下屏蔽
  except//必须用 except 去掉异常,否则后面的数据接收不响应
  end;
  {$endif}



end;

procedure TIocpClass.DoSend(Socket: TSocket; OuterFlag: Integer);
var
  helper:TRecvHelper;
  tmp:Pointer;
begin

  {$ifndef EXCEPT_DEBUG}//调试异常的情况下屏蔽
  try
  {$endif}

    try
      //threadLock.Lock('TIocpClass.DoSend');//线程引发的,必须锁定

      //这时候传入的标识有可能是错误的,不过只会发生在发送的时候
      if OuterFlag <> 0 then
      begin
        //TRecvHelper 只是在接收时使用,不要修改发送时的 OuterFlag 外部标识
//        helper := TRecvHelper(OuterFlag);
//        OuterFlag := helper.OuterFlag;//恢复占用的外部标识

      end;

      //句柄已经释放了就不要再触发事件给上层了
      if socketList.GetItem(Socket, tmp)=False then
      begin
        //MessageBox(0, 'socket已释放!', '', 0);
        Exit;
      end;

      if Assigned(OnSend) then OnSend(Socket, OuterFlag);

    finally
      //threadLock.UnLock;
    end;

  {$ifndef EXCEPT_DEBUG}//调试异常的情况下屏蔽
  except//必须用 except 去掉异常,否则后面的数据接收不响应
  end;
  {$endif}


end;

function TIocpClass.GetBufString_OnRecvData(buf: PChar;
  bufLen: Integer): string;
begin
  Result := GetBufString(buf, bufLen)
end;

procedure TIocpClass.InitSock;
var
  wsData: TWSAData;
begin
  if WSAStartUp($202, wsData) <> 0 then
  begin
      WSACleanup();
  end;

end;

//--------------------------------------------------
// 2015/4/3 9:38:45 同步事件
var
  Synchronize_OnRecv_Socket:TSocket = 0;
  Synchronize_OnRecv_buf:PChar = nil;
  Synchronize_OnRecv_BytesTransferred:Integer = 0;
  Synchronize_OnRecv_OuterFlag:Integer = 0;

procedure TServerWorkerThread.Synchronize_OnRecv;
begin
  LogFile('Synchronize_OnRecv');

  //if Assigned(OnRecv_thread) then OnRecv_thread(PerHandleData.Socket, PerIoData.DataBuf.buf, BytesTransferred, PerHandleData.OuterFlag);

  if Assigned(OnRecv_thread) then OnRecv_thread(Synchronize_OnRecv_Socket, Synchronize_OnRecv_buf, Synchronize_OnRecv_BytesTransferred, Synchronize_OnRecv_OuterFlag);

end;
//--------------------------------------------------
// 2015/4/3 9:38:45 同步事件
var
  Synchronize_OnSend_Socket:TSocket = 0;
  Synchronize_OnSend_OuterFlag:Integer = 0;

procedure TServerWorkerThread.Synchronize_OnSend;
begin
  LogFile('Synchronize_OnSend');

  //if Assigned(OnSend_thread) then OnSend_thread(PerIoData.Socket, PerIoData.OuterFlag);
  if Assigned(OnSend_thread) then OnSend_thread(Synchronize_OnSend_Socket, Synchronize_OnSend_OuterFlag);


end;

//--------------------------------------------------
// 2015/4/3 9:38:45 同步事件
var
  Synchronize_OnClose_Socket:TSocket = 0;
  Synchronize_OnClose_OuterFlag:Integer = 0;

procedure TServerWorkerThread.Synchronize_OnClose;
begin
  LogFile('Synchronize_OnClose');

  //if Assigned(IocpOnClose) then IocpOnClose(PerHandleData.Socket);//必须在 free 前调用
  //if Assigned(OnClose_thread) then OnClose_thread(PerHandleData.Socket, PerHandleData.OuterFlag);//必须在 free 前调用

  if Assigned(OnClose_thread) then OnClose_thread(Synchronize_OnClose_Socket, Synchronize_OnClose_OuterFlag);//必须在 free 前调用


end;





//--------------------------------------------------

//工作线程//有一个问题是怎么知道所有的 PerIoData 和 PerHandleData 都正确释放而没有内存泄漏呢
procedure TServerWorkerThread.Run;//CompletionPortID:Pointer):Integer;stdcall;
var
    BytesTransferred,dwFlags: DWORD;
    PerIoData : LPPER_IO_OPERATION_DATA;//这里是自己用的临时变量
    TempSc:Integer;
    PerHandleData : LPPER_HANDLE_DATA;
    SendBytes:DWORD;
    RecvBytes:DWORD;//接收到的字节数
    Flags:DWORD;
    //CompletionPort : THandle;
    tmp:Pointer;


    procedure ClearSocket();
    begin

      //GlobalFree(DWORD(PerHandleData));

      //--------------------------------------------------

        if PerHandleData.isFree <> 0 then //按道理这时候的 PerHandleData 不应该是无用值?//有可能是 send 或者 recv 时出错立即销毁后产生的?
        begin
          //ShowMessage('access violation');//实际上确实是 access violation 错误
          //MessageBox(0, 'access violation', '服务器内部错误', 0);
          Exit;
          //按道理应该是不会到这里的,多数是程序内部错误造成(例如指针访问违例)
        end;

        //根据目前的业务逻辑只有一个接收 iodata 并且是一直在接收的,所以 socket 的销毁可以和接收 io 绑定在一起
        //而发送包事件中就不要销毁 socket 了,以免 as 错误
        if (PerIoData <> nil)and(PerIoData.OpCode = 1) then//test
        begin
          closesocket(PerHandleData.Socket);

          Exit;
          //ShowMessage('access violation');//实际上确实是 access violation 错误
        end;


        //根据目前的业务逻辑只有一个接收 iodata 并且是一直在接收的,所以 socket 的销毁可以和接收 io 绑定在一起
        //而发送包事件中就不要销毁 socket 了,以免 as 错误
        if  ((PerIoData <> nil)and(PerIoData.OpCode = 0))
          or((PerIoData = nil)) //如果是还未关联 PerIoData 就被关闭了 socket 那么这时候的 PerIoData 就应该是空
         then
        begin
          closesocket(PerHandleData.Socket);

          //--------------------------------------------------
          // 2015/4/3 11:01:27 用户事件
          //不要锁定,里面有锁

          if g_IOCP_Synchronize_Event = False then
          begin
            //if Assigned(IocpOnClose) then IocpOnClose(PerHandleData.Socket);//必须在 free 前调用
            if Assigned(OnClose_thread) then OnClose_thread(PerHandleData.Socket, PerHandleData.OuterFlag);//必须在 free 前调用

          end
          else
          begin
            Synchronize_OnClose_Socket := PerHandleData.Socket;
            Synchronize_OnClose_OuterFlag := PerHandleData.OuterFlag;

            LogFile('Synchronize_OnClose:' + IntToStr(Self.ThreadID));
            Self.Synchronize(Self.Synchronize_OnClose);
            LogFile('Synchronize_OnClose end:' + IntToStr(Self.ThreadID));

          end;

         //--------------------------------------------------


          PerHandleData.isFree := 1;
          GlobalFree(DWORD(PerHandleData));
        end;

    end;

    procedure ClearIoData();//代替 GlobalFree(DWORD(PerIoData));
    begin
      //if Assigned(IocpOnClose) then IocpOnClose(PerHandleData.Socket);//必须在 free 前调用
      //GlobalFree(DWORD(PerIoData));

      if PerIoData.OpCode = 1
      //现在发送包要特别删除
      then FreeSendHelperIoData(PerIoData)  //发送包释放方式
      else GlobalFree(DWORD(PerIoData));    //接收包释放方式

    end;

//--------------------------------------------------
var
  bSleep:Boolean; // 2015/4/3 15:59:53 是否让循环等待一下
  bGet:BOOL; //GetQueuedCompletionStatus 的返回值

begin
  BytesTransferred := 0;

  bSleep := False;

    //CompletionPort:=THANDLE(CompletionPortID);
    //得到创建线程是传递过来的IOCP
    while(True) do
    begin

      if bSleep then
      begin
        Sleep(1);
        bSleep := False;
      end;

      //--------------------------------------------------
      //PerHandleData.IsFree := 3;//test GetQueuedCompletionStatus 失败的时候会有无效的 PerHandleData 值?(确实如此,它会保持 PerHandleData 本身的值不变)
      PerHandleData := nil;//test GetQueuedCompletionStatus 失败的时候会有无效的 PerHandleData 值?(确实如此,它会保持 PerHandleData 本身的值不变)
      PerIoData := nil;

      //工作者线程会停止到GetQueuedCompletionStatus函数处，直到接受到数据为止
      //if (GetQueuedCompletionStatus(CompletionPort, BytesTransferred, DWORD(PerHandleData), POverlapped(PerIoData), INFINITE) = False) then
      bGet := GetQueuedCompletionStatus(CompletionPort, BytesTransferred, DWORD(PerHandleData), POverlapped(PerIoData), INFINITE);

      try
        threadLock.Lock('TServerWorkerThread.Run');

         //工作者线程会停止到GetQueuedCompletionStatus函数处，直到接受到数据为止
         //if (GetQueuedCompletionStatus(CompletionPort, BytesTransferred, DWORD(PerHandleData), POverlapped(PerIoData), INFINITE) = False) then
         if (bGet = False) then
         begin
           //实际上这种情况是会发生的,这里 PerHandleData 无效,只能关闭 socket 不能做别的清理工作(但这时是不知道 socket 的,所以什么都不能做)
           //if PerHandleData.IsFree = 3 then
           if PerHandleData = nil then
           begin
             //ShowMessage('error GetQueuedCompletionStatus()');
             //MessageBox(0,'error GetQueuedCompletionStatus()', '', 0);
             Continue;
           end;

           //当客户端连接断开或者客户端调用closesocket函数的时候,函数GetQueuedCompletionStatus会返回错误。如果我们加入心跳后，在这里就可以来判断套接字是否依然在连接。
           if PerHandleData<>nil then
           begin
             //closesocket(PerHandleData.Socket);
             //GlobalFree(DWORD(PerHandleData));
             ClearSocket();
           end
           else
           begin
             //Sleep(1);
             bSleep := True;
           end;

           if PerIoData<>nil then
           begin
             //GlobalFree(DWORD(PerIoData));
             ClearIoData();
           end
           else
           begin
             Sleep(1);
           end;

           continue;
         end;

         //当客户端调用shutdown函数来从容断开的时候，我们可以在这里进行处理。
         if (BytesTransferred = 0) then
         begin
            if PerHandleData<>nil then
            begin
              TempSc:=PerHandleData.Socket;
              shutdown(PerHandleData.Socket, 1);
              //closesocket(PerHandleData.Socket);
              //GlobalFree(DWORD(PerHandleData));
              ClearSocket;
            end;
            if PerIoData<>nil then
            begin
              //GlobalFree(DWORD(PerIoData));
              ClearIoData();
            end;
            continue;
         end;

         //--------------------------------------------------
         //这里才开始正常的处理
         //在上一篇中我们说到IOCP可以接受来自客户端的数据和自己发送出去的数据，两种数据的区别在于我们定义的结构成员...

         //当是接受来自客户端的数据是，我们进行数据的处理。
         if (PerIoData.OpCode = 0) then
         begin
           PerIoData.DataBuf.buf := PerIoData.Buf + PerIoData.BytesSEND;
           PerIoData.DataBuf.len := PerIoData.BytesRECV - PerIoData.BytesSEND;
           //这时变量PerIoData.Buffer就是接受到的客户端数据。数据的长度是PerIoData.DataBuf.len 你可以对数据进行相关的处理了。
           //.......

           //--------------------------------------------------
           //发送一些测试数据
           //SendBuf_test(PerHandleData.Socket);
           //SendBuf(PerHandleData.Socket, 'aaa'#13#10, 5);
           //正规做法应当是触发一个事件或是回调函数,由上层应用决定是否发送

           //threadLock.Lock;//线程引发的,必须锁定,代码太乱了锁定代码还是放到事件处理函数中

           //if Assigned(IocpOnRecv) then IocpOnRecv(PerHandleData.Socket, PerIoData.DataBuf.buf, PerIoData.DataBuf.len);
           //PerIoData.DataBuf.len 里没有值?
           //if Assigned(IocpOnRecv) then IocpOnRecv(PerHandleData.Socket, PerIoData.DataBuf.buf, BytesTransferred);
//这里有问题,会导致后面的recv不产生 iocp 事件,看一下可能是有内存越界等
//这里不用判断对应的 socket 是否已经释放了,socket 被关闭后才发生接收事件是不可能的,因为每个连接在本框架中只生产一个接收 io 结构
//并且是顺序调用的.而发送失败时只关闭句柄,并不释放对应 socket 的接收结构和io句柄结构(如果以后实现改了则要判断)
//     ll

           //--------------------------------------------------
           // 2015/4/3 11:01:27 用户事件
           //不要锁定,里面有锁

            if g_IOCP_Synchronize_Event = False then
            begin
              if Assigned(OnRecv_thread) then OnRecv_thread(PerHandleData.Socket, PerIoData.DataBuf.buf, BytesTransferred, PerHandleData.OuterFlag);

            end
            else
            begin
              Synchronize_OnRecv_Socket := PerHandleData.Socket;
              Synchronize_OnRecv_buf := PerIoData.DataBuf.buf;
              Synchronize_OnRecv_BytesTransferred := BytesTransferred;
              Synchronize_OnRecv_OuterFlag := PerHandleData.OuterFlag;

              LogFile('Synchronize_OnRecv:' + IntToStr(Self.ThreadID));
              Self.Synchronize(Self.Synchronize_OnRecv);
              LogFile('Synchronize_OnRecv end:' + IntToStr(Self.ThreadID));

              //Synchronize_OnConnect_Acceptsc := Acceptsc;//还要将参数传出//这里不用
              //OuterFlag := Synchronize_OnConnect_OuterFlag;//还要将参数传出
            end;

           //--------------------------------------------------

           //当我们将数据处理完毕以后，应该将此套接字设置为结束状态，同时初始化和它绑定在一起的数据结构。
           ZeroMemory(@(PerIoData.Overlapped), sizeof(OVERLAPPED));
           PerIoData.BytesRECV := 0;
           Flags := 0;
           ZeroMemory(@(PerIoData.Overlapped), sizeof(OVERLAPPED));
           PerIoData.DataBuf.len := DATA_BUFSIZE;
           ZeroMemory(@PerIoData.Buf,sizeof(@PerIoData.Buf));
           PerIoData.DataBuf.buf := @PerIoData.Buf;

           //再次投递一个接收请求
           //if (WSARecv(PerHandleData.Socket, @(PerIoData.DataBuf), 1, @RecvBytes, @Flags,@(PerIoData.Overlapped), nil) = SOCKET_ERROR) then
           if (WSARecv(PerHandleData.Socket, @(PerIoData.DataBuf), 1, RecvBytes, Flags,@(PerIoData.Overlapped), nil) = SOCKET_ERROR) then
           begin
             //MessageBox(0, 'a', '', 0);不能放在这里,会使 WSAGetLastError() 失效
             if (WSAGetLastError() <> ERROR_IO_PENDING) then
             begin
               //MessageBox(0, 'a2', '', 0);
               //ExitProcess(0);

               if PerHandleData<>nil then
               begin
                 TempSc:=PerHandleData.Socket;
                 //closesocket(PerHandleData.Socket);
                 //GlobalFree(DWORD(PerHandleData));
                 ClearSocket;
               end;
               if PerIoData<>nil then
               begin
                 //GlobalFree(DWORD(PerIoData));
                 ClearIoData();
               end;
               continue;
             end;

           end;

           //投递失败的情况下应当也是不删除的//仍然需要,如果这时候对方 socket 忽然关闭,那么是不一定会触发 iocp 的 GetQueuedCompletionStatus 的
//           WSARecv(PerHandleData.Socket, @(PerIoData.DataBuf), 1, @RecvBytes, @Flags,@(PerIoData.Overlapped), nil);
         end
         //--------------------------------------------------
         //**************************************************
         //--------------------------------------------------
         //当我们判断出来接受的数据是我们发送出去的数据的时候，在这里我们清空我们申请的内存空间
         else//发送的情况
         begin
           //应当要判断一下是否发送完了,再决定是否删除//也可以不删除,让它们跟着 socket ,不过有可能 socket 删除了,这个还在触发事件
           PerIoData.BytesSEND := PerIoData.BytesSEND + BytesTransferred;

           //发送完毕了
           //if PerIoData.BytesSEND >= PerIoData.BufLen then
           //begin
           //  //这里是不能保证 PerHandleData 没有释放的,因为接收出错可能在前,那么这时候 PerHandleData.Socket 实际上是不可用的
           //  //其实可以把 PerHandleData.Socket 放到 PerIoData 中
           //  if Assigned(OnSend) then OnSend(PerIoData.Socket, PerIoData.OuterFlag);
           //
           //  //GlobalFree(DWORD(PerIoData));
           //  ClearIoData();
           //  //FreeSendHelperIoData(PerIoData);
           //  Continue;
           //end;

           //移动缓冲位置(跳过已发送的数据)继续发送剩余的部分//另,接收部分没有必要多次,接收到多少报告上层调用者就行了,由上层决定是否继续接收
           //PerIoData.DataBuf.buf := PerIoData.Buf + PerIoData.BytesSEND;
           //PerIoData.DataBuf.len := PerIoData.BufLen - PerIoData.BytesSEND;

           //取下一个包内容,不能再象上面那样计算了 特别是计算长度时很可能会越界
           if IoDataGetNext(PerIoData, BytesTransferred) = True then
           begin
             Flags := 0;//有时候不一定是 0 ,要再赋值//可能是 delphi 初始化 bug ? 按道理 delphi 是会初始化变量的

             //WSASend(PerHandleData.Socket, @(PerIoData.DataBuf), 1{这个应该指的是缓冲结构的个数,固定为1}, @SendBytes, Flags, @(PerIoData.Overlapped), nil);
             WSASend(PerIoData.Socket, @(PerIoData.DataBuf), 1{这个应该指的是缓冲结构的个数,固定为1}, SendBytes, Flags, @(PerIoData.Overlapped), nil);
             //WSASend(PerIoData.Socket,   @(PerIoData.DataBuf), 1{这个应该指的是缓冲结构的个数,固定为1}, @SendBytes, Flags, @(PerIoData.Overlapped), nil);

           end
           else//全部发送成功了
           begin

             //--------------------------------------------------
             // 2015/4/3 11:01:27 用户事件
             //不要锁定,里面有锁

              if g_IOCP_Synchronize_Event = False then
              begin
               if Assigned(OnSend_thread) then OnSend_thread(PerIoData.Socket, PerIoData.OuterFlag);

              end
              else
              begin
                Synchronize_OnSend_Socket := PerIoData.Socket;
                Synchronize_OnSend_OuterFlag := PerIoData.OuterFlag;

                LogFile('Synchronize_OnSend:' + IntToStr(Self.ThreadID));
                Self.Synchronize(Self.Synchronize_OnSend);
                LogFile('Synchronize_OnSend end:' + IntToStr(Self.ThreadID));

                //Synchronize_OnConnect_Acceptsc := Acceptsc;//还要将参数传出//这里不用
                //OuterFlag := Synchronize_OnConnect_OuterFlag;//还要将参数传出
              end;

             //--------------------------------------------------


             //看看是否有缓冲包要发送
             iocpClass.SendDataSafe_Next(PerIoData.Socket);

             //GlobalFree(DWORD(PerIoData));
             ClearIoData();

           end;

         end;

      finally
        threadLock.UnLock();
      end;
    end;

end;


{ TServerWorkerThread }

procedure TServerWorkerThread.Execute;
begin
  inherited;
  Run;

  LogFile('TServerWorkerThread.Execute 已退出.');//记录下,是否异常退出

end;


{ TCreateServerThread }

procedure TAcceptThread.Execute;
begin
  inherited;

  CreateServer;

  LogFile('TAcceptThread.Execute 已退出.');//记录下,是否异常退出


end;

{ TIocpClass }

procedure TIocpClass.SendData(Socket: TSocket; buf: PChar; bufLen: Integer; OuterFlag: Integer);
begin
  iocpSendHelper.SendData(Socket, buf, bufLen, OuterFlag);

end;

//线程安全的同步发送,调用者不需要考虑同步问题,简单地直接调用就行了
procedure TIocpClass.SendDataSafe(Socket: TSocket; buf: PChar; bufLen,
  OuterFlag: Integer);
var
  helper:TSendHelper;
  PerIoData: LPPER_IO_OPERATION_DATA;
begin
  try
    sendLock.Lock('TIocpClass.SendDataSafe');

    helper := nil;
    if sendSocketList.GetItem(Socket, Pointer(helper)) = False then
    begin//没有正在发送的话,发送
      helper := TSendHelper.Create;
      helper.socket := Socket;
      sendSocketList.SetItem(Socket, helper);
      SendData(Socket, buf, bufLen, OuterFlag);//因为这块数据立即发送了,所以不用放在缓冲中
    end
    else//有正在发送的话,等待
    begin
      //if helper = nil then helper := TSendHelper.Create;
      PerIoData := MakeSendHelperIoData(Socket, buf, bufLen, OuterFlag);
      helper.sendDataList.Add(PerIoData);
      // 2012-10-10 15:33:46
      //这种判断有一个隐患,如果这时的 helper 因为某种原因并没有释放而被下一个连接使用了,那么就会再也不发送了,所以
      //要在连接的地方清空一下.同时要注意,释放的地方不要因为这个清空导致异常
    end;

  finally
    sendLock.UnLock;
  end;

end;

//发送下一块,只能是内部调用
procedure TIocpClass.SendDataSafe_next(Socket: TSocket);
var
  sendHelper:TSendHelper;
  PerIoData: LPPER_IO_OPERATION_DATA;
begin
  try
    sendLock.Lock('TIocpClass.SendDataSafe_next');
    sendHelper := nil;
    //有正在发送的话
    if sendSocketList.GetItem(Socket, Pointer(sendHelper)) = True{False} then
    begin
      //if helper = nil then helper := TSendHelper.Create;
      if  sendHelper.PopSendData(PerIoData) = True then
      begin
        SendBuf(Socket, PerIoData);
      end
      else//没有数据了,清空
      begin
        sendSocketList.DeleteItem(Socket);
        sendHelper.Free;
      end;

    end;

  finally
    sendLock.UnLock;
  end;

end;


procedure TIocpClass.StartService;
var
  thread:TAcceptThread;

begin
  Self.threadLock := TThreadLock.Create(Application);
  acceptLock := TThreadLock.Create(Application);
  acceptList := TFastQueue.Create(20000);//20000//其实 2000 就足够了
  socketList := TFastHashSocketQueue.Create();
  //ckeyList := TFastHashSocketQueue.Create();
  //Count := 0;
  //Count2 := 0;

  sendDataList := TList.Create;
  sendSocketList := TFastHashSocketQueue.Create();
  sendLock := TThreadLock.Create(Application);


  thread := TAcceptThread.Create(True);
  thread.iocpClass := Self;

  //这些变量最好是直接赋值不要经过 iocpClass,这样更安全
  thread.threadLock := Self.threadLock;
  thread.acceptLock := Self.acceptLock;
  thread.acceptList := Self.acceptList;
  thread.OnConnect_thread := Self.DoConnect;//OnConnect;
  thread.Resume;



end;

{ TAcceptFastThread }

//完成端口开始接收第一个包,其实只有一个地方调用
function RecvNewBuf(Socket: TSocket; OuterFlag:Integer; var PerIoData:LPPER_IO_OPERATION_DATA):Boolean;
var
  dwFlags: DWORD;
  //PerIoData : LPPER_IO_OPERATION_DATA;//这里是自己用的临时变量
  RecvBytes:DWORD;//接收到的字节数
  Flags:DWORD;
  errno:Integer;
begin
    Result := True;
    PerIoData := nil;


    //创建一个“单IO数据结构”其中将PerIoData.BytesSEND 和PerIoData.BytesRECV 均设置成0。说明此“单IO数据结构”是用来接受的。
    PerIoData := LPPER_IO_OPERATION_DATA(GlobalAlloc(GPTR, sizeof(PER_IO_OPERATION_DATA)));
    if (PerIoData = nil) then
    begin
      PerIoData := nil;
      Sleep(1);//test
      exit;
    end;
    ZeroMemory(@PerIoData.Overlapped, sizeof(OVERLAPPED));
    PerIoData.BytesSEND := 0;
    PerIoData.BytesRECV := 0;
    PerIoData.DataBuf.len := DATA_BUFSIZE;//1024;
    PerIoData.DataBuf.buf := @PerIoData.Buf;
    PerIoData.OpCode := 0;//接收用的
    PerIoData.Socket := Socket;//用做关键字的话,放这里更安全
    PerIoData.OuterFlag := OuterFlag;//用做关键字的话,放这里更安全
    Flags := 0;


    //用此“单IO数据结构”来接受Acceptsc套接字的数据。
    //if (WSARecv(Socket, @(PerIoData.DataBuf), 1, @RecvBytes, @Flags,@(PerIoData.Overlapped), nil) = SOCKET_ERROR) then
    if (WSARecv(Socket, @(PerIoData.DataBuf), 1, RecvBytes, Flags,@(PerIoData.Overlapped), nil) = SOCKET_ERROR) then
    begin
       errno := WSAGetLastError();       //WSAENOTSOCK
       //if (WSAGetLastError() <> ERROR_IO_PENDING) then
       if (errno <> ERROR_IO_PENDING) then//出现这个错误必定要销毁对话 socket 和在这里分配的内存
       begin
         //MessageBox(0, 'b', '', 0);
         result := False;
         exit;
       end
    end;

end;

//--------------------------------------------------
// 2015/4/3 9:38:45 同步事件
var
  Synchronize_OnConnect_Acceptsc:Integer = 0;
  Synchronize_OnConnect_OuterFlag:Integer = 0;

procedure TAcceptFastThread.Synchronize_OnConnect;
begin
  LogFile('Synchronize_OnConnect');

  //if Assigned(OnConnect_thread) then OnConnect_thread(Acceptsc, OuterFlag);

  if Assigned(OnConnect_thread) then OnConnect_thread(Synchronize_OnConnect_Acceptsc, Synchronize_OnConnect_OuterFlag);

  //Synchronize_OnConnect_Acceptsc := 0;
  //Synchronize_OnConnect_OuterFlag := 0;//这些标志还有用的,不能改

end;

//--------------------------------------------------

procedure TAcceptFastThread.Execute;
var
  Acceptsc:Integer;
  PerHandleData : LPPER_HANDLE_DATA;//这个应该是可更改的
  PerIoData : LPPER_IO_OPERATION_DATA;//这里是自己用的临时变量

  OuterFlag:Integer;
  haveSocket:Boolean;
  re:Boolean;
  buff:array[0..1024] of Char;
  str:PChar;
  bindErr:Boolean;
  tmp:Pointer;
begin
  inherited;

  while(TRUE) do
  begin

    //--------------------------------------------------
    try
      acceptLock.Lock('acceptLock.Lock');//很简单,不用 try 了// 2015/4/3 13:48:29  还是要的,因为 lock 本身分异常
      //acceptList.Write(Acceptsc);
      haveSocket := acceptList.Read(Acceptsc);
    finally
      acceptLock.UnLock;
    end;

    if haveSocket = False then
    begin
      //Acceptsc := WSAAccept(Listensc, nil, nil, nil, 0);//WSAAccept 如果是线程安全的话,其实可以自己 accept 一下减少 cpu 占用
      Sleep(1);

      Continue;//没有未处理的了
    end;

    //--------------------------------------------------
    try
      iocpClass.threadLock.Lock('TAcceptFastThread.Execute');

      //这个时候 Acceptsc 有可能是已经被关闭了的
      if iocpClass.socketList.GetItem(Acceptsc, tmp) then
      begin
        LogFile('上次的关闭还未完成. ' + IntToStr(Acceptsc));//如果连接太多太快的情况下是可能的,因为被关闭的那个又被重用了
        Continue;
      end;

      //--------------------------------------------------

      //用户事件,如果需要用户会传入一个外部标识
      //不要锁定,里面有锁

      //成功的话才触发连接事件,否则清除全部分配的资源,因为第一个 recv 失败的话可能是不触发 iocp 的事件的,那样就会内存泄漏了
      //不行必须先触发 connect 事件,因为有很多初始化工作要做,如果后面的 recv 出错的话就清理资源
      OuterFlag := 0;//clq // 2015/4/2 13:29:32 这里初始化一下比较好

      if g_IOCP_Synchronize_Event = False then
      begin
        if Assigned(OnConnect_thread) then OnConnect_thread(Acceptsc, OuterFlag);
      end
      else
      begin
        Synchronize_OnConnect_Acceptsc := Acceptsc;
        Synchronize_OnConnect_OuterFlag := OuterFlag;

        LogFile('Synchronize_OnConnect:' + IntToStr(Self.ThreadID));
        Self.Synchronize(Self.Synchronize_OnConnect);
        LogFile('Synchronize_OnConnect end:' + IntToStr(Self.ThreadID));

        //Synchronize_OnConnect_Acceptsc := Acceptsc;//还要将参数传出
        OuterFlag := Synchronize_OnConnect_OuterFlag;//还要将参数传出
      end;

      //如果这时候客户端关闭 socket 的话是不会触发 iocp 事件的,那怎么知道对方关闭了呢?//哦,绑定时会提示失败的

      //--------------------------------------------------

      //创建一个“单句柄数据结构”将Acceptsc套接字绑定。
      PerHandleData := LPPER_HANDLE_DATA (GlobalAlloc(GPTR, sizeof(PER_HANDLE_DATA)));
      if (PerHandleData = nil) then
      begin
        MessageBox(0, '内存用尽', '服务器内部错误', 0);
        exit;
      end;
      PerHandleData.Socket := Acceptsc;
      PerHandleData.OuterFlag := OuterFlag;
      PerHandleData.isFree := 0;//test
      //PerHandleData.isFirst := 1;//第一个包


      //将套接字、完成端口和“单句柄数据结构”三者绑定在一起。
      bindErr := False;
      if (CreateIoCompletionPort(Acceptsc, CompletionPort, DWORD(PerHandleData), 0) = 0) then
      begin
        LogFile('完成端口绑定失败.' + SysErrorMessage(GetLastError()));//"参数不正确" 的时候是重复绑定了一个端口
        //这时候 Acceptsc 是可能已经被关闭了的
        closesocket(Acceptsc);//Continue;

        bindErr := True;

        //MessageBox(0, '完成端口绑定失败', '服务器内部错误', 0);
        //MessageBox(0, PChar('完成端口绑定失败.' + SysErrorMessage(GetLastError())), '服务器内部错误', 0);
        //exit;
      end;


      //开始接收数据
      PerIoData := nil;//重置一下
      re := RecvNewBuf(Acceptsc, OuterFlag, PerIoData);

      if PerIoData = nil
      then Exit;


      //当对方 socket 已关闭时是会发生的,错误为 "Socket Error #10054 Connectionreset by peer." //WSAECONNRESET//这种时候要触发 onclose 事件,否则连接会没清空
      //不过这个错误应该会在 iocp 处反映出来呀//不对,不是所有错误都会在 iocp 处,多数 iocp 程序都是要判断收取和发送是否成功并立即 closesocket 和清除 pre 各个结构的
      //发送时不用做这种判断了,因为目前的这个 iocp 架构是先接收的,并且只有一个发送的 iodata
      // 2013-3-7 15:29:31 目前认为是绑定失败的才需要自己处理,如果成功绑定的 iocp 应当会有反应

      //--------------------------------------------------
      if bindErr = True then
      begin

        //有可能在这里释放以后, iocp 事件又在触发引起 as 错误
        iocpClass.DoClose(Acceptsc, OuterFlag);
        GlobalFree(Integer(PerIoData));
        GlobalFree(Integer(PerHandleData));//不用判断类型,因为这里肯定是接收的


        Continue;
      end;
      //--------------------------------------------------

      if re = False then
      begin

        closesocket(Acceptsc);//先关闭 socket 比较安全,以免再次触发 iocp 事件(似乎还是会触发)
//        iocpClass.socketList.DeleteItem(Acceptsc);//记录//test

        //Inc(iocpClass.Count);//test

        //有可能在这里释放以后, iocp 事件又在触发引起 as 错误
        iocpClass.DoClose(Acceptsc, OuterFlag);
        GlobalFree(Integer(PerIoData));
        GlobalFree(Integer(PerHandleData));//不用判断类型,因为这里肯定是接收的

      end;//if

    finally
      iocpClass.threadLock.UnLock;
    end;


  end;//while

  LogFile('TAcceptFastThread.Execute 已退出.');//记录下,是否异常退出


end;

end.


