unit uThreadLock;

//线程锁

interface


uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  winsock2,WinSock,ComCtrls,Contnrs,
  IniFiles,
  Dialogs;

{$DEFINE USE_MUTEX}//是否使用互斥量,更可靠,速度慢一点//实际测试速度差异可以忽略不计

type
  TThreadLock = class(TComponent)

  private
    hMutex:THandle;
    hSemaphore:THandle;
    isLocked:Boolean;
    //useMutex:Boolean;//是否使用互斥量,更可靠,速度慢一点

    //用于判断死锁的位置
    debugInfo1:string;
    debugInfo2:string;

    //因为程序退出时会销毁 debugInfo1,debugInfo2 ,所以要判断一下
    isFree:Boolean;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure Lock;overload;
    procedure Lock(const debugInfo:string);overload;

    procedure UnLock;

    //procedure InitLock();

    //仅用于调试死锁原因及位置
    procedure GetDebugInfo(var info1:string; var info2:string; var lock:Boolean);
    //仅用于调试
    function TryLock_Test: Integer;

  end;

//var
//  threadLock:TThreadLock;

implementation

uses uLogFile;

{ TThreadLock }




constructor TThreadLock.Create(AOwner: TComponent);
begin
  inherited;
  isLocked := False;
  isFree := False;

  {$IFDEF USE_MUTEX}
  hMutex:=CreateMutex(nil,false,nil);
  {$ELSE}
  hSemaphore := CreateSemaphore(0, 1, 1, nil);
  {$ENDIF}
end;

destructor TThreadLock.Destroy;
begin
  {$IFDEF USE_MUTEX}
  CloseHandle(hMutex);
  {$ELSE}
  CloseHandle(hSemaphore);
  {$ENDIF}

  isFree := True;

  inherited;
end;

procedure TThreadLock.Lock;
begin
  //在线程中
  //有死锁?
  
  {$IFDEF USE_MUTEX}
  WaitForSingleObject(hMutex, INFINITE);
  {$ELSE}
  WaitForSingleObject(hSemaphore, INFINITE);
  {$ENDIF}

  while(isLocked = true) do
  begin
    //sleep(1000);//其实是死锁了，在linux下是进入不到这里的//windows 下可重入
    sleep(1);

    if isFree then Exit;//其实只是防止程序退出时的异常,不过确实有效    

    {$IFDEF DEBUG_TTHREAD_LOCK}
    LogFile('isLocked = true'); Sleep(60*1000);
    {$ENDIF}
  end;

  isLocked := true;//要在解锁后赋值
end;

procedure TThreadLock.Lock(const debugInfo:string);
var
  r:Integer;
begin
  //在线程中
  //有死锁?

  {$IFDEF USE_MUTEX}

    {$IFDEF DEBUG_TTHREAD_LOCK}
    //if WAIT_TIMEOUT = WaitForSingleObject(hMutex, 0)//IGNORE
    //if WAIT_OBJECT_0 <> WaitForSingleObject(hMutex, 5*1000) then
    r := WaitForSingleObject(hMutex, 50*1000);
    while (WAIT_OBJECT_0 <> r) do
    begin
      LogFile('isLocked = true r:' + IntToStr(r));
      LogFile('Self.debugInfo1: ' + Self.debugInfo1);
      LogFile('Self.debugInfo2: ' + Self.debugInfo2);
      Sleep(60*1000);

    end;
    {$ENDIF}


    WaitForSingleObject(hMutex, INFINITE);

  {$ELSE}
    WaitForSingleObject(hSemaphore, INFINITE);
  {$ENDIF}

  while(isLocked = true) do
  begin
    //sleep(1000);//其实是死锁了，在linux下是进入不到这里的//windows 下可重入
    sleep(1);

    if isFree then Exit;//其实只是防止程序退出时的异常,不过确实有效

    {$IFDEF DEBUG_TTHREAD_LOCK}
    LogFile('isLocked = true'); Sleep(60*1000);
    {$ENDIF}
  end;

  isLocked := true;//要在解锁后赋值

  {$IFDEF DEBUG_TTHREAD_LOCK}
  try
  {$ENDIF}

  debugInfo2 := PChar(debugInfo1);
  debugInfo1 := PChar(debugInfo);

  {$IFDEF DEBUG_TTHREAD_LOCK}
  except
    //如果是用 TThreadLock.Create(Application) 创建的线程锁,在这里会报错,因为这时候的锁已经被 Application 释放了
    LogFile('TThreadLock.Lock 锁已释放.');
    MessageBox(0, '', '', 0);
    MessageBox(0, PChar(debugInfo1), '', 0);
  end;
  {$ENDIF}

end;

function TThreadLock.TryLock_Test:Integer;
begin
  Result := 0;

  Result := WaitForSingleObject(hMutex, 1);

  if Result = WAIT_OBJECT_0 then ReleaseMutex(hMutex);

end;

procedure TThreadLock.GetDebugInfo(var info1:string; var info2:string; var lock:Boolean);
begin
  info1 := PChar(debugInfo1);
  info2 := PChar(debugInfo2);
  lock := isLocked;
  
end;


procedure TThreadLock.UnLock;
begin
  islocked := false;//要在解锁前赋值

  {$IFDEF USE_MUTEX}
  ReleaseMutex(hMutex);
  {$ELSE}
  ReleaseSemaphore(hSemaphore, 1, nil);
  {$ENDIF}
  
end;

//--------------------------------------------------
initialization
//  threadLock:=TThreadLock.Create(Application);

end.
