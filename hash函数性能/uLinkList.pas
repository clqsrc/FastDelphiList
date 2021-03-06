unit uLinkList;

//参照 umgr2 已经很成功的双向链表的实现

//因为用到了 SysUtils ,会让一些功能无法实现,因此除核心功能外的功能在其他地方实现//例如: uLinkListFun,


interface

//uses
//  Windows;
//尽量不引入其他单元
function MessageBox(hWnd: THandle{HWND}; lpText, lpCaption: PAnsiChar; uType: LongWord{UINT}): Integer; stdcall;


const
  _LINK_LIST_AS_TAG_ : Byte = 111;//一个简单的 AS 访问内存例外校验

type
  PLinkNode = ^TLinkNode;
  TLinkNode = packed record
    data: Integer;//指针也转换成这个,如果是字符串桥接一个结构体好了
    next: PLinkNode;
    prev: PLinkNode;
    _tag:Byte;//必须等于 _LINK_LIST_AS_TAG_,因为这是指针操作,还是校验一下的好
    //count:integer;//简单化,不提供 count 等于操作,由调用结构体实现就行了,这样一个节点也可以表示一个队列
    //所以很显然这是个先进先出的队列,只要记住头指针就行了
  end;

//核心函数就两个  
procedure Add_LinkList(var head:PLinkNode; var node:PLinkNode);
procedure Del_LinkList(var head:PLinkNode; var node:PLinkNode);
//--------------------------------------------------
//下面两个函数涉及内存分配,实际上对高性能程序来说是不用的
//因为用到了 SysUtils ,会让一些功能无法实现,因此除核心功能外的功能在 uLinkListFun 实现
//procedure AddData_LinkList(var head:PLinkNode; data:Integer);
//procedure FreeNode_LinkList(var head:PLinkNode; var node:PLinkNode);


implementation

const
  user32    = 'user32.dll';
  
function MessageBox; external user32 name 'MessageBoxA';

procedure Add_LinkList(var head:PLinkNode; var node:PLinkNode);
begin
  //as 校验标志
  if head<>nil then head._tag := _LINK_LIST_AS_TAG_;
  if node<>nil then node._tag := _LINK_LIST_AS_TAG_;

  //--------------------------------------------------

  //if head = nil then head := node;

  if head<>nil then head.prev := node;
  //head.next 不用变

  //node.prev 不用变
  node.next := head;

  head := node;//加到头上,所以要替换头

end;

procedure Del_LinkList(var head:PLinkNode; var node:PLinkNode);
//var
//  node_old:n
begin
  if node = nil then Exit;

  //--------------------------------------------------
  //as 校验标志//其实这时 messagebox 已经不安全,仅用于测试
  if node._tag <> _LINK_LIST_AS_TAG_ then MessageBox(0, 'LinkList 双向链表指针错误!','error', 0);//System.Error(reAccessViolation);//RaiseException(EXCEPTION_STACK_OVERFLOW, 0, 0, 0);;

  //--------------------------------------------------

  //1. node 的上一个节点
  if node.prev<>nil then
  begin
    //.prev 不用变
    node.prev.next := node.next;
  end;

  //2. node 的下一个节点
  if node.next<>nil then
  begin
    node.next.prev := node.prev;
    //.next 不用变

  end;

  //3. 头节点
  if head<>nil then
  begin
    //.prev 不用变
    //.next 不用变

    //其自身要变
    if head = node  then head := node.next;//如果删除的是头节点,则头向下移一位

  end;

end;





end.
