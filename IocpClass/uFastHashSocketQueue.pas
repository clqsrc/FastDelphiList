unit uFastHashSocketQueue;

//类似于 uFastQueue ,不过 uFastQueue 只是 FIFO 这个是 hashmap
//虽然想过直接使用 TSocket 作为索引号不过不行,虽然多数 socket 值比较小但有过超过 66000 的 socket 值

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  winsock2_v2,{WinSock,}ComCtrls,Contnrs,
  
  //Contnrs,//TQueue 性能不行
  Dialogs;

const
  MaxSocketListSize = 65536;//必须是 2 的 n 次方,否则 hash 函数达不到高速的意义,具体解释见 hash 理论

type
  //PSocketRecord = ^TSocketRecord;
  TSocketRecord = record
    IsSet:Byte;//是否已经使用了

    key:Integer;//其实就是 socket 本身,也就是数据
    data:Pointer;//Integer;//数据,指向一个外部定义的对象
  end;

type
  PSocketList = ^TSocketList;//^TStringItemList;
  TSocketList = array[0..MaxSocketListSize] of TSocketRecord;



type
  TFastHashSocketQueue = class(TObject)
  private
    FData:PSocketList;//PINT;
    FReadPos:Integer;
    FWritePos:Integer;
    //MaxCount:Integer;
    FCount: Integer;
    FCountBak: Integer;//备份队列中的有效个数

    FBakList:PSocketList;//TList;//冲突时的备用列表,这个是简单的顺序列表

    function CheckIndex(index:integer):Boolean;
    //参数 var 是为了方便测试
    function GetIndex(var socket: TSocket): Integer;

    function SetItemBak(socket: TSocket; data:Pointer): Boolean;
    function DeleteItemBak(socket: TSocket): Boolean;
    function GetItemBak(socket: TSocket; var data:Pointer): Boolean;
  public
    property Count:Integer read FCount;

    constructor Create; //override;
    destructor Destroy; override;

    function SetItem(socket: TSocket; data:Pointer): Boolean;
    function DeleteItem(socket: TSocket): Boolean;
    function GetItem(socket: TSocket; var data:Pointer): Boolean;
  end;

implementation




{ TFastHashSocketQueue }

function TFastHashSocketQueue.CheckIndex(index: integer): Boolean;
begin
  Result := True;
  
  if (index < 0)or(index > MaxSocketListSize-1) then
    Result := False;

end;

//字符串为 hash 向整数的转换
function BKDRHash(const str:string):Integer;
var
  i:Integer;
begin
  Result := 0;

  for i := 1 to Length(str) do
  begin
    Result := Result * 131 + ord(str[i]);//java 里面是 31// 也可以乘以31、131、1313、13131、131313..
  end;

  result := result and $7FFFFFFF;//有些算法还有这句,是为了去除符号位?

end;

//用在整数上看看
function BKDRHash_Int(const Data:Integer):Integer;
var
  i:Integer;
  p:PByte;
begin
  Result := 0;
  p := @data;

  for i := 0 to 3 do
  begin
    Result := Result * 131 + p^;//java 里面是 31// 也可以乘以31、131、1313、13131、131313..
    Inc(p);
  end;

  result := result and $7FFFFFFF;//有些算法还有这句,是为了去除符号位?

end;


function TFastHashSocketQueue.GetIndex(var socket:TSocket):Integer;
//function indexFor(h:Integer; length:Integer)
var
  h:Integer;
  len:Integer;
begin
  //return h & (length-1);

  h := socket;
  //h := BKDRHash_Int(socket);//test

  len := MaxSocketListSize;//必须是 2 的 n 次方

  //Result := h;//其实这样在目前的 win32 的 socket 环境下也行
  Result := h and (len - 1);

//  Result := 0;//test 测试节点重复使用时
//  socket := 0;//test 测试节点重复使用时
end;


constructor TFastHashSocketQueue.Create();
begin
  inherited Create;

  //FData := GetMemory(MaxCount * SizeOf(Integer));
  //FData := GetMemory(MaxSocketListSize * SizeOf(TSocketRecord));
  FData := AllocMem(MaxSocketListSize * SizeOf(TSocketRecord));//代替 GetMem

  FBakList := AllocMem(MaxSocketListSize * SizeOf(TSocketRecord));//代替 GetMem

//  FReadPos := 0;
//  FWritePos := 0;
  FCount := 0;
  FCountBak := 0;
end;

destructor TFastHashSocketQueue.Destroy;
begin
  FreeMem(FData);
  FreeMem(FBakList);


  inherited;
end;

function TFastHashSocketQueue.GetItem(socket: TSocket; var data:Pointer): Boolean;
var
  index:Integer;
begin
  Result := True;
  index := GetIndex(socket);
  if not CheckIndex(index) then
  begin
    Result := False;
    Exit;
  end;

  if (FData[index].key <> socket) then//hash 冲突
  begin
    if GetItemBak(socket,data) = False then
    begin
      //MessageBox(0, 'hash 冲突', '', 0);//hash 失败,其实是不可能的
      Result := False;
    end;

    Exit;
  end;

  data := FData[index].data;

  if FData[index].IsSet = 0 then
  begin
    Result := False;
    Exit;
  end;


end;

function TFastHashSocketQueue.SetItem(socket: TSocket; data:Pointer): Boolean;
var
  index:Integer;
begin
  Result := True;

  index := GetIndex(socket);
  if not CheckIndex(index) then
  begin
    Result := False;
    Exit;
  end;

  if (FData[index].IsSet = 1) then//hash 冲突
  begin
    if (FData[index].key = socket) then//重复设置了//不允许,这样简单一点
    begin
      MessageBox(0, PChar('重复设置,请先删除原来的值. index=' + inttostr(index) + ' socket=' + inttostr(socket) + ' key=' + inttostr(FData[index].key)), '', 0);//hash 失败,其实是不可能的
      Result := False;
      Exit;
    end;
    
    //冲突了,用备份保存
    if SetItemBak(socket, data) = False then
    begin
      MessageBox(0, PChar('hash 冲突 ' + inttostr(index) + ' socket=' + inttostr(socket) + ' key=' + inttostr(FData[index].key)), '', 0);//hash 失败,其实是不可能的
      Result := False;
    end;

    Exit;
  end;

  FData[index].data := data;
  FData[index].key := socket;
  FData[index].IsSet := 1;

  Inc(FCount);
end;

//其实只是设置一个标志,并不修改
function TFastHashSocketQueue.DeleteItem(socket: TSocket): Boolean;
var
  index:Integer;
  i:Integer;
begin
  Result := True;

  index := GetIndex(socket);
  if not CheckIndex(index) then
  begin
    Result := False;
    Exit;
  end;

  if (FData[index].key <> socket) then//hash 冲突
  begin
    if DeleteItemBak(socket) = False then
    begin
      MessageBox(0, 'hash 冲突', '', 0);//hash 失败,其实是不可能的//是有可能不存在
      Result := False;
    end;

    Exit;
  end;


  FData[index].data := nil;//data;
  FData[index].key := 0;//socket;
  FData[index].IsSet := 0;

  Dec(FCount);
end;


function TFastHashSocketQueue.DeleteItemBak(socket: TSocket): Boolean;
var
  index:Integer;
  i:Integer;
begin
  Result := False;
  for i := 0 to MaxSocketListSize-1 do
  begin
    if FBakList[i].key = socket then
    begin
      FBakList[i].data := nil;//data;
      FBakList[i].key := 0;//socket;
      FBakList[i].IsSet := 0;

      Dec(FCount);
      Dec(FCountBak);

      Result := True;

      Break;
    end;
  end;

end;

function TFastHashSocketQueue.GetItemBak(socket: TSocket;
  var data: Pointer): Boolean;
var
  index:Integer;
  i:Integer;
  setcount:Integer;//已找到有的值的个数
begin
  Result := False;
  setcount := 0;
  
  for i := 0 to MaxSocketListSize-1 do
  begin
    if setcount = FCountBak then Break;//为了速度只找 FCountBak 个有效值
    if FBakList[i].IsSet = 1 then Inc(setcount);

    if (FBakList[i].key = socket) then
    begin
      data := FBakList[i].data;

      Result := True;

      Break;
    end;

  end;

end;

function TFastHashSocketQueue.SetItemBak(socket: TSocket;
  data: Pointer): Boolean;
var
  index:Integer;
  i:Integer;
begin
  Result := False;
  for i := 0 to MaxSocketListSize-1 do
  begin
    if (FBakList[i].IsSet = 0) then//找到第一个空位就填充,不用到队列后面
    begin
      FBakList[i].data := data;
      FBakList[i].key := socket;
      FBakList[i].IsSet := 1;

      Inc(FCount);
      Inc(FCountBak);

      Result := True;

      Break;
    end;
  end;


end;

end.
