unit uLogMemSta;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls;

//ShortString 不会重新分配内存//尽量不要在写日志时又开内存,除非想看看内存是否能再分配出来
procedure LogFileMem(const s:ShortString);

implementation


var
  g_LogFileHandle:THandle = 0;
  g_LogFileBuf:PAnsiChar = nil;
  g_LogFilePos:PInt64 = nil;
  g_LogFilePos_read:PInt64 = nil;
  g_LogFileLock:TRTLCriticalSection;  //全局临界区变量

const
  FileLen: integer = 2*1024*1024;

//创建内存共享文件//把第1个int64作为文件的长度,后面的是内存,为避免异常,文件长度固定为 2m
//日志只有一个写者,所以直接在内部加写锁就可以了
class function CreateLogFile(const MapName: string{; FileLen: integer = 2*1024*1024}):thandle;

var
  r:thandle;
  p: Pointer;
begin
  //r1:= CreateFileMapping($FFFFFFFF, nil, PAGE_READWRITE, 0, len1, PChar(MapName));
  r := CreateFileMapping(INVALID_HANDLE_VALUE, nil, PAGE_READWRITE, 0, FileLen, PChar(MapName));

  //虽然成功了，但是仍然要看是否已经建立过，如果建立过了是要关闭句柄的
  if ((r <> 0 )and (GetLastError = ERROR_ALREADY_EXISTS)) then
  begin
    CloseHandle(r);//一定要关闭
    r := 0;
  end;
  result := r;

  InitializeCriticalSection(g_LogFileLock);  //初始化
  //DeleteCriticalSection(g_LogFileLock);   //删除
end;

//打开共享文件的写入缓冲
procedure GetLogFileBuf(const FileHand:THandle);
var
  p:PAnsiChar;
begin
  p := MapViewOfFile(FileHand, FILE_MAP_ALL_ACCESS, 0, 0, 0);
  if p = nil then
  begin
    //ShowMessage('打开日志文件失败.');
    Exit;
  end;

  g_LogFilePos := PInt64(p);
  g_LogFilePos^ := 0;
  g_LogFileBuf := p + SizeOf(Int64);//前面是长度
end;


//ShortString 不会重新分配内存//尽量不要在写日志时又开内存,除非想看看内存是否能再分配出来
procedure LogFileMem(const s:ShortString);
var
  pos:Int64;
begin
  if g_LogFileBuf = nil then
  begin
    //ShowMessage('打开日志文件失败.');
    Exit;
  end;

  try
    EnterCriticalSection(g_LogFileLock);    //进入临界区

    pos := g_LogFilePos^;

    //--------------------------------------------------
    //校验文件长度
    //因为有很多附加的字符,所以抛多 100 字节好了
    if FileLen < (pos + Length(s) + 100) then pos := 0;

    //--------------------------------------------------

    copymemory(g_LogFileBuf + pos, PAnsiChar(@s[1]), Length(s));

    pos := pos + Length(s);

    g_LogFilePos^ := pos; //文件位置要写回去

    //--------------------------------------------------
    //为方便查看,写一下回车换行
    g_LogFileBuf[pos] := #13;
    Inc(pos);//加位置
    g_LogFileBuf[pos] := #10;
    Inc(pos);//加位置

    //--------------------------------------------------
    //安全起见写一个 #0 结束符号
    g_LogFileBuf[pos] := #0;
    //Inc(pos);//加位置//安全符号不用中位置

    //--------------------------------------------------
    g_LogFilePos^ := pos; //文件位置要写回去

  finally
    LeaveCriticalSection(g_LogFileLock);  //离开临界区
  end;

end;

class procedure get_share_string1(const MapName: string;buf1:pchar;len1:integer);
var
  r1:thandle;
  p1: Pointer;
begin

  r1 := OpenFileMapping(FILE_MAP_ALL_ACCESS, False, PChar(MapName));
  if r1 = 0 then
  begin
    Exit;
  end;

  p1 := MapViewOfFile(r1, FILE_MAP_ALL_ACCESS, 0, 0, 0);
  if p1 = nil then
  begin
    //CloseHandle(r1);
    r1 := 0;
    exit;
  end;

  g_LogFilePos_read := p1;

  //设置值//赋值
  //copymemory(buf1,p1,len1);
  copymemory(buf1, PAnsiChar(p1) + SizeOf(Int64), len1);//现在前面 64 位是长度

  //showmessage(inttostr(result));
  UnmapViewOfFile(p1);//这个是一定要有的
  CloseHandle(r1);
end;




initialization
  //g_LogFileHandle := CreateLogFile('_logfile_');
  //内存文件居然有不能用 [\] 符号的限制
  g_LogFileHandle := CreateLogFile(StringReplace(ExtractFilePath(Application.ExeName), '\', '_', [rfReplaceAll] ));

  if g_LogFileHandle = 0 then 
  ShowMessage('打开日志文件失败.本程序将不写入网络日志.');

  GetLogFileBuf(g_LogFileHandle);
  LogFileMem('ttt');
 
finalization


end.
