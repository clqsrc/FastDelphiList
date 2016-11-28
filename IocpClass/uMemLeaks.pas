
unit uMemLeaks;


//EurekaLog 的 ELeaks.pas 不是很可靠,还是自己检测一下重复释放
//因为粒度很小就直接用 delphi 里喜欢用的 TRTLCriticalSection 实现锁定好了,加强可靠性

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  ComCtrls, Contnrs, fsHashMap,
  uThreadLock,
  Dialogs;


procedure AddMem(mem:Integer);

//lastpos 的 0,1 有特殊用途,所以要大于等于 2,也不能是负数
procedure DelMem(mem:Integer; lastpos:Integer);
//一个简单的检测指针是否合法
function CheckMem(mem:Integer):Boolean;



implementation

uses iocpInterface;

const
  //是否显示最后删除位置,正式发布需要禁用,因为它保存了链表
  //GShowDebugPos:Boolean = True;
  GShowDebugPos:Boolean = False;

var
  GMemList:THashMap;
  GMemLock:TRTLCriticalSection;  //全局临界区变量

//
procedure AddMem(mem:Integer);
begin
  EnterCriticalSection(GMemLock);    //进入临界区
  try
    GMemList.Add(mem, 1);

  finally
    LeaveCriticalSection(GMemLock);  //离开临界区
  end;
end;

//lastpos 的 0,1 有特殊用途,所以要大于等于 2,也不能是负数
procedure DelMem(mem:Integer; lastpos:Integer);
var
  v:Integer;
begin
  EnterCriticalSection(GMemLock);    //进入临界区
  try
    v := GMemList.ValueOf(mem);
    //if GMemList.ValueOf(mem) = -1 then
    if v = -1 then
    begin
      MessageBox(0, '无效指针,可能是重复释放', '', 0);
      Exit;
    end;
    
    if v > 255 then
    begin
      MessageBox(0, PChar('无效指针,可能是重复释放.最后位置:' + pchar(v)), '', 0);
      Exit;
    end;

    if v > 1 then
    begin
      MessageBox(0, PChar('无效指针,可能是重复释放.最后位置:' + inttostr(v)), '', 0);
      Exit;
    end;

    if lastpos <= 1 then
    begin
      MessageBox(0, '最后位置不能小于或等于1', '', 0);
      Exit;
    end;


    //GMemList.Modify(mem, v+1);//如果后面不删除的话可以检测重复释放了多少次
    GMemList.Modify(mem, lastpos);//记录最后释放的位置
    if GShowDebugPos = False then GMemList.Remove(mem);//注释掉这个可以查看重复释放的地方

  finally
    LeaveCriticalSection(GMemLock);  //离开临界区
  end;
end;

//一个简单的检测指针是否合法
function CheckMem(mem:Integer):Boolean;
var
  v:Integer;
begin
  Result := True;
  v := 0;

  EnterCriticalSection(GMemLock);    //进入临界区
  try
    v := GMemList.ValueOf(mem);
    //if GMemList.ValueOf(mem) = -1 then
    if v = -1 then
    begin
      Result := False;
//      MessageBox(0, '无效指针,可能是内存已经破坏.建议重启程序.', '', 0);
//      Exit;
    end;

  finally
    LeaveCriticalSection(GMemLock);  //离开临界区
  end;

  //放到锁定外面来提示
  if v = -1 then
  begin
    MessageBox(0, 'CheckMem: 无效指针,可能是内存已经破坏.建议重启程序.', '', 0);
    Exit;
  end;
  

end;


var
  i:Integer;
  PerIoData:LPPER_IO_OPERATION_DATA;

initialization

  InitializeCriticalSection(GMemLock);  //初始化
  GMemList := THashMap.Create;

finalization
  if DebugHook<>0 then if GMemList.Count>0 then MessageBox(0, '有未释放的内存', 'uMemLeaks.pas', 0);

  //--------------------------------------------------
  //test 只是测试看看是什么样的内存没有清理而已

  for i := 0 to GMemList.Count-1 do
  begin
    PerIoData := LPPER_IO_OPERATION_DATA(GMemList.Keys[i]);
    PerIoData.TickCount := 0;
    //不能这样处理,会把列表数量减少的//IocpFree(PerIoData, 4);//test

    //test 直接检查看看
    if CheckPerIoDataComplete(PerIoData) then
    begin
      IocpFree(PerIoData, 4);//不在 iocp 中的就可以直接释放了

    end;


  end;

  if DebugHook<>0 then if GMemList.Count>0 then MessageBox(0, '有未释放的内存2', 'uMemLeaks.pas', 0);


  //--------------------------------------------------

  if GShowDebugPos = True then MessageBox(0, 'GShowDebugPos 开启时有未释放的内存是正常的,可禁用', 'uMemLeaks.pas', 0);
  GMemList.Free;
  DeleteCriticalSection(GMemLock);   //删除


end.
