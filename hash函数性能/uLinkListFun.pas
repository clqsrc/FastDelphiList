unit uLinkListFun;

//因为用到了 SysUtils ,会让一些功能无法实现,因此除核心功能外的功能在这里实现//实际上是 uLinkList 的扩展

interface

uses
  SysUtils, uLinkList;

type
  TLinkListRec = record//TLinkList 名称留给类好了
    head:PLinkNode;
    count:Integer;//与直接用 PLinkNode 相比,其实只是为了要 count 来避免危险的 while 循环

  end;


//核心函数就两个  
//procedure Add_LinkList(var head:PLinkNode; var node:PLinkNode);
//procedure Del_LinkList(var head:PLinkNode; var node:PLinkNode);
//--------------------------------------------------
//下面两个函数涉及内存分配,实际上对高性能程序来说是不用的
function AddData_LinkList(var head:PLinkNode; data:Integer):PLinkNode;overload;
procedure FreeNode_LinkList(var head:PLinkNode; var node:PLinkNode);overload;

function AddData_LinkList(var list:TLinkListRec; data:Integer):PLinkNode;overload;
procedure FreeNode_LinkList(var list:TLinkListRec; var node:PLinkNode);overload;

implementation



//--------------------------------------------------
//下面两个函数涉及内存分配,实际上对高性能程序来说是不用的
function AddData_LinkList(var head:PLinkNode; data:Integer):PLinkNode;
var
  node:PLinkNode;
begin
  node := AllocMem(SizeOf(TLinkNode));

  node.data := data;

  Add_LinkList(head, node);

  Result := node;
end;

procedure FreeNode_LinkList(var head:PLinkNode; var node:PLinkNode);
begin
  Del_LinkList(head, node);

  if node = nil then Exit;

  //FreeAndNil(node);//从源码看是针对类的,还是自己写吧

  FreeMem(node);
  node := nil;
end;

function AddData_LinkList(var list:TLinkListRec; data:Integer):PLinkNode;overload;
begin
  Inc(list.count);

  Result := AddData_LinkList(list.head, data);
end;

procedure FreeNode_LinkList(var list:TLinkListRec; var node:PLinkNode);overload;
begin
  Inc(list.count, -1);

  FreeNode_LinkList(list.head, node);
end;  



end.
