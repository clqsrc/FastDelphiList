unit uFastHashedStringList;

//修正 THashedStringList 在插入和 PutObject 时的速度缺陷
//THashedStringList 主要的问题是重写了   ,而插入和 PutObject 等修改内容的操作都会触发这个事件,
//而这个事件是要表明更新索引的,所以每次都更新索引引起了性能的急剧下降

interface
uses
  IniFiles,SysUtils, Classes;

type
  TFastHashedStringListMini = class(THashedStringList)
  private
    FChangeTag:Boolean;
  protected
    procedure Changed; override;

  public
    //因为屏蔽了 Changed ,所以在需要更新索引时一定要调用这个函数
    //procedure SetChangeTag();
    //更新索引
    procedure UpdateIndex();

  end;


//直接来自 TFastHashedString
type
  TFastHashedStringList = class(TStringList)
  private
    FValueHash: TStringHash;
    FNameHash: TStringHash;
    FValueHashValid: Boolean;
    FNameHashValid: Boolean;
    procedure UpdateValueHash;
    procedure UpdateNameHash;
  protected
    //procedure Changed; override;
  public
    FList: PStringItemList;
    destructor Destroy; override;
    function IndexOf(const S: string): Integer; override;
    function IndexOfName(const Name: string): Integer; override;
    procedure PutObject2(Index: Integer; AObject: TObject);//test
    //在为屏蔽了 Changed ,所以在需要更新索引时一定要调用这个函数
    procedure SetChangeTag();
    //更新索引
    procedure UpdateIndex();
  end;

implementation

{ TFastHashedStringList }

//procedure TFastHashedStringList.Changed;
//begin
//  //inherited;
//  //恢复为 procedure TStringList.Changed; 的内容
//
//  //if (FUpdateCount = 0) and Assigned(FOnChange) then
//  //  FOnChange(Self);
//
//  Self.FValueHashValid := True;
//end;

{ THashedStringList }

//procedure THashedStringList.Changed;
//begin
//  inherited Changed;
//  FValueHashValid := False;
//  FNameHashValid := False;
//end;

destructor TFastHashedStringList.Destroy;
begin
  FValueHash.Free;
  FNameHash.Free;
  inherited Destroy;
end;

function TFastHashedStringList.IndexOf(const S: string): Integer;
begin
  UpdateValueHash;
  if not CaseSensitive then
    Result :=  FValueHash.ValueOf(AnsiUpperCase(S))
  else
    Result :=  FValueHash.ValueOf(S);
end;

function TFastHashedStringList.IndexOfName(const Name: string): Integer;
begin
  UpdateNameHash;
  if not CaseSensitive then
    Result := FNameHash.ValueOf(AnsiUpperCase(Name))
  else
    Result := FNameHash.ValueOf(Name);
end;

//--------------------------------------------------
procedure TFastHashedStringList.PutObject2(Index: Integer; AObject: TObject);
begin
//  if (Index < 0) or (Index >= FCount) then Error(@SListIndexError, Index);
//  Changing;
  if FList= nil then
  ReallocMem(FList, 20000 * 2000 * SizeOf(TStringItem));

  FList^[Index].FObject := AObject;
  Changed;//是这一个造成特别的慢//clq
end;
//--------------------------------------------------

procedure TFastHashedStringList.SetChangeTag;
begin
  FValueHashValid := False;
  FNameHashValid := False;
end;

procedure TFastHashedStringList.UpdateIndex;
begin
  SetChangeTag();
  UpdateValueHash;
  UpdateNameHash;
  
end;

procedure TFastHashedStringList.UpdateNameHash;
var
  I: Integer;
  P: Integer;
  Key: string;
begin
  if FNameHashValid then Exit;
  
  if FNameHash = nil then
    FNameHash := TStringHash.Create
  else
    FNameHash.Clear;
  for I := 0 to Count - 1 do
  begin
    Key := Get(I);
    P := AnsiPos('=', Key);
    if P <> 0 then
    begin
      if not CaseSensitive then
        Key := AnsiUpperCase(Copy(Key, 1, P - 1))
      else
        Key := Copy(Key, 1, P - 1);
      FNameHash.Add(Key, I);
    end;
  end;
  FNameHashValid := True;
end;

procedure TFastHashedStringList.UpdateValueHash;
var
  I: Integer;
begin
  if FValueHashValid then Exit;
  
  if FValueHash = nil then
    FValueHash := TStringHash.Create
  else
    FValueHash.Clear;
  for I := 0 to Count - 1 do
    if not CaseSensitive then
      FValueHash.Add(AnsiUpperCase(Self[I]), I)
    else
      FValueHash.Add(Self[I], I);
  FValueHashValid := True;
end;


{ TFastHashedStringListTmp }

procedure TFastHashedStringListMini.Changed;
begin
  //inherited;
  //恢复为 procedure TStringList.Changed; 的内容

  //if (FUpdateCount = 0) and Assigned(FOnChange) then
  //  FOnChange(Self);

  //这样修改不太安全,不过比全部重写要好
  if (UpdateCount = 0) and Assigned(OnChange) then
    OnChange(Self);

  //--------------------------------------------------
  if FChangeTag then inherited;
  FChangeTag := False;

end;

procedure TFastHashedStringListMini.UpdateIndex;
begin
  FChangeTag := True;
  Changed;
end;

end.
