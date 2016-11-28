unit uActiveCheck;

//��������Ƿ�����

//{$DEFINE DEBUG_DIS_TRY}//�� try �ĵط��쳣λ���޷�ȷ��,�����ڱ�������Ч

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
  //socket �Ļʱ��ṹ
  PSocketACTime = ^TSocketACTime;
  TSocketACTime = record
    itor:TFastListItem;//������
    so:TSocket;
    dt:TDateTime;
    dt_sec:Int64;//����
    data_index:Integer;//�ڱ��������е�λ��,�� 0 ��ʼ//��Ϊ�е�����ɾ��,������ʵ����Ч��,ֻ��������¼����ʱ������
    debugTag:Int64;

  end;

type
  TActiveCheckObj = class(TObject)
  private
    //threadLock:TThreadLock;//����������,���ڶ��� iocp ���߳�������// 2015/4/28 10:31:21

  public
    //socket �ĸ���ʱ��(���һ���лʱ��)
    acTimeList:TFastHashSocketQueue;
    //data:TList;//���ڿ�����������,������ڱ���//������ TList ,�Ǹ�Ҳ�������ƶ���
    data:TFastList;
    //���Ӳ�����Ͽ��ĳ�ʱֵ
    timeOutSec:Integer;

    constructor Create; //override;
    destructor Destroy; override;

    //--------------------------------------------------
    //���ɶ�����Ҫ��ʱ��ָ��
    function CreateTime(const so:TSocket; const dt:TDateTime):Pointer;
    procedure FreeTime(const p:Pointer);
    function GetTime(const p:Pointer):TDateTime;
    //--------------------------------------------------

    //����һ�� socket �Ļʱ��
    procedure UpdateActiveTime(const so:TSocket);
    procedure StartService;
    //�����߳���,ֱ���� iocp ��ģ�ⶨʱ���¼��б�������
    procedure OnTimer;
    //�ֹ���������
    procedure ClearForMemoeryTest;
  end;


//ֻ��һ������ʱ����������,����ÿ��������һ�������ʵ��
procedure StartCheckActiveSocket;//Ҫ���ȵ������������������ص���
procedure StopCheckActiveSocket;

//����һ�� socket ����������ʱ��
procedure UpdateActiveTime(const so:TSocket);
//������ӵĳ�ʱֵ,��λ��
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


//ʵ�����ǲ��ͷŵ�
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
  then MessageBox(0, '�ڴ�����쳣', '�ڲ�����', 0);//һ���򵥵ĳ����ж�

  pac.debugTag := 1;

  //data.Delete(pac.data_index);//��������ɾ��,��Ϊ��һ��ɾ��������������Ͳ�ͬ��
  data.Delete(PFastListItem(pac));

  //Dispose(p);//����ֱ���ͷ�,Ҫת��Ϊ��ȷ������
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
  data.InitForNew(PFastListItem(pac));//������ new �����Ķ�����û���Լ���ʼ��,����Ҫһ����ʼ���Ĺ���

  pac.so := so;
  pac.dt := dt;
  pac.dt_sec := DateTimeToUnix(dt);

  pac.data_index := data.Count;//ע��,����ɾ����//������

  //--------------------------------------------------
  //������ new �����Ķ�����û���Լ���ʼ��
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

    //��ɾ���ɵ�
    if acTimeList.GetItem(so, p) then
    begin
      acTimeList.DeleteItem(so);
      FreeTime(p);

    end;

    //�ټ����µ�
    p := CreateTime(so, Now);
    acTimeList.SetItem(so, p);



end;

//�����߳���,ֱ���� iocp ��ģ�ⶨʱ���¼��б�������
procedure TActiveCheckObj.OnTimer;
var
  i:Integer;
  pac:PSocketACTime;
  t:Integer;
  //item:PSocketACTime;
  item, next:PFastListItem;
begin

  //����ѭ��Ҳ��������,Ҳ���� try , iocp �ӿ���ȫ��������
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

        //С�� 0 �Է���
        //if (t > 10)or(t < 0) then
        if (t > self.timeOutSec)or(t < 0) then
        begin
          try
          closesocket(pac.so);
          self.acTimeList.DeleteItem(pac.so);
          self.FreeTime(pac);//����ͷ��ڴ���,Ҫ�������
          except
            MessageBox(0, PChar(IntToStr(self.data.Count)), '', 0);
          end;
        end;

        item := next;//acObj.data.GetNext(item);
        Inc(i);
      end;



  end;


  //Ҳ��Ҫ sleep//Sleep(3 * 1000);//3 ����һ��,����̫�ܼ�


end;

//�ֹ���������//��Ҫ�� iocp ����
procedure TActiveCheckObj.ClearForMemoeryTest;
var
  i:Integer;
  pac:PSocketACTime;
  t:Integer;
  //item:PSocketACTime;
  item, next:PFastListItem;
begin

      //����,��������,��Ҫ���ӿ�,�ڵ���ʱ iocp ��������//Self.threadLock.Lock('TThreadActiveCheck.Execute');

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
//��ʱ���ر�,�����Ƿ��� socket �Լ�������          closesocket(pac.so);
          self.acTimeList.DeleteItem(pac.so);
          self.FreeTime(pac);//����ͷ��ڴ���,Ҫ�������
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

//ֻ��һ������ʱ����������,����ÿ��������һ�������ʵ��
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

//ֻ��һ������ʱ����������,����ÿ��������һ�������ʵ��
procedure UpdateActiveTime(const so:TSocket);
begin
  //Exit;
  GActiveCheckObj.UpdateActiveTime(so);  //ll �ϵ����쳣,ȥ�� try ����

end;

//������ӵĳ�ʱֵ,��λ��
procedure SetActiveTimeOut(const timeOutSec:Integer);
begin
  //Exit;
  GActiveCheckObj.timeOutSec := timeOutSec;
  
end;


end.




