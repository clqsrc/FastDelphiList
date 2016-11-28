unit uLogMemSta;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls;

//ShortString �������·����ڴ�//������Ҫ��д��־ʱ�ֿ��ڴ�,�����뿴���ڴ��Ƿ����ٷ������
procedure LogFileMem(const s:ShortString);

implementation


var
  g_LogFileHandle:THandle = 0;
  g_LogFileBuf:PAnsiChar = nil;
  g_LogFilePos:PInt64 = nil;
  g_LogFilePos_read:PInt64 = nil;
  g_LogFileLock:TRTLCriticalSection;  //ȫ���ٽ�������

const
  FileLen: integer = 2*1024*1024;

//�����ڴ湲���ļ�//�ѵ�1��int64��Ϊ�ļ��ĳ���,��������ڴ�,Ϊ�����쳣,�ļ����ȹ̶�Ϊ 2m
//��־ֻ��һ��д��,����ֱ�����ڲ���д���Ϳ�����
class function CreateLogFile(const MapName: string{; FileLen: integer = 2*1024*1024}):thandle;

var
  r:thandle;
  p: Pointer;
begin
  //r1:= CreateFileMapping($FFFFFFFF, nil, PAGE_READWRITE, 0, len1, PChar(MapName));
  r := CreateFileMapping(INVALID_HANDLE_VALUE, nil, PAGE_READWRITE, 0, FileLen, PChar(MapName));

  //��Ȼ�ɹ��ˣ�������ȻҪ���Ƿ��Ѿ����������������������Ҫ�رվ����
  if ((r <> 0 )and (GetLastError = ERROR_ALREADY_EXISTS)) then
  begin
    CloseHandle(r);//һ��Ҫ�ر�
    r := 0;
  end;
  result := r;

  InitializeCriticalSection(g_LogFileLock);  //��ʼ��
  //DeleteCriticalSection(g_LogFileLock);   //ɾ��
end;

//�򿪹����ļ���д�뻺��
procedure GetLogFileBuf(const FileHand:THandle);
var
  p:PAnsiChar;
begin
  p := MapViewOfFile(FileHand, FILE_MAP_ALL_ACCESS, 0, 0, 0);
  if p = nil then
  begin
    //ShowMessage('����־�ļ�ʧ��.');
    Exit;
  end;

  g_LogFilePos := PInt64(p);
  g_LogFilePos^ := 0;
  g_LogFileBuf := p + SizeOf(Int64);//ǰ���ǳ���
end;


//ShortString �������·����ڴ�//������Ҫ��д��־ʱ�ֿ��ڴ�,�����뿴���ڴ��Ƿ����ٷ������
procedure LogFileMem(const s:ShortString);
var
  pos:Int64;
begin
  if g_LogFileBuf = nil then
  begin
    //ShowMessage('����־�ļ�ʧ��.');
    Exit;
  end;

  try
    EnterCriticalSection(g_LogFileLock);    //�����ٽ���

    pos := g_LogFilePos^;

    //--------------------------------------------------
    //У���ļ�����
    //��Ϊ�кܶ฽�ӵ��ַ�,�����׶� 100 �ֽں���
    if FileLen < (pos + Length(s) + 100) then pos := 0;

    //--------------------------------------------------

    copymemory(g_LogFileBuf + pos, PAnsiChar(@s[1]), Length(s));

    pos := pos + Length(s);

    g_LogFilePos^ := pos; //�ļ�λ��Ҫд��ȥ

    //--------------------------------------------------
    //Ϊ����鿴,дһ�»س�����
    g_LogFileBuf[pos] := #13;
    Inc(pos);//��λ��
    g_LogFileBuf[pos] := #10;
    Inc(pos);//��λ��

    //--------------------------------------------------
    //��ȫ���дһ�� #0 ��������
    g_LogFileBuf[pos] := #0;
    //Inc(pos);//��λ��//��ȫ���Ų�����λ��

    //--------------------------------------------------
    g_LogFilePos^ := pos; //�ļ�λ��Ҫд��ȥ

  finally
    LeaveCriticalSection(g_LogFileLock);  //�뿪�ٽ���
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

  //����ֵ//��ֵ
  //copymemory(buf1,p1,len1);
  copymemory(buf1, PAnsiChar(p1) + SizeOf(Int64), len1);//����ǰ�� 64 λ�ǳ���

  //showmessage(inttostr(result));
  UnmapViewOfFile(p1);//�����һ��Ҫ�е�
  CloseHandle(r1);
end;




initialization
  //g_LogFileHandle := CreateLogFile('_logfile_');
  //�ڴ��ļ���Ȼ�в����� [\] ���ŵ�����
  g_LogFileHandle := CreateLogFile(StringReplace(ExtractFilePath(Application.ExeName), '\', '_', [rfReplaceAll] ));

  if g_LogFileHandle = 0 then 
  ShowMessage('����־�ļ�ʧ��.�����򽫲�д��������־.');

  GetLogFileBuf(g_LogFileHandle);
  LogFileMem('ttt');
 
finalization


end.