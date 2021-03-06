unit uActiveCheck;

//检测连接是否活动的类

//{$DEFINE DEBUG_DIS_TRY}//有 try 的地方异常位置无法确定,不过在本例中无效

interface
uses
  IniFiles, SysUtils, DateUtils, Windows, Forms,
  //uFastHashedStringList,
  uThreadLock,
  //uFastHashSocketQueue,
  uFastHashSocketQueue_v2,
  uFastList, iocpInterfaceClass,
  //winsock2,{WinSock,}
  Classes;

type
  //socket 的活动时间结构
  PSocketACTime = ^TSocketACTime;
  TSocketACTime = record
    itor:TFastListItem;//迭代器
    so:TSocket;
    dt:TDateTime;
    dt_sec:Int64;//秒数
    data_index:Integer;//在遍历数组中的位置,从 0 开始//因为有单个的删除,所以其实是无效的,只能用来记录添加时的总数
    debugTag:Int64;

  end;

type
  TActiveCheckObj = class(TObject)
  private
    //threadLock:TThreadLock;//不用锁定了,现在都在 iocp 中线程锁定了// 2015/4/28 10:31:21

  public
    //socket 的更新时间(最近一次有活动时间)
    acTimeList:TFastHashSocketQueue;
    //data:TList;//用于快速索引访问,这个用于遍历//不能用 TList ,那个也是整体移动的
    data:TFastList;
    //连接不活动被断开的超时值
    timeOutSec:Integer;

    constructor Create; //override;
    destructor Destroy; override;

    //--------------------------------------------------
    //生成队列需要的时间指针
    function CreateTime(const so:TSocket; const dt:TDateTime):Pointer;
    procedure FreeTime(const p:Pointer);
    function GetTime(const p:Pointer):TDateTime;
    //--------------------------------------------------

    //更新一个 socket 的活动时间
    procedure UpdateActiveTime(const so:TSocket);
    procedure StartService;
    //不开线程了,直接在 iocp 的模拟定时器事件中遍历就行
    procedure OnTimer;
    //手工清理测试
    procedure ClearForMemoeryTest;
  end;


//只有一个监听时可以这样用,否则每个监听带一个这个类实例
procedure StartCheckActiveSocket;//要首先调用这个函数来生成相关的类
procedure StopCheckActiveSocket;

//更新一个 socket 的最新流动时间
procedure UpdateActiveTime(const so:TSocket);
//不活动连接的超时值,单位秒
procedure SetActiveTimeOut(const timeOutSec:Integer);

var
  GActiveCheckObj:TActiveCheckObj;

implementation



{ TActiveCheck }

constructor TActiveCheckObj.Create;
begin
  acTimeList := TFastHashSocketQueue.Create;
  //data := TList.Create;
  data := TFastList.Create;

  timeOutSec := 10;
end;


//实际上是不释放的
destructor TActiveCheckObj.Destroy;
begin
  data.Free;
  acTimeList.Free;
  
  inherited;
end;

procedure TActiveCheckObj.FreeTime(const p: Pointer);
var
  pac:PSocketACTime;
begin
  pac := p;

  if pac.debugTag<>0
  then MessageBox(0, '内存访问异常', '内部错误', 0);//一个简单的出错判断

  pac.debugTag := 1;

  //data.Delete(pac.data_index);//不能这样删除,因为第一次删除后各个的索引就不同了
  data.Delete(PFastListItem(pac));

  //Dispose(p);//不能直接释放,要转换为正确的类型
  Dispose(pac);
  
end;

function TActiveCheckObj.CreateTime(const so:TSocket; const dt: TDateTime): Pointer;
var
  pac:PSocketACTime;
begin
  //Result := Pointer(DateTimeToUnix(dt));
  //Result := AllocMem(SizeOf(TSocketACTime))
  Result := nil;
  new(pac);
  data.InitForNew(PFastListItem(pac));//有问题 new 出来的东西并没有自己初始化,所以要一个初始化的过程

  pac.so := so;
  pac.dt := dt;
  pac.dt_sec := DateTimeToUnix(dt);

  pac.data_index := data.Count;//注意,用来删除的//不用了

  //--------------------------------------------------
  //有问题 new 出来的东西并没有自己初始化
  pac.debugTag := 0;
  //pac.itor.l := nil;
  //pac.itor.r := nil;
  //pac.itor.data := nil;
  //pac.itor.delete := 0;

  //--------------------------------------------------
  data.Add(PFastListItem(pac));

  Result := pac;

end;


function TActiveCheckObj.GetTime(const p: Pointer): TDateTime;
var
  i:Int64;
begin
  i := Int64(p);
  Result := UnixToDateTime(i);

end;

procedure TActiveCheckObj.UpdateActiveTime(const so: TSocket);
var
  p:Pointer;
begin

    //先删除旧的
    if acTimeList.GetItem(so, p) then
    begin
      acTimeList.DeleteItem(so);
      FreeTime(p);

    end;

    //再加入新的
    p := CreateTime(so, Now);
    acTimeList.SetItem(so, p);



end;

//不开线程了,直接在 iocp 的模拟定时器事件中遍历就行
procedure TActiveCheckObj.OnTimer;
var
  i:Integer;
  pac:PSocketACTime;
  t:Integer;
  //item:PSocketACTime;
  item, next:PFastListItem;
begin

  //不用循环也不用锁定,也不用 try , iocp 接口中全部做好了
  //while (Self.Terminated = False)and(Application <>nil)and(Application.Terminated = False) do
  begin
  //  try
      //acObj.threadLock.Lock('TThreadActiveCheck.Execute');

      item := self.data.GetFirst;

      i := 0;
      //for i := 0 to acObj.data.Count-1 do
      while i<self.data.Count do
      begin
        if item = nil then Break;
        next := self.data.GetNext(item);

        //pac := acObj.data.Items[i];
        pac := PSocketACTime(item);

        t := DateTimeToUnix(now)-pac.dt_sec;

        //小于 0 以防错
        //if (t > 10)or(t < 0) then
        if (t > self.timeOutSec)or(t < 0) then
        begin
          try
          closesocket(pac.so);
          self.acTimeList.DeleteItem(pac.so);
          self.FreeTime(pac);//这个释放内存了,要放在最后
          except
            MessageBox(0, PChar(IntToStr(self.data.Count)), '', 0);
          end;
        end;

        item := next;//acObj.data.GetNext(item);
        Inc(i);
      end;



  end;


  //也不要 sleep//Sleep(3 * 1000);//3 秒检查一次,不能太密集


end;

//手工清理测试//需要先 iocp 锁定
procedure TActiveCheckObj.ClearForMemoeryTest;
var
  i:Integer;
  pac:PSocketACTime;
  t:Integer;
  //item:PSocketACTime;
  item, next:PFastListItem;
begin

      //算了,不锁定了,还要出接口,在调用时 iocp 锁定即可//Self.threadLock.Lock('TThreadActiveCheck.Execute');

      item := self.data.GetFirst;

      i := 0;
      //for i := 0 to acObj.data.Count-1 do
      while i<self.data.Count do
      begin
        if item = nil then Break;
        next := self.data.GetNext(item);

        //pac := acObj.data.Items[i];
        pac := PSocketACTime(item);

        begin
          try
//暂时不关闭,看看是否是 socket 自己有问题          closesocket(pac.so);
          self.acTimeList.DeleteItem(pac.so);
          self.FreeTime(pac);//这个释放内存了,要放在最后
          except
            MessageBox(0, PChar(IntToStr(self.data.Count)), '', 0);
          end;
        end;

        item := next;//acObj.data.GetNext(item);
        Inc(i);
      end;

end;


procedure TActiveCheckObj.StartService;
begin
//  checkThread := TThreadActiveCheck.Create(True);
//  checkThread.acObj := Self;
//
//  checkThread.Resume;

end;

//只有一个监听时可以这样用,否则每个监听带一个这个类实例
procedure StartCheckActiveSocket;
//var
//  GActiveCheckObj:TActiveCheckObj;
begin
  GActiveCheckObj := TActiveCheckObj.Create;
  GActiveCheckObj.StartService;

  //iocpServer.AddOnTimerEvent

end;

procedure StopCheckActiveSocket;
begin
  if GActiveCheckObj=nil then Exit;

//  GActiveCheckObj.checkThread.Terminate;
//  GActiveCheckObj.checkThread.WaitFor;
//  GActiveCheckObj.checkThread.Free;

  GActiveCheckObj.Free;
end;  

//只有一个监听时可以这样用,否则每个监听带一个这个类实例
procedure UpdateActiveTime(const so:TSocket);
begin
  //Exit;
  GActiveCheckObj.UpdateActiveTime(so);  //ll 断点有异常,去掉 try 试试

end;

//不活动连接的超时值,单位秒
procedure SetActiveTimeOut(const timeOutSec:Integer);
begin
  //Exit;
  GActiveCheckObj.timeOutSec := timeOutSec;
  
end;


end.





