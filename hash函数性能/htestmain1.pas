unit htestmain1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Math, WinSock,
  Dialogs, StdCtrls;

type
  TForm1 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    Button4: TButton;
    Button5: TButton;
    procedure FormCreate(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

uses uHashList, uLinkList, uLinkListFun;

{$R *.dfm}


procedure InitSocket();
var
  rWSAData: TWSADATA;
  wSockVer: Word;
begin


  wSockVer := MAKEWORD(2,0);
  if Winsock.WSAStartup( wSockVer, rWSAData ) <> 0 then
  begin
    //Memo.Lines.Add( 'WSAStartUp Failed!' );
    Exit;
  end;


end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  //TMemoryStream

  InitSocket();
  
end;

procedure TForm1.Button4Click(Sender: TObject);
begin
  ShowMessage(IntToStr(Trunc(Log2(2000))))  ;
end;

procedure TForm1.Button1Click(Sender: TObject);
var
  list:THashList;
  i:Integer;
begin

  Init_IntHashList(list);
  SetCapacity_HashList(list, 80000);//只占大约 2m 内存


  //for i := 0 to 20000 do
  for i := -1000 to 2000 do
  begin
    Put_HashList(list, i, i); //这个的散布很好,密集生成的情况下只需要容量是最大个数就行了

//    Put_HashList(list, socket(AF_INET, SOCK_STREAM, IPPROTO_IP), i);//如果是密集生成 socket 的话散布也很好,不过容量得是最大个数的4倍,这时冲突基本为 0 !

  end;

  SetLength(list.list, 0);

end;

procedure TForm1.Button3Click(Sender: TObject);

type
  TStringRecTest = record
    str:string;
    i:Integer;
  end;

var
  list:TStrHashList;
  i:Integer;
  str:string;
  str2:TStringRecTest;
  vi:Integer;
begin

  FillChar(str2, SizeOf(str2), 0);
  ShowMessage(str2.str);

  Init_StrHashList(list);
  SetCapacity_StrHashList(list, 40000);


  for i := 0 to 10000 do
  //for i := -1000 to 2000 do
  begin
    //str := IntToStr(i);//这个 2 倍容量的时候就很好

    str := {str + }IntToStr(i);//这个 4 倍容量的时候也不太好,冲突只是从 500 多变为 200 多,扩容的意义不大,可能是字符串 hash 函数的原因
    //10000 的话要有 16 倍的才好,不过内存占用很小,所以开大一点容量也不要紧

    Put_StrHashList(list, str, i);
    //Break;
  end;

  if Get_StrHashList(list, '10000', vi)<>-1
  then ShowMessage(IntToStr(vi));

end;

procedure TForm1.Button5Click(Sender: TObject);
var
  head, node:PLinkNode;
begin
  head := nil;//成员变量才会初始化,局部变量不会的//全局变量也会
//  node := AllocMem(SizeOf(TLinkNode));

//  Add_LinkList(head, node);
  node := AddData_LinkList(head, 3);
  AddData_LinkList(head, 3);//有意制造的意外

  ShowMessage(IntToStr(head.data));
  FreeNode_LinkList(head, node);

end;

end.
