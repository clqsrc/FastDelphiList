
unit fsHashMap;

//带遍历的 hash 整数 key 列表//基本上等同于传统 C++ 意义上的 hashmap,但由于象 multimap 一样允许多键值,所以插入前应当判断是否有相同的键了
//从传统意义的 hashmap 来说应当是自己判断重复的,不过为了兼容 delphi 原来的 TStringHash 还是这样好了,而且尽量地少修改原算法代码

{$R-,T-,H+,X+}
//Range Checking                    {$R}
//Typed @ Operator                  {$T}
//Huge Strings                      {$H}
//Extended Syntax                   {$X}

interface

uses SysUtils, Classes, fsList, fsIntegerHashList, IniFiles;

type
  THashMap = TIntegerHashList;

  //其实这个函数加上 TIntegerHashList 就可以不要 string2integer 的 hash 实现了,只要在取值前算一下 hash 值就可以了
  //严格来说还是不行,因为 string hash 后会有冲突的
  function HashOf(const Key: string): Cardinal;

  //--------------------------------------------------
  //删除用的方便性函数//因为不能直接在 for 的时候删除
  type IntArr = array of Integer;
  procedure SetMax(var arr:IntArr; MaxLength: Integer);
  procedure Add(arr:IntArr; value:Integer);
  function Count(arr:IntArr):Integer;


implementation

function HashOf(const Key: string): Cardinal;
//来自 function TStringHash.HashOf(const Key: string): Cardinal;
var
  I: Integer;
begin
  Result := 0;
  for I := 1 to Length(Key) do
    Result := ((Result shl 2) or (Result shr (SizeOf(Result) * 8 - 2))) xor
      Ord(Key[I]);
end;

//--------------------------------------------------
//删除用的方便性函数//因为不能直接在 for 的时候删除

{$R+} //Range Checking 有动态数组的地方最好校验一下//不过 IniFiles.pas 中是关闭的,估计是影响性能 

procedure SetMax(var arr:IntArr; MaxLength: Integer);
begin
  SetLength(arr, MaxLength+1);//最后一个元素用来存个数
end;

procedure Add(arr:IntArr; value:Integer);
var
  count:Integer;
begin
  count := arr[Length(arr)-1];//最后一个元素用来存个数
  Inc(count);

  arr[count-1] := value;

  arr[Length(arr)-1] := count;//最后一个元素用来存个数

end;

function Count(arr:IntArr):Integer;
var
  count:Integer;
begin
  count := arr[Length(arr)-1];//最后一个元素用来存个数

  result := count;
end;

{$R-} //Range Checking

//-------------------------------------------------- 

end.
