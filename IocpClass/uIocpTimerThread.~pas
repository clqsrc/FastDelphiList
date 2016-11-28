
//实际使用中发现很多需要使用定时器去访问 iocp 内容的情况,例如定时给大家发心跳,
//这时就需要加锁同步,因此这里封装一个事件使其自动加锁
//这是指高性能状态下的非同步模式,如果同步模式的直接在主窗口中用定时器就行了

//可以加入多个处理事件,注意事件中不能直接操作 gui 控件

unit uIocpTimerThread;

interface


uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  ComCtrls,Contnrs, DateUtils,
  IniFiles, uThreadLock,
  Dialogs;

type
  //定时触发事件
  TOnIocpTimerProc = procedure ({Sender: TObject}) of object;


  //事件列表中的一个
  TIocpTimerProcItem = record
    OnIocpTimerProc:TOnIocpTimerProc;
    //要等待多少毫秒触发一次,和 sleep 的参数是一样的
    Interval: Cardinal;
    //传入的参数
    Sender: TObject;
    //上次运行的毫秒
    lastTime:TDateTime;
    //事件名称,记录一下,便于纠错
    name:string;
  end;

  //模拟的定时器线程
  TIocpTimerThread = class(TThread)
  private
  protected
    OnTimerProcList : array of TIocpTimerProcItem;

    FOnThreadBegin:TOnIocpTimerProc;
    FOnThreadEnd:TOnIocpTimerProc;

    procedure Execute; override;

  public
    iocpClass:TObject; //TIocpClass;
    threadLock:TThreadLock;

    //增加一个定时器处理事件
    procedure AddOnTimerEvent(EventName:string; OnTimer:TOnIocpTimerProc; Interval:Cardinal);

    //CoInitialize, CoUninitialize 这样的函数必须在线程起始,终止时唯一调用,所以要在这两个地方可以执行代码
    procedure SetOnTimerEvent_ThreadFun(OnThreadBegin:TOnIocpTimerProc; OnThreadEnd:TOnIocpTimerProc);

    constructor Create(CreateSuspended: Boolean);
    //destructor Destroy; override;


  end;



implementation

uses uLogFile, iocpInterfaceClass;




{ TIocpTimerThread }

//CoInitialize, CoUninitialize 这样的函数必须在线程起始,终止时唯一调用,所以要在这两个地方可以执行代码
procedure TIocpTimerThread.SetOnTimerEvent_ThreadFun(OnThreadBegin:TOnIocpTimerProc; OnThreadEnd:TOnIocpTimerProc);
begin

  FOnThreadBegin := OnThreadBegin;
  FOnThreadEnd := OnThreadEnd;

end;


//增加一个定时器处理事件
procedure TIocpTimerThread.AddOnTimerEvent(EventName:string; OnTimer:TOnIocpTimerProc; Interval:Cardinal);
var
  item:TIocpTimerProcItem;
  iocpClass:TIocpClass;

begin

  iocpClass := TIocpClass(self.iocpClass);

  try
    if iocpClass.threadLock<>nil then
    iocpClass.threadLock.Lock('TIocpTimerThread.Execute');

    item.name := EventName;
    item.OnIocpTimerProc := OnTimer;
    item.Interval := Interval;

    SetLength(OnTimerProcList, Length(OnTimerProcList) + 1);
    OnTimerProcList[Length(OnTimerProcList) - 1] := item;

  finally
    if iocpClass.threadLock<>nil then
    iocpClass.threadLock.UnLock();
  end;

end;

procedure TIocpTimerThread.Execute;
var
  iocpClass:TIocpClass;
  i:Integer;
  //lastTime:;//上次运行的毫秒
  tnow:TDateTime;
begin
  iocpClass := TIocpClass(self.iocpClass);

  if Assigned(FOnThreadBegin) then FOnThreadBegin(); //线程初始化,如 ole

  while (not Self.Terminated) do
  begin

    try
      iocpClass.threadLock.Lock('TIocpTimerThread.Execute');

      for i := 0 to Length(Self.OnTimerProcList)-1 do
      begin
        tnow := Now;

        //时间差到了就触发
        if Abs(MilliSecondOfTheDay(tnow - OnTimerProcList[i].lastTime)) > OnTimerProcList[i].Interval then
        begin

          {$ifndef EXCEPT_DEBUG}//调试异常的情况下屏蔽
          try
          {$endif}

            if g_IOCP_Synchronize_Event then
              Self.Synchronize(Self.OnTimerProcList[i].OnIocpTimerProc) //UI 同步的话
            else
              Self.OnTimerProcList[i].OnIocpTimerProc();

            //OnTimerProcList[i].lastTime := Now;

          {$ifndef EXCEPT_DEBUG}//调试异常的情况下屏蔽
          except//必须用 except 去掉异常,否则后面的数据接收不响应
            LogFile('error on OnIocpTimerProc 线程定时器名:' + OnTimerProcList[i].name);
          end;
          {$endif}

          OnTimerProcList[i].lastTime := Now;
        end;


      end;


    finally
      iocpClass.threadLock.UnLock();
    end;

    Sleep(10); //太低是不行的,也没有意义
  end;

  if Assigned(FOnThreadEnd) then FOnThreadEnd(); //线程初始化,如 ole


end;


constructor TIocpTimerThread.Create(CreateSuspended: Boolean);
begin
  inherited Create(CreateSuspended);

  FOnThreadBegin := nil;
  FOnThreadEnd := nil;


end;

end.

