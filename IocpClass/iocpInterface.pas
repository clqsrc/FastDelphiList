unit iocpInterface;

//iocp �ĵ�����������
//��Ҫֱ��ʹ�ô˵�Ԫ,��ʹ�� iocpInterfaceClass �ж������

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
  TSocket = Cardinal;//u_int;//clq //c ����ԭ�����ȷ���޷��ŵ�//TSocket ����������//IdWinSock2 ������    

const
  DATA_BUFSIZE = 1024;//8192;

type
  //�ص�����ָ��
  //OnRecvProc = procedure (Socket: TSocket; buf:PChar; bufLen:Integer);
  //����һ�����
  TOnRecvProc = procedure (Socket: TSocket; buf:PChar; bufLen:Integer) of object;
  //����һ�����//����ղ�ͬ����,�����ȫ�����ͲŲ���һ���¼�
  TOnSendProc = procedure (Socket: TSocket) of object;
  //�رտͻ��� socket ʱ
  TOnSocketCloseProc = procedure (Socket: TSocket) of object;

type

  //��IO���ݽṹ

  LPVOID = Pointer;
  LPPER_IO_OPERATION_DATA = ^PER_IO_OPERATION_DATA;

  PER_IO_OPERATION_DATA = packed record

    //--------------------------------------------------
    Overlapped: OVERLAPPED; //�̶�//iocp��Ҫ
    BufInfo: WSABUF; //Buffers:WSABUF;//��ʵ����һ������(����)�����[��ַ,����]�����б�,�����ǵ�ʵ������ʵ����1��//DataBuf: WSABUF;        //�̶�//iocp��Ҫ//iocp �ڲ������ݱ�ʾ,�����������ͻ��峤��,����ǿ��԰��û����������һ���첽������ı��
    //�� api �Ͽ�Ӧ�ý� Buffers;������ֻ��һ������Ӧ�ý� Buffer; ��������ʵָ���ǻ���������Ϣ,������ý� BufInfo
    //��ʵ������ OVERLAPPED һ��һ��Ҫ�����λ��,ֻ�� WSARecv �� WSASend ��Ҫ�õ�����,ֻ��Ϊ�˷����ڴ����ֱ�ӷ�һ����� 
    //--------------------------------------------------

    //Buffer: array [0..1024] of CHAR;
    Buf: array [0..DATA_BUFSIZE] of AnsiChar;//CHAR;//�û�Ҫ�����Ļ�����,������������ǲ����
    BufLen: DWORD;//�û�Ҫ�����Ļ���������,������������ǲ����
    //BytesSEND: DWORD;//����ɵĶ���
    //BytesRECV: DWORD;//����ɵĶ���// 2015/5/7 9:16:12 û��Ҫ�����,iocp�¼����ֱ�Ӵ��е�ǰ��ɵ��ֽ���
    OpCode: Integer;//0 - ��ʾ�ǽ����õĻ���, 1 - ��ʾ�Ƿ����õĻ���
    Socket: TSocket;//��ʵ socket �������������ͷ�ʱ����ȫ//��Ȼ������� socket ��Ϊ�ؼ���ȥ��ʶһ�����Ӷ���ֱ�ӹ�����һ��ָ��Ļ�
                    //�ǻ���Ӧ�÷��� PER_HANDLE_DATA �в��Ӽ�����
    //OuterFlag:Integer;//�����ⲿ���ӱ�־//Ϊ����ԭ�� iocp �ӿ�,�����������̺߳����д��ݵĲ���//������,ֱ�����ⲿ�������б���,�� socket �����,���Դ�󽵵͸��Ӷ�.���Ҵ�������˵�Ѿ��� socket ��־��,û�б�Ҫ�ټ�������
    //ExtInfo:Integer;//��չ��Ϣ,ͨ����һ��ָ��
    atWork:Integer; //atSend:Integer; //1 - ���� iocp �з��ͻ����,��Ҫ����
    conFree:Integer; //1 - ���ڵ������ͷ���,Ҫ�Լ��ͷ��ڴ�
    debugtag:Integer; //test
    first:Integer;    //test
    TickCount:DWORD; //���һ�η���(����)ʱ�� GetTickCount//�����ж� iocp ������ʱ���¼���Ӧ
    //CloseTickCount:Integer; //���ַ����ر��¼�ʱ��ʱ��
  end;

  //����������ݽṹ��// 2015/5/7 10:19:01 ��ʵû�б�Ҫ������ṹ,��Ϊ��ֻ���� GetQueuedCompletionStatus ��ȡ�� CreateIoCompletionPort ʱ�����ֵ����,һ��������������յ�����������һ���ӿ��յ���,����ʵ������ PER_IO_OPERATION_DATA �оͿ��Եõ�
  {
  //LPPER_HANDLE_DATA = ^ PER_HANDLE_DATA;
  //PER_HANDLE_DATA = packed record
  //  Socket: TSocket;
  //  IsFree : Integer;//ȷʵ����Ҫ�ж� PER_HANDLE_DATA �Ƿ��Ѿ�ɾ����//�����ڲ���
  //  //isFirst : Integer;//��һ����,�������� accept ��ѹ��
  //  OuterFlag:Integer;//�����ⲿ���ӱ�־//Ϊ����ԭ�� iocp �ӿ�,�����������̺߳����д��ݵĲ���
  //end;
  }
  //�ĳ�ֱ�Ӵ� socket ����,���ڴ�Ĺ���,���� soket ֵ�������п��ܳ�����������ͷ�Χ,����ֻ��Ϊһ��У��,ʵ��ʹ�û���ȡ���ݰ�(PER_IO_OPERATION_DATA)�д���


  
//��ɶ˿ڷ���
procedure SendBuf(Socket: TSocket; PerIoData : LPPER_IO_OPERATION_DATA);overload;
//��ɶ˿ڽ���
function RecvBuf(Socket: TSocket; PerIoData : LPPER_IO_OPERATION_DATA):Boolean;overload;

procedure SetNonBlock(so:TSocket);
//��� socket �Ƿ��Ѿ��ر�,��̫׼ȷ
function NOTSOCK(so:TSocket):Boolean;
//���һ�� iocp �ջ��߷� �Ƿ������//ֻ�����ڻ��ɶϿ�������,�����п���Ӱ�� iocp �¼�//ֻ�� WSA_IO_INCOMPLETE ������²���Ҫ�ȴ�
function CheckPerIoDataComplete(PerIoData : LPPER_IO_OPERATION_DATA):Boolean;
//ֻ��Ϊ�˵������Ĺرյ�
function closesocket(const s: TSocket): Integer; //stdcall;

// 2015/5/11 9:43:43 iocp ���ڴ���亯��,��Ϊԭ�����ڴ������ GlobalAlloc/GlobalFree(DWORD(PerIoData)) ��������ʽ,���ܺܺõķ�ֹ�ڴ�й©
function IocpAlloc(Bytes: Longint): Pointer;
procedure IocpFree(P: Pointer; lastpos:Integer);
//���ָ���Ƿ��� IocpAlloc ��غ���������ڴ�
function IocpCheck(P: Pointer):Boolean;

implementation

uses uThreadLock, uMemLeaks, uLogFile;



//ֻ��Ϊ�˵������Ĺرյ�
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
  //Result := Pointer(GlobalAlloc(GPTR, sizeof(PER_IO_OPERATION_DATA)));//���ڴ�Խ��д��û�м������

  AddMem(Integer(Result));//����ڴ�,������,��ҪҲ����
end;  

//lastpos �� 0,1 ��������;,����Ҫ���ڵ��� 2,Ҳ�����Ǹ���
procedure IocpFree(P: Pointer; lastpos:Integer);
begin
  //GlobalFree(DWORD(PerIoData)

  DelMem(Integer(p), lastpos);//����ڴ�,������,��ҪҲ����

  FreeMem(p);
  //GlobalFree(DWORD(p));
end;

//����Ƿ���Ұָ��
function IocpCheck(P: Pointer):Boolean;
begin

  Result := CheckMem(Integer(p));//����ڴ�,������,��ҪҲ����

end;



//��ɶ˿ڷ���
procedure SendBuf(Socket: TSocket; PerIoData : LPPER_IO_OPERATION_DATA);overload;
var
  tmpSendBytes:DWORD;
  Flags:DWORD;
  errno:Integer;
begin

  Flags := 0;
  PerIoData.TickCount := GetTickCount();

  //--------------------------------------------------

  //�ôˡ���IO���ݽṹ��������Acceptsc�׽��ֵ����ݡ�
  //if (WSARecv(Acceptsc, @(PerIoData.DataBuf), 1, @RecvBytes, @Flags,@(PerIoData.Overlapped), nil) = SOCKET_ERROR) then
  if (WSASend(Socket, @PerIoData.BufInfo, 1{���Ӧ��ָ���ǻ���ṹ�ĸ���,�̶�Ϊ1}, tmpSendBytes, Flags, @(PerIoData.Overlapped), nil) = SOCKET_ERROR) then
  begin
    errno := WSAGetLastError();       //WSAENOTSOCK
       
    //WSAEFAULT = 10014 ���Ӧ���� PerIoData �е����ݲ���

    //if (WSAGetLastError() <> ERROR_IO_PENDING) then
    if (errno <> ERROR_IO_PENDING) then//�����������ض�Ҫ���ٶԻ� socket �������������ڴ�
    begin
      PerIoData.atWork := 999; //Ӧ���� closesocket ǰ��
      //WSAGetOverlappedResult(

      //MessageBox(0, 'b', pchar(IntToStr(errno)), 0);
      closesocket(Socket);//Ŀǰ�ļܹ��»ᴥ�� iocp �¼�ʹ�ͷ��¼�����,�����Ժ���Ӧ���Լ�������
//      Winsock2_v2.closesocket(Socket); //���,�������ɵĹر��¼�������
      //PerIoData.atWork := 999;
      exit;
    end
  end;

  PerIoData.atWork := 1;// 2015/5/11 9:41:41 ��ʱ�� iocp ���ݲ�����ķ��ͳ�ȥ��,�����ٲ�����

end;

const
  RecvBuf_Name:array[0..255] of char='RecvBuf'; //��¼��������,��Ϊ delphi û�к������ĺ�
  
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
     if (errno <> ERROR_IO_PENDING) then//�����������ض�Ҫ���ٶԻ� socket �������������ڴ�
     begin
       //MessageBox(0, 'b', '', 0);
       //MessageBox(0, 'b', pchar(IntToStr(errno)), 0);

       //ͳһ������һ���ͷ�,ֻҪ���ö���֤�ر� socket �������ر��¼�������
       //Ŀǰֻ�������ط�����,�Ժ���취�ϲ���һ��
       //IocpFree(PerIoData, Integer(@RecvBuf_Name)); //�Լ��ͷŸ�����//������˵,������ü�Ȼʧ���˾Ͳ������ж�Ӧ�� iocp ����,��Ȼ iocp ��У��һ��Ҳ�ǿ��Ե�//���򵥵ķ�ʽ��,ÿ�����Ӷ�����һ���շ� periodata ֻ������ͬʱ��ɾ��ʱ��ɾ������: ���ӹر�,���ڷ���״̬,���ڽ���״̬
       //PerIoData := nil;

       result := False;
       exit;
     end
  end;

  if r = 0 then
  begin
    PerIoData.debugtag := 111;
    //MessageBox(0, 'RecvBuf �����ɹ�?', '', 0);//�ǳ���,��ʱ���ᴥ���¼���,���

  end
  else PerIoData.debugtag := 1;

  PerIoData.atWork := 1;// 2015/5/11 9:41:41 ��ʱ�� iocp ���ݲ�����ķ��ͳ�ȥ��,�����ٲ�����

  Result := True;// 2015/5/8 8:36:11 Ĭ�ϴ���ź��������Ĵ���

end;

//iocp ���Ժܺõ�������� socket ��ͬ����,�� windows �ٷ��ĵ��м��Ƽ��� iocp ���������ͬ��ɽ��������Խ�ʡ�����ڴ�
//function SetNonBlock(so:TSocket):Boolean;
procedure SetNonBlock(so:TSocket);
var
  arg:Integer;
begin
  //Result := True;

  if INVALID_SOCKET = so then Exit;
  
  //���ȣ�����ͨѶΪ������ģʽ
  arg := 1;
  if SOCKET_ERROR = ioctlsocket(so, FIONBIO, arg) then
  begin
    //
    //if WSAENOTSOCK = WSAGetLastError then Result := False;
  end;  

end;

//�ظ��ر� socket �� windows �»��������ص�����,����ķ��������� 1.�ر�ǰ���ж� socket �Ƿ���� 2.�Ȳ�ѯ���������Ƿ����
//����������һ�� socket ������ WSAENOTSOCK �����ж� socket �Ƿ����,��ʹ socket ����Ҳ��Ҫ��ε��û����ǹرյ������ socket ��
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

  //�� SO_CONNECT_TIME ����
  //���ȣ�����ͨѶΪ������ģʽ
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

//���һ�� iocp �ջ��߷� �Ƿ������//��Ŀǰ��ɶ˿ڵ�ʵ������,����취�ǱȽ�׼ȷ��,����Ӧ����ֻ�ܶ��Ѿ�ʧȥ���ӵ� iocp ���в�ѯ,�����п���ȡ������ʹ�������ӵ��¼�������
//��������¶�û����Ӧ iocp �¼����ѶϿ����ӽ��в���
function CheckPerIoDataComplete(PerIoData : LPPER_IO_OPERATION_DATA):Boolean;
var
  i:Integer;

  dwTransfer, dwFlags:DWORD;
  err:Integer;

begin  //Result := True; Exit;

  Result := False;

  //--------------------------------------------------
  //ȡ���ǵ� iocp data ������Ϊʲôiocpû����ر��¼�//��֪Ϊ��ʼ������,�п������ڴ��쳣�����?
  //��һ�� getsockopt SOCKET_ERROR  WSAGetLastError. WSAENOTSOCK �ļ���ǿ���,������Ҫ֤ʵ�������ȷʵ����


  //dwFlags dw2 := 1;

  if FALSE = WSAGetOverlappedResult(PerIoData.Socket,
    @PerIoData.Overlapped, @dwTransfer, False, @dwFlags) then//����ԭ��
  begin
    err := WSAGetLastError();
    LogFile('CheckPerIoDataComplete :' + IntToStr(err));

    //WSAENOTSOCK
    //996 - WSA_IO_INCOMPLETE ����û��ɵ� iocp //���ָչر�ʱȷʵ�ܶ� iocp �¼���û���

    if WSAENOTSOCK = err then
    begin
      //oldConnect.recvHelper.FPerIoData.atWork := 0;//�������ͷ�

      //��Ŀǰ����,�����⵽ socket �Ѿ���������,�����ж��������,������������������

      Result := True;

    end;

    if WSA_IO_INCOMPLETE <> err
    then Result := True;


  end;

end;




//SO_ERROR	  




//���� socket ����Ҫ�̵߳�
////procedure CreateThreadAccept;
////var
////  hThread:THandle;
////  ThreadID:THandle;
////begin
////
//  end;
//  CloseHandle(hThread);
////
//  delphi Ҫ�� BeginThread ���� CreateThread
//  BeginThread(nil, 0, @ServerWorkerThread, Pointer(CompletionPort),0, ThreadID);
////
////  IsMultiThread := TRUE;//�������Ҳ������ CreateThread
////  hThread := CreateThread(nil, 0, @CreateServerThread, nil, 0, ThreadID);
////  if (hThread = 0) then
////  begin
////      Exit;
////  end;
////  CloseHandle(hThread);
////
////end;

end.