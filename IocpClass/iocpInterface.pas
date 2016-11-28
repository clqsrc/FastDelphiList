unit iocpInterface;

//iocp 的单独放在这里
//不要直接使用此单元,请使用 iocpInterfaceClass 中定义的类

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  //winsock2, 
  Winsock2_v2,
  //IdWinSock2,
  //WinSock,

  ComCtrls,Contnrs,
  Dialogs;

type
  TSocket = Cardinal;//u_int;//clq //c 语言原型里的确是无符号的//TSocket 兼容性修正//IdWinSock2 中有误    

const
  DATA_BUFSIZE = 1024;//8192;

type
  //回调函数指针
  //OnRecvProc = procedure (Socket: TSocket; buf:PChar; bufLen:Integer);
  //接收一块完成
  TOnRecvProc = procedure (Socket: TSocket; buf:PChar; bufLen:Integer) of object;
  //发送一块完成//与接收不同的是,这个是全部发送才产生一次事件
  TOnSendProc = procedure (Socket: TSocket) of object;
  //关闭客户端 socket 时
  TOnSocketCloseProc = procedure (Socket: TSocket) of object;

type

  //单IO数据结构

  LPVOID = Pointer;
  LPPER_IO_OPERATION_DATA = ^PER_IO_OPERATION_DATA;

  PER_IO_OPERATION_DATA = packed record

    //--------------------------------------------------
    Overlapped: OVERLAPPED; //固定//iocp需要
    BufInfo: WSABUF; //Buffers:WSABUF;//其实这是一个发送(接收)缓冲的[地址,长度]数组列表,在我们的实现中其实都是1个//DataBuf: WSABUF;        //固定//iocp需要//iocp 内部的数据表示,包括缓冲区和缓冲长度,这个是可以按用户定义在完成一次异步操作后改变的
    //从 api 上看应该叫 Buffers;但我们只有一个所以应该叫 Buffer; 但内容其实指的是缓冲区的信息,所以最好叫 BufInfo
    //其实并不象 OVERLAPPED 一样一定要在这个位置,只是 WSARecv 和 WSASend 需要用到而已,只是为了方便内存管理直接放一块好了 
    //--------------------------------------------------

    //Buffer: array [0..1024] of CHAR;
    Buf: array [0..DATA_BUFSIZE] of AnsiChar;//CHAR;//用户要操作的缓冲区,在这个生存期是不变的
    BufLen: DWORD;//用户要操作的缓冲区长度,在这个生存期是不变的
    //BytesSEND: DWORD;//已完成的多少
    //BytesRECV: DWORD;//已完成的多少// 2015/5/7 9:16:12 没必要用这个,iocp事件里会直接带有当前完成的字节数
    OpCode: Integer;//0 - 表示是接收用的缓冲, 1 - 表示是发送用的缓冲
    Socket: TSocket;//其实 socket 保存在这里在释放时更安全//当然如果不用 socket 作为关键字去标识一个连接而是直接关联到一个指针的话
                    //那还是应该放在 PER_HANDLE_DATA 中并加计数器
    //OuterFlag:Integer;//传出外部连接标志//为兼容原有 iocp 接口,作用类似于线程函数中传递的参数//不用了,直接在外部连接类中保存,与 socket 相关联,可以大大降低复杂度.而且从理论上说已经有 socket 标志了,没有必要再加其他的
    //ExtInfo:Integer;//扩展信息,通常是一个指针
    atWork:Integer; //atSend:Integer; //1 - 正在 iocp 中发送或接收,不要操作
    conFree:Integer; //1 - 所在的连接释放了,要自己释放内存
    debugtag:Integer; //test
    first:Integer;    //test
    TickCount:DWORD; //最后一次发送(接收)时的 GetTickCount//用来判断 iocp 操作超时无事件响应
    //CloseTickCount:Integer; //发现发生关闭事件时的时间
  end;

  //“单句柄数据结构”// 2015/5/7 10:19:01 其实没有必要用这个结构,因为这只是在 GetQueuedCompletionStatus 中取得 CreateIoCompletionPort 时传入的值而已,一般就是用来表明收到的数据是哪一个接口收到的,而这实际上在 PER_IO_OPERATION_DATA 中就可以得到
  {
  //LPPER_HANDLE_DATA = ^ PER_HANDLE_DATA;
  //PER_HANDLE_DATA = packed record
  //  Socket: TSocket;
  //  IsFree : Integer;//确实是需要判断 PER_HANDLE_DATA 是否已经删除了//仅用于测试
  //  //isFirst : Integer;//第一个包,用来减轻 accept 的压力
  //  OuterFlag:Integer;//传出外部连接标志//为兼容原有 iocp 接口,作用类似于线程函数中传递的参数
  //end;
  }
  //改成直接传 socket 好了,简化内存的管理,另外 soket 值理论上有可能超过其接收类型范围,所以只作为一个校验,实际使用还是取数据包(PER_IO_OPERATION_DATA)中带的


  
//完成端口发送
procedure SendBuf(Socket: TSocket; PerIoData : LPPER_IO_OPERATION_DATA);overload;
//完成端口接收
function RecvBuf(Socket: TSocket; PerIoData : LPPER_IO_OPERATION_DATA):Boolean;overload;

procedure SetNonBlock(so:TSocket);
//检查 socket 是否已经关闭,不太准确
function NOTSOCK(so:TSocket):Boolean;
//检查一个 iocp 收或者发 是否完成了//只可用在怀疑断开的连接,否则有可能影响 iocp 事件//只有 WSA_IO_INCOMPLETE 的情况下才需要等待
function CheckPerIoDataComplete(PerIoData : LPPER_IO_OPERATION_DATA):Boolean;
//只是为了调试在哪关闭的
function closesocket(const s: TSocket): Integer; //stdcall;

// 2015/5/11 9:43:43 iocp 的内存分配函数,因为原来的内存分配是 GlobalAlloc/GlobalFree(DWORD(PerIoData)) 这样的形式,不能很好的防止内存泄漏
function IocpAlloc(Bytes: Longint): Pointer;
procedure IocpFree(P: Pointer; lastpos:Integer);
//检查指针是否是 IocpAlloc 相关函数分配的内存
function IocpCheck(P: Pointer):Boolean;

implementation

uses uThreadLock, uMemLeaks, uLogFile;



//只是为了调试在哪关闭的
function closesocket(const s: TSocket): Integer; //stdcall;
begin

  //if NOTSOCK(s) then Exit;
  //Exit;


  Result := Winsock2_v2.closesocket(s);
end;

function IocpAlloc(Bytes: Longint): Pointer;
begin
  //GlobalAlloc(GPTR, sizeof(PER_IO_OPERATION_DATA)

  Result := AllocMem(Bytes);
  //Result := Pointer(GlobalAlloc(GPTR, sizeof(PER_IO_OPERATION_DATA)));//对内存越界写并没有检测能力

  AddMem(Integer(Result));//检测内存,测试用,不要也可以
end;  

//lastpos 的 0,1 有特殊用途,所以要大于等于 2,也不能是负数
procedure IocpFree(P: Pointer; lastpos:Integer);
begin
  //GlobalFree(DWORD(PerIoData)

  DelMem(Integer(p), lastpos);//检测内存,测试用,不要也可以

  FreeMem(p);
  //GlobalFree(DWORD(p));
end;

//检测是否是野指针
function IocpCheck(P: Pointer):Boolean;
begin

  Result := CheckMem(Integer(p));//检测内存,测试用,不要也可以

end;



//完成端口发送
procedure SendBuf(Socket: TSocket; PerIoData : LPPER_IO_OPERATION_DATA);overload;
var
  tmpSendBytes:DWORD;
  Flags:DWORD;
  errno:Integer;
begin

  Flags := 0;
  PerIoData.TickCount := GetTickCount();

  //--------------------------------------------------

  //用此“单IO数据结构”来接受Acceptsc套接字的数据。
  //if (WSARecv(Acceptsc, @(PerIoData.DataBuf), 1, @RecvBytes, @Flags,@(PerIoData.Overlapped), nil) = SOCKET_ERROR) then
  if (WSASend(Socket, @PerIoData.BufInfo, 1{这个应该指的是缓冲结构的个数,固定为1}, tmpSendBytes, Flags, @(PerIoData.Overlapped), nil) = SOCKET_ERROR) then
  begin
    errno := WSAGetLastError();       //WSAENOTSOCK
       
    //WSAEFAULT = 10014 这个应该是 PerIoData 中的数据不对

    //if (WSAGetLastError() <> ERROR_IO_PENDING) then
    if (errno <> ERROR_IO_PENDING) then//出现这个错误必定要销毁对话 socket 和在这里分配的内存
    begin
      PerIoData.atWork := 999; //应该在 closesocket 前面
      //WSAGetOverlappedResult(

      //MessageBox(0, 'b', pchar(IntToStr(errno)), 0);
      closesocket(Socket);//目前的架构下会触发 iocp 事件使释放事件完整,不过以后还是应当自己来处理
//      Winsock2_v2.closesocket(Socket); //奇怪,是这个造成的关闭事件不完整
      //PerIoData.atWork := 999;
      exit;
    end
  end;

  PerIoData.atWork := 1;// 2015/5/11 9:41:41 这时候 iocp 数据才算真的发送出去了,不能再操作了

end;

const
  RecvBuf_Name:array[0..255] of char='RecvBuf'; //记录函数名称,因为 delphi 没有函数名的宏
  
function RecvBuf(Socket: TSocket; PerIoData : LPPER_IO_OPERATION_DATA):Boolean;overload;
var
  tmpRecvBytes:DWORD;
  Flags:DWORD;
  errno:Integer;
  r:Integer;
begin
  Result := False;

  Flags := 0;

  PerIoData.TickCount := GetTickCount();

  PerIoData.debugtag := 3;


  //if (WSARecv(Socket, @PerIoData.BufInfo, 1, tmpRecvBytes, Flags,@(PerIoData.Overlapped), nil) = SOCKET_ERROR) then
  r := WSARecv(Socket, @PerIoData.BufInfo, 1, tmpRecvBytes, Flags,@(PerIoData.Overlapped), nil);
  if (r = SOCKET_ERROR) then
  begin
     errno := WSAGetLastError();       //WSAENOTSOCK
     //if (WSAGetLastError() <> ERROR_IO_PENDING) then
     if (errno <> ERROR_IO_PENDING) then//出现这个错误必定要销毁对话 socket 和在这里分配的内存
     begin
       //MessageBox(0, 'b', '', 0);
       //MessageBox(0, 'b', pchar(IntToStr(errno)), 0);

       //统一和连接一起释放,只要调用都保证关闭 socket 并触发关闭事件就行了
       //目前只有两个地方调用,以后想办法合并成一个
       //IocpFree(PerIoData, Integer(@RecvBuf_Name)); //自己释放更合理//理论上说,这个调用既然失败了就不可能有对应的 iocp 触发,当然 iocp 处校验一下也是可以的//更简单的方式是,每个连接都带有一对收发 periodata 只有三者同时可删除时才删除连接: 连接关闭,不在发送状态,不在接收状态
       //PerIoData := nil;

       result := False;
       exit;
     end
  end;

  if r = 0 then
  begin
    PerIoData.debugtag := 111;
    //MessageBox(0, 'RecvBuf 立即成功?', '', 0);//非常多,这时还会触发事件吗,会的

  end
  else PerIoData.debugtag := 1;

  PerIoData.atWork := 1;// 2015/5/11 9:41:41 这时候 iocp 数据才算真的发送出去了,不能再操作了

  Result := True;// 2015/5/8 8:36:11 默认错误才好做后续的处理

end;

//iocp 可以很好地与非阻塞 socket 共同工作,在 windows 官方文档中即推荐用 iocp 与非阻塞共同完成接收数据以节省物理内存
//function SetNonBlock(so:TSocket):Boolean;
procedure SetNonBlock(so:TSocket);
var
  arg:Integer;
begin
  //Result := True;

  if INVALID_SOCKET = so then Exit;
  
  //首先，设置通讯为非阻塞模式
  arg := 1;
  if SOCKET_ERROR = ioctlsocket(so, FIONBIO, arg) then
  begin
    //
    //if WSAENOTSOCK = WSAGetLastError then Result := False;
  end;  

end;

//重复关闭 socket 在 windows 下会引起严重的问题,解决的方法有两种 1.关闭前先判断 socket 是否存在 2.先查询连接类中是否存在
//本质是利用一个 socket 操作的 WSAENOTSOCK 返回判断 socket 是否存在,即使 socket 存在也不要多次调用或者是关闭到错误的 socket 号
function NOTSOCK(so:TSocket):Boolean;
var
  arg:Integer;
  r:Integer;
begin
  Result := False;

  if INVALID_SOCKET = so then
  begin
    Result := True;

    Exit;
  end;

  //用 SO_CONNECT_TIME 更好
  //首先，设置通讯为非阻塞模式
  arg := 1;
  if SOCKET_ERROR = ioctlsocket(so, FIONBIO, arg) then
  begin
    //
    //if WSAENOTSOCK = WSAGetLastError then Result := True;
    r := WSAGetLastError;
    if WSAENOTSOCK = r
    then Result := True;
  end;

end;

//检查一个 iocp 收或者发 是否完成了//从目前完成端口的实现来看,这个办法是比较准确的,不过应该是只能对已经失去连接的 iocp 进行查询,否则有可能取走数据使正常连接的事件不返回
//特殊情况下对没有响应 iocp 事件的已断开连接进行补刀
function CheckPerIoDataComplete(PerIoData : LPPER_IO_OPERATION_DATA):Boolean;
var
  i:Integer;

  dwTransfer, dwFlags:DWORD;
  err:Integer;

begin  //Result := True; Exit;

  Result := False;

  //--------------------------------------------------
  //取他们的 iocp data 看看是为什么iocp没报告关闭事件//不知为何始终是有,有可能是内存异常引起的?
  //做一个 getsockopt SOCKET_ERROR  WSAGetLastError. WSAENOTSOCK 的检测是可以,但首行要证实这种情况确实存在


  //dwFlags dw2 := 1;

  if FALSE = WSAGetOverlappedResult(PerIoData.Socket,
    @PerIoData.Overlapped, @dwTransfer, False, @dwFlags) then//错误原因
  begin
    err := WSAGetLastError();
    LogFile('CheckPerIoDataComplete :' + IntToStr(err));

    //WSAENOTSOCK
    //996 - WSA_IO_INCOMPLETE 还有没完成的 iocp //发现刚关闭时确实很多 iocp 事件还没完成

    if WSAENOTSOCK = err then
    begin
      //oldConnect.recvHelper.FPerIoData.atWork := 0;//让其能释放

      //从目前来看,如果检测到 socket 已经不存在了,可以判定是完成了,不过如果是其他情况呢

      Result := True;

    end;

    if WSA_IO_INCOMPLETE <> err
    then Result := True;


  end;

end;




//SO_ERROR	  




//接受 socket 是需要线程的
////procedure CreateThreadAccept;
////var
////  hThread:THandle;
////  ThreadID:THandle;
////begin
////
//  end;
//  CloseHandle(hThread);
////
//  delphi 要用 BeginThread 代替 CreateThread
//  BeginThread(nil, 0, @ServerWorkerThread, Pointer(CompletionPort),0, ThreadID);
////
////  IsMultiThread := TRUE;//用这个后也可以用 CreateThread
////  hThread := CreateThread(nil, 0, @CreateServerThread, nil, 0, ThreadID);
////  if (hThread = 0) then
////  begin
////      Exit;
////  end;
////  CloseHandle(hThread);
////
////end;

end.
