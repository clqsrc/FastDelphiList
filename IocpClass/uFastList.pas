unit uFastList;

//delphi �� TList ��һ�η���ȫ���ڴ沢�����ƶ���,�����Ǵ�ͳ�����ϵ�����,�ǲ��ܸ�����ɾ��
//������,���������ǱߵĽ����,�ٶȻ��ܽ���,��Ҫ����������̫��,������ʱ�����滻 TList

interface
uses
  IniFiles, SysUtils, Windows,
  DateUtils,
  Classes;

type
  PFastListItem = ^TFastListItem;
  //��ֹ���������Ĵ���,����ѹ���ĺ���
  TFastListItem = packed record
    l:PFastListItem;
    r:PFastListItem;
    data:Pointer;//Integer;//����,ָ��һ���ⲿ����Ķ���
    delete:Byte;//��־�Ƿ���ɾ������,Ŀǰ�����ڲ����Ƿ��ظ��ͷ���һ���ڵ�
  end;

  TFastList = class(TObject)
  private
    //���׽ڵ�Ϊ������������Ϊ��
    first:PFastListItem;
    //����Ҫ��β�ڵ�,�������������½ڵ�
    last:PFastListItem;
  public
    Count:Integer;

    constructor Create; //override;
    destructor Destroy; override;

    //������ p �������ǿ��ת��Ϊ PFastListItem,���ṹ���
    //procedure Add(const p:Pointer);
    procedure Add(const item:PFastListItem);
    procedure Delete(const item:PFastListItem);
    function GetFirst: PFastListItem;
    function GetNext(const item:PFastListItem):PFastListItem;
    //������ new �����Ķ�����û���Լ���ʼ��,����Ҫһ����ʼ���Ĺ���
    //�¼�һ���ڵ��Ҫ��������
    //procedure OnAfterNewItem();
    procedure InitForNew(var item:PFastListItem);
  end;

implementation


{ TFastList }

procedure TFastList.Add(const item: PFastListItem);
begin
  if item=nil then Exit;

  Count := Count + 1;

  if first=nil then//ͷβͬʱ����
  begin
    first := item;
    last := item;
    Exit;
  end;

  if last=nil then//ͷβͬʱ����
  begin
    first := item;
    last := item;
    Exit;
  end;

  begin
    item.l := last;
    last.r := item;
    last := item;
  end;
end;

constructor TFastList.Create;
begin
  first := nil;
  last := nil;
  Count := 0;

end;

procedure TFastList.Delete(const item: PFastListItem);
begin
  if item=nil then Exit;
  
  //item.delete := 1;
  Inc(item.delete);

  //ֻ��һ���ڵ�����
  if first = last then
  begin
    first := nil;
    last := nil;
    Count := 0;
    Exit;
  end;

  if item = first then
  begin
    if first.r <> nil then first.r.l := nil;
    first := first.r;
    Count := Count -1;
    Exit;
  end;

  if item = last then
  begin
    last := last.l;
    Count := Count -1;
    Exit;
  end;

  //if item.l=nil then Exit;//����������ж�,��������˾����쳣��
  if item.l=nil then
  begin
    MessageBox(0, PChar('�ڵ�ɾ�����ش���![TFastList.Delete] ' + IntToStr(Count) + ' ' + IntToStr(item.delete)) , '', 0);
    Exit;//����������ж�,��������˾����쳣��

  end;

  item.l.r := item.r;
  item.r.l := item.l;
  Count := Count -1;
end;

destructor TFastList.Destroy;
begin

  inherited;
end;

function TFastList.GetNext(const item: PFastListItem): PFastListItem;
begin
  Result := nil;
  if item=nil then Exit;

  Result := item.r;
end;

function TFastList.GetFirst: PFastListItem;
begin
  Result := first;
end;

procedure TFastList.InitForNew(var item: PFastListItem);
begin
  //--------------------------------------------------
  //������ new �����Ķ�����û���Լ���ʼ��
  item.l := nil;
  item.r := nil;
  item.data := nil;
  item.delete := 0;

  //--------------------------------------------------
end;

end.




