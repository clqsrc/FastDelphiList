unit uHashList;

(*
1.根据 java hashmap 和 hashtable 实现分析的说法是,初始长度大小应当是超过 0.75 使用率后按双倍增长
  出于性能的考虑这里可以做得简单点,初始指定大小后就不变了.
2.长度为大于 16 并按 2 倍扩展.

*)
(*
1.对于 socket 来说,容量为最大个数 4 倍,基本上冲突为 0 ,所以不必拘泥于 java 的 0.75 比例,直接 4倍好了(大约是 0.25)
*)

interface

uses
  Math, SysUtils, Windows, Forms,
  uLinkList, uLinkListFun,
  Dialogs;

//底层实现使用结构体不用类,提供更高的灵活性
type
  PHashItem = ^THashItem;
  THashItem = record
    key:Integer;
    key_len:Integer;//如果关键字不是整数,还要保存它们的原始值,这时 key 就是指针值,而 key_len 就是指针内数据的长度
    value:Integer;
    is_set:Byte;//使用了为 1, 0 为未使用的单元格
    overlayCount:Integer;//test 用于测试同一个 hash 格子上的重复次数
    //nextIndex:Integer//test 冲突时候的下一个元素在备份缓冲中的位置,这样就不用实现易错的双向链表了,而且也不用分配内存,性能提高
    //mlist:PLinkNode;//冲突元素或者重复元素的链表
    mlist:TLinkListRec;//冲突元素或者重复元素的链表
  end;

  THashList = record
    //关键字的类型, 0 为整数, 1 为字符串, 2 为浮点数
    key_type:Integer;
    //元素个数
    count:Integer;
    //元素列表
    list:array of THashItem;
    //冲突时的备份缓冲
    list_bak:array of THashItem;
    //容器大小
    //Capacity//delphi 下不用了,动态数组有长度
    Capacity:Integer;//为了方便字符串键原始数值的处理 list 的总长度为 Capacity 的两倍, hash 计算使用 Capacity 而不是 list 的总长度
    //即 list 的前半部分为正常数据,后半部分为冲突数组,因为二者的长度都保证大于 count 所以是可以安全使用的
    //不好,如果是在此基础上扩展的类,要移动元素是很慢的//取出的 pos 大于等于 Capacity 的时候算是到备份冲突缓冲好了
  end;

  //与 THashList 一样,只是多了保留字符串关键字原始值的地方
  TStrHashList = record
    hashList:THashList;
    key_str:array of string;//字符串的原始值必须保存
    //value_str:array of string;//字符串的原始值必须保存
    //冲突时的备份缓冲
    key_str_bak:array of THashItem;

  end;

//返回其数组大小,以便放置对应的字符串原始值的数组也要有这么大
function SetCapacity_HashList(var list:THashList; size:Integer; init:Boolean = True):Integer;
//返回其所在数组中的值,以便放置对应的字符串原始值
function Put_HashList(var list:THashList; const key,value:Integer; key_len:Integer = 0):Integer;
//返回其所在数组中的值,以便放置对应的字符串原始值,以及无结果时为 -1
function Get_HashList(var list:THashList; key:Integer; var value:Integer):Integer;


procedure SetCapacity_StrHashList(var list:TStrHashList; size:Integer; init:Boolean = True);
procedure Put_StrHashList(var list:TStrHashList; const key:string; value:Integer);
function Get_StrHashList(var list:TStrHashList; key:string; var value:Integer):Integer;

//必须初始化 hash 表的类型,因为它们的比较函数肯定是不同的
//procedure Init_HashList(var list:TStrHashList);
procedure Init_IntHashList(var list:THashList);
procedure Init_StrHashList(var list:TStrHashList);

implementation

var
  GOverlayCount:Integer = 0;//test
  //单元格最大冲突数
  GOverlayCount_Max:Integer = 0;

//整数的 hash 算法 1
function hash_int(key:LongWord; Capacity:Integer):Integer;
//function indexFor(h:Integer; length:Integer)
var
  h:LongWord;
  len:Integer;
begin

  //return h & (length-1);

  h := key;

  //h := BKDRHash_Int(socket);//test

  len := Capacity;//MaxHashListSize;//必须是 2 的 n 次方

  //Result := h;//
  Result := h and (len - 1);


end;

//字符串为 hash 向整数的转换
function BKDRHash(const str:string):Integer;overload;
var
  i:Integer;
begin
  Result := 0;

  for i := 1 to Length(str) do
  begin
    Result := Result * 131 + ord(str[i]);//java 里面是 31// 也可以乘以31、131、1313、13131、131313..
    //Result := Result * 31 + ord(str[i]);//java 里面是 31// 也可以乘以31、131、1313、13131、131313..
  end;

  result := result and $7FFFFFFF;//有些算法还有这句,是为了去除符号位?// 2013-12-3 15:39:41 应该是的

  //下面是判断空字符串,似乎也可以让它过,或者多加个参数判断是否处理空字符串
  //if Result = 0
  //then ShowMessage(str);

end;

//字符串为 hash 向整数的转换
function BKDRHash(const str:PAnsiChar; const len:Integer):Integer;overload;
var
  i:Integer;
begin
  Result := 0;

  //for i := 1 to Length(str) do
  for i := 0 to len - 1 do
  begin
    Result := Result * 131 + ord(str[i]);//java 里面是 31// 也可以乘以31、131、1313、13131、131313..
    //Result := Result * 31 + ord(str[i]);//java 里面是 31// 也可以乘以31、131、1313、13131、131313..
  end;

  result := result and $7FFFFFFF;//有些算法还有这句,是为了去除符号位?// 2013-12-3 15:39:41 应该是的

  //下面是判断空字符串,似乎也可以让它过,或者多加个参数判断是否处理空字符串
  //if Result = 0
  //then ShowMessage(str);

end;


//function hash_str(const key:string; Capacity:Integer):Integer;
//var
//  i:Integer;
//begin
//  Result := 0;
//
//  i := BKDRHash(key);
//
//  Result := hash_int(i, Capacity);
//
//  if Result = 0
//  then ShowMessage(key);
//
//end;

//必须初始化 hash 表的类型,因为它们的比较函数肯定是不同的
procedure Init_HashList(var list:THashList);
begin
  list.count := 0;
  list.Capacity := 0;
  list.key_type := 0;
end;

procedure Init_IntHashList(var list:THashList);
begin
  Init_HashList(list);
  list.key_type := 0;
end;

//也可传比较函数之类的,象 C++ 一样
procedure Init_StrHashList(var list:TStrHashList);
begin
  Init_HashList(list.hashList);
  list.hashList.key_type := 1;

end;  


//可以参考 TMemoryStream
function SetCapacity_HashList(var list:THashList; size:Integer; init:Boolean = True):Integer;
var
  i:Integer;
begin

  //奇怪 delphi 下也要初始化这些变量
  if init = True then
  list.count := 0;

  //--------------------------------------------------

  //capacity 必须是 2 的 n 次方

//  for i :=  to  do
//  begin
//
//  end;

  i := Trunc(Log2(size));//先算 2 的对数

  size := Trunc(Power(2, i + 1));//再算 2 的指数

  SetLength(list.list, size);
  SetLength(list.list_bak, size);
  //SetLength(list.list, size * 2);//空间放大两倍,以便放置冲突数据,不过这样的话,扩容的时候就不能简单的 setlength 完事,还要先备份数据


  list.Capacity := size;

  //Result := size * 2;
  Result := size;

end;

function key_comp():Boolean;
begin
  Result := False;
  
end;  

function Put_HashList(var list:THashList; const key,value:Integer{; var old_value:Integer}; key_len:Integer = 0):Integer;
var
  item:THashItem;
  bkitem:PHashItem;//冲突或者重复时的单元格//这时要操作两个单元格
  pos:Integer;
  i:Integer;
  node:PLinkNode;
begin

  if list.key_type = 0
  then pos := hash_int(key, list.Capacity)//整数
  else pos := hash_int(BKDRHash(PAnsiChar(key), key_len), list.Capacity);//字符串

  item := list.list[pos];
  item.overlayCount := item.overlayCount + 1;

  //总数
  if item.overlayCount>1
  then Inc(GOverlayCount);

  //单元格最大冲突数
  if item.overlayCount>GOverlayCount_Max
  then GOverlayCount_Max := item.overlayCount;


  //--------------------------------------------------
  if item.is_set = 1 then//如果当前单元格有数据了那么就当做是冲突或者重复键值的元素
  begin
    //--------------------------------------------------
    //先找到原来的
    if item.mlist.head<>nil then
    begin
      node := item.mlist.head;
      for i := 0 to item.mlist.count-1 do
      begin
        if node = nil then Break;

        bkitem := PHashItem(node.data);
        //if bkitem.key = key then //找到了//不同的关键字类型需要使用不同的比较方法
        if StrComp()
        begin
          {old_value := bkitem.value;}//算了,为了兼容其他接口,性能牺牲点好了
          bkitem.value := value;//找到旧的值就要替换掉,不过要把旧值返回,这样才能让字符串或者其他指针类有机会清空旧值所占的内存
          //如果为了接口简单不返回旧值就需要调用者查找旧值再删除,这样也是可以的,不过很显然性能差了一倍//当然大多数 hashmap 实现都得先删除
        end;

        node := node.next;
      end;
    end;

    //--------------------------------------------------

    //item.next.data := value;
    //AddData_LinkList(item.next.data := value);这样只保存了值
    bkitem := AllocMem(SizeOf(THashItem));//生成一个新节点//从性能的角度来看,生成的单元格不用删除,所以这里还可以从预分配的内存块中取得以加快速度

    bkitem.key := key;
    bkitem.value := value;
    AddData_LinkList(item.mlist, Integer(bkitem));
  end;

  if item.is_set = 0 then//正常的赋值,不过如果替换模式和重复模式下是不同的处理//不过可以只实现重复模式,替换模式在上面加个删除就行了//或者是只实现唯一的,重复模式再加个list的值
  begin
    item.key := key;
    item.value := value;
  end;

  
  item.is_set := 1;
  list.list[pos] := item;
  Inc(list.count);

  //--------------------------------------------------

  Result := pos;
end;

//返回其所在数组中的值,以便放置对应的字符串原始值,以及无结果时为 -1
function Get_HashList(var list:THashList; key:Integer; var value:Integer):Integer;
var
  item:THashItem;
  pos:Integer;
begin
  pos := hash_int(key, list.Capacity);

  item := list.list[pos];

  value := item.value;

  if (item.key = key)and(item.is_set = 1)
  then Result := pos
  else Result := -1;

end;


procedure SetCapacity_StrHashList(var list:TStrHashList; size:Integer; init:Boolean = True);
begin
  size := SetCapacity_HashList(list.hashList, size, init);
  SetLength(list.key_str, size);
  SetLength(list.key_str_bak, size);
  
end;

procedure Put_StrHashList(var list:TStrHashList; const key:string; value:Integer);
var
  i:Integer;
  pos:Integer;
begin

  i := BKDRHash(key);
  pos := Put_HashList(list.hashList, i, value);

  list.key_str[pos] := key;//字符串的原始值必须另外保存,否则生成的 i 冲突时无法处理
  //list.value_str[pos] := value;

end;

function Get_StrHashList(var list:TStrHashList; key:string; var value:Integer):Integer;
var
  i:Integer;
  pos:Integer;
begin
  i := BKDRHash(key);
  pos := Get_HashList(list.hashList, i, value);


  if pos<>-1
  then Result := pos
  else Result := -1;

end;



end.
