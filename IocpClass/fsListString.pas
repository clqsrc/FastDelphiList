unit fsListString;

//fs 前缀为代替原 delphi7 及之前版本数据结构容器的高性能版本

//与 fsList 一样的算法,移动最后一个元素,但元素直接是 string

interface

uses SysUtils, Classes;


type

  TFastListString = class(TObject) //class //其实不写后面的 (TObject) 也是一样的
  private
    FList: array of string;//TList;
    FCount: Integer;
    FCapacity: Integer;
    function Get(Index: Integer): string;
    procedure Put(Index: Integer; const Value: string);

    //增加一个数据结构,注意是内部分配内存的//太复杂,暂不实现
    //procedure Add(Item: Pointer);
    function AddItem(SizeOfItem:Integer):Pointer;

    //删除一个数据结构,注意只能是删除内部分配内存的//太复杂,暂不实现
    procedure RemoveItem(Item: Pointer);

    //来自 procedure TList.Grow; 原算法很高效,可以直接用
    procedure Grow;
  public
    //Count:Integer;

    constructor Create(Capacity: Integer = 0);
    destructor Destroy; override;
    procedure Clear;
    //收回删除操作后不用的内存,其实就是 TList 的 Capacity property.//大多数情况下没有必要调用它
    procedure FreeMemoryForDelete;


    //传统的增加一个外部指针//也可以象 TList 一样传入一个强制转换为指针的整数值//但不能用 RemoveItem 来删除,只能使用指定索引的 Delete
    //返回值为新元素在数组中的索引(目前和 TList 一样可认为始终是最后一个)
    function Add(const Item: string):Integer;

    //传统删除//与 Add 对应//与 TList 的区别是列表中的元素顺序会被打乱,类似于 sort 过的传统 TList
    //返回值为受影响的元素索引//与 TList 的区别是, TList 在插入位置后的元素索引值全部要更新,而这里只会影响一个元素,所以直接返回它的索引号就行了 
    function Delete(Index: Integer):Integer;

    property Count: Integer read FCount;// write SetCount;
    property Items[Index: Integer]: string read Get write Put; default;

  end;

implementation


{ TFastListString }

function TFastListString.Add(const Item: string):Integer;
begin
  inc(FCount);

  //Result := FList.Add(Item); //返回其在数组中的位置// 2015/4/27 16:55:54 不能直接加上后面,因为删除时可能会留有空白
  //Exit; //ll// 测试下 hashmap 的实现及 bug 逻辑

  //可以有如下测试用例:
  //1.加数字 1..10
  //2.删除 第6个 即 list[5],后面的也全部删除
  //3.再加一个 6,即 list[5],这时候打印会发现数字对不上的,因为 FList 并没删除,这时候 6 加到 list[10] 上了
  //4.所以再加 6..20 再全部打印是不会出来 1..20 的

  if FCount>Length(FList) //FList.Count //如果容量不够了再加,因为上次删除的可能还有空间
  then begin Grow; FList[FCount - 1] := Item; end //FList.Add(Item) //来自 procedure TList.Grow; 原算法很高效,可以直接用
  else FList[FCount - 1] := Item;

  Result := FCount - 1; //所以不论底层窗口如何,这里一定是返回最后一个元素才对

end;

//来自 procedure TList.Grow; 原算法很高效,可以直接用
procedure TFastListString.Grow;
var
  Delta: Integer;
begin
  if FCapacity > 64 then
    Delta := FCapacity div 4
  else
    if FCapacity > 8 then
      Delta := 16
    else
      Delta := 4;

  //SetCapacity(FCapacity + Delta);
  FCapacity := FCapacity + Delta;
  SetLength(FList, FCapacity);
end;

function TFastListString.AddItem(SizeOfItem: Integer): Pointer;
begin

end;

procedure TFastListString.Clear;
begin
  SetLength(FList, 0);//FList.Clear;
  FCapacity := 0;
  FCount := 0;
  
end;

constructor TFastListString.Create(Capacity: Integer = 0);
begin
  //Self.FList := TList.Create;

  FCapacity := Capacity;//1024 * 1024;
  SetLength(FList, FCapacity);

end;

function TFastListString.Delete(Index: Integer):Integer;
begin
  //Dec(FCount);//后面还要用到

  //算法比较简单,即不真正删除,只是将最后一个元素填充到要删除的位置即可
  FList[index] := FList[FCount-1];

  //可在 PackMem 时释放多余内存

  Dec(FCount);
  //FList.Count := FCount+1;//test //可用来测试越界情况
  //FList.Capacity := FCount+1;//test //可用来测试越界情况

  Result := Index;//注意,如果删除的是最后一个元素,返回值会超出本容器,虽然不会超出底层容器

  if Index = FCount then Result := -1; //最后一个元素删除的话还是报告说不用处理吧

end;

destructor TFastListString.Destroy;
begin
  Self.Clear;
  //FList.Clear;
  //FList.Free;

  inherited;
end;

procedure TFastListString.FreeMemoryForDelete;
begin
  SetLength(FList, FCount); //FList.Count := FCount;// 2015/5/12 14:20:50 这个也不能少
  FCapacity := FCount; //释放物理内存//按道理说每次都加到最后;每次都移动最后的元素,应该是不会删除还有元素的空间的,不过还未测试
end;

function TFastListString.Get(Index: Integer): string;
//resourcestring
const
  SListIndexError = 'TFastListString: List index out of bounds (%d) . count: %d [索引超出最后一个元素]';
begin
  if (Index < 0) or (Index >= FCount) then
    raise Exception.CreateFmt(SListIndexError, [index, FCount]);


  Result := FList[index];
end;

procedure TFastListString.Put(Index: Integer; const Value: string);
begin
  FList[index] := Value;

end;

procedure TFastListString.RemoveItem(Item: Pointer);
begin

end;


end.
