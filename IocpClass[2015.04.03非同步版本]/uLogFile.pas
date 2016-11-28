unit uLogFile;

//线程锁

interface


uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  IniFiles,
  Dialogs;

procedure LogFile(s:AnsiString);

implementation

var
  g_logFileName:string;

procedure LogFile(s:AnsiString);
var
  f:TFileStream;
  fn:string;
begin
 //Exit;
  try
    s := DateTimeToStr(now) + '    ' + s + #13#10;
    fn := g_logFileName; // 2015/4/3 8:57:14 //ExtractFilePath(Application.ExeName) + 'log.txt';

    if FileExists(fn) then
      f := TFileStream.Create(fn, fmOpenReadWrite or fmShareDenyNone)
    else
      f := TFileStream.Create(fn, fmCreate or fmShareDenyNone);

    //--------------------------------------------------
    //截断太大的文件
    if ( f.Size > 2*1024*1024 ) then f.Size := 50*1024;
    //if ( f.Size > 2*1024 ) then f.Size := 50;

    //--------------------------------------------------
      

    f.Seek(0, soEnd);
    f.Write((@s[1])^, Length(s));
  except

  end;
  f.Free;
end;

//--------------------------------------------------
initialization
//  threadLock:=TThreadLock.Create(Application);
  g_logFileName := ExtractFilePath(Application.ExeName) + 'log.txt';;


end.
