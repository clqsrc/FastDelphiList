unit fsList;

//fs 前缀为代替原 delphi7 及之前版本数据结构容器的高性能版本

//本文件代替传统 TList,主要改进原类别中删除的问题,原实现是整个移动后面的内存所以容量时速度很慢
//原实现的容量增加时的内存再分配算法已经非常快了,虽然其有再分配动作,但其分配时机的效果不错,当然
//也可以预分配置加速这部分.
//增加删除指针 Item: Pointer 的两个函数实现与 delphi 的 string 实现一样,用前导两个整数来保存其
//原始索引值,因为删除一个节点时肯定其他的节点索引会被改变,所以要有保留索引值的地方.也可以只保留
//索引值,而使用统一分配的单个内存块,那样更安全,不过复杂度上升级太多,加个标志也差不多了.

//原来 uFastList.pas 实现的是传统链表,需要开放出节点的结构体,使用非常的不方便

interface

uses SysUtils, Classes;


type

  //*** 注意与原始的 TList 相比,有删除动作后的列表不再是按元素加入先后顺序的了,因为其删除时移动其他元素的算法不同
  //*** 删除后只有一个元素的索引(在数组中的位置)会被修改,只要同步这个元素的索引值即可认为元素的索引值(在数组中的位置)是不变的,可以当作元素的唯一标识  
  //类似 delphi 的 TThreadList 实现//全部重写 TList 太不合算了也不安全
  TFastList = class(TObject) //class //其实不写后面的 (TObject) 也是一样的
  private
    FList: TList;
    FCount: Integer;
    function Get(Index: Integer): Pointer;
    procedure Put(Index: Integer; const Value: Pointer);

    //增加一个数据结构,注意是内部分配内存的//太复杂,暂不实现
    //procedure Add(Item: Pointer);
    function AddItem(SizeOfItem:Integer):Pointer;

    //删除一个数据结构,注意只能是删除内部分配内存的//太复杂,暂不实现
    procedure RemoveItem(Item: Pointer);
  public
    //Count:Integer;

    constructor Create(Capacity: Integer = 0);
    destructor Destroy; override;
    procedure Clear;
    //收回删除操作后不用的内存,其实就是 TList 的 Capacity property.//大多数情况下没有必要调用它
    procedure FreeMemoryForDelete;


    //传统的增加一个外部指针//也可以象 TList 一样传入一个强制转换为指针的整数值//但不能用 RemoveItem 来删除,只能使用指定索引的 Delete
    //返回值为新元素在数组中的索引(目前和 TList 一样可认为始终是最后一个)
    function Add(Item: Pointer):Integer;

    //传统删除//与 Add 对应//与 TList 的区别是列表中的元素顺序会被打乱,类似于 sort 过的传统 TList
    //返回值为受影响的元素索引//与 TList 的区别是, TList 在插入位置后的元素索引值全部要更新,而这里只会影响一个元素,所以直接返回它的索引号就行了 
    function Delete(Index: Integer):Integer;

    property Count: Integer read FCount;// write SetCount;
    property Items[Index: Integer]: Pointer read Get write Put; default;

  end;

implementation


{ TFastList }

function TFastList.Add(Item: Pointer):Integer;
begin
  inc(FCount);

  //Result := FList.Add(Item); //返回其在数组中的位置// 2015/4/27 16:55:54 不能直接加上后面,因为删除时可能会留有空白
  //Exit; //ll// 测试下 hashmap 的实现及 bug 逻辑

  //可以有如下测试用例:
  //1.加数字 1..10
  //2.删除 第6个 即 list[5],后面的也全部删除
  //3.再加一个 6,即 list[5],这时候打印会发现数字对不上的,因为 FList 并没删除,这时候 6 加到 list[10] 上了
  //4.所以再加 6..20 再全部打印是不会出来 1..20 的

  if FCount>FList.Count //如果容量不够了再加,因为上次删除的可能还有空间
  then FList.Add(Item)
  else FList[FCount - 1] := Item;

  Result := FCount - 1; //所以不论底层窗口如何,这里一定是返回最后一个元素才对

end;

function TFastList.AddItem(SizeOfItem: Integer): Pointer;
begin

end;

procedure TFastList.Clear;
begin
  FList.Clear;
  FCount := 0;
  
end;

constructor TFastList.Create(Capacity: Integer = 0);
begin
  Self.FList := TList.Create;

  FList.Capacity := Capacity;//1024 * 1024;

end;

//procedure TFastList.Delete(Index: Integer);
function TFastList.Delete(Index: Integer):Integer;
begin
  //Dec(FCount);//后面还要用到

  //算法比较简单,即不真正删除,只是将最后一个元素填充到要删除的位置即可
  //FList.Items[index] := FList.Items[FList.Count-1];
  FList.Items[index] := FList.Items[FCount-1];

  //可在 PackMem 时释放多余内存

  Dec(FCount);
  //FList.Count := FCount+1;//test //可用来测试越界情况
  //FList.Capacity := FCount+1;//test //可用来测试越界情况

  Result := Index;//注意,如果删除的是最后一个元素,返回值会超出本容器,虽然不会超出底层容器

  if Index = FCount then Result := -1; //最后一个元素删除的话还是报告说不用处理吧

end;

destructor TFastList.Destroy;
begin
  Self.Clear;
  FList.Clear;
  FList.Free;

  inherited;
end;

procedure TFastList.FreeMemoryForDelete;
begin
  FList.Count := FCount;// 2015/5/12 14:20:50 这个也不能少
  FList.Capacity := FCount; //释放物理内存//按道理说每次都加到最后;每次都移动最后的元素,应该是不会删除还有元素的空间的,不过还未测试
end;

function TFastList.Get(Index: Integer): Pointer;
//resourcestring
const
  SListIndexError = 'TFastList: List index out of bounds (%d) . count: %d [索引超出最后一个元素]';
begin
  if (Index < 0) or (Index >= FCount) then
    raise Exception.CreateFmt(SListIndexError, [index, FCount]);
  

  Result := FList.Items[index];
end;

procedure TFastList.Put(Index: Integer; const Value: Pointer);
begin
  FList.Items[index] := Value;

end;

procedure TFastList.RemoveItem(Item: Pointer);
begin

end;


end.
