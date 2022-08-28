{******************************************************************************}
{                                                                              }
{  Simple player for sounds that use the "Media Control Interface"  aka "MCI"  }
{                                                                              }
{                          Copyright(c) 2022 TikoTako                          }
{                                                                              }
{        https://docs.microsoft.com/en-us/windows/win32/multimedia/mci         }
{                https://github.com/TikoTako/SimpleMCISoundPlayer              }
{                                                                              }
{                   Released under the BSD-3-Clause license:                   }
{     https://github.com/TikoTako/SimpleMCISoundPlayer/blob/master/LICENSE     }
{                                                                              }
{******************************************************************************}

unit SimpleMCISoundPlayerUnit;

interface

uses
  Winapi.Windows, Winapi.MMSystem,
  System.SysUtils, System.Generics.Collections, System.Classes,
  Vcl.Controls;

type
  TCopula = record
    Name: string;
    IsPlaying: bool;
    class operator Initialize(out Dest: TCopula);
  end;

  TCopulaListHelper = class helper for TList<TCopula>
    function IndexOf(wut: string): integer;
  end;

  TSimpleMCISoundPlayer = class(TControl)
  private
    fLastError: Cardinal;
    fFilesOpened: TList<TCopula>;
    function InternalClose(FileName: string; removeFromList: bool = true): bool;
  public
    constructor Create(AOWner: TComponent); override;
    destructor Destroy(); override;
    function Open(FileName: string): bool;
    function Close(FileName: string): bool;
    function Play(FileName: string; doRewind: bool = true; doLoop: bool = false): bool;
    function Rewind { Seek } (FileName: string): bool;
    function Stop(FileName: string): bool;
    procedure StopAll();
    function SetVolume(FileName: string; _volume: integer): bool;
    function GetVolume(FileName: string): integer;
    function CheckIfFileIsOpen(FileName: string): bool;
    function GetErrorStringFromCode(ErrorCode: Cardinal): string;
    //
    property GetLastError: Cardinal read fLastError;
  end;

implementation

{ derp-log }

procedure log(s: string); overload;
begin
  if GetStdHandle(STD_OUTPUT_HANDLE) > 0 then
    writeln(s);
end;

procedure log(s: string; const c: array of const); overload;
begin
  if GetStdHandle(STD_OUTPUT_HANDLE) > 0 then
    writeln(Format(s, c));
end;

{ IfThen }

function IfThen(b: boolean; s1: string; s2: string): string; overload;
begin
  if b then
    Exit(s1);
  Exit(s2);
end;

function IfThen(b: boolean; i1: integer; i2: integer): integer; overload;
begin
  if b then
    Exit(i1);
  Exit(i2);
end;

{ TCopula }

class operator TCopula.Initialize(out Dest: TCopula);
begin
  Dest.IsPlaying := false;
end;

{ TCopulaListHelper }

function TCopulaListHelper.IndexOf(wut: string): integer;
var
  i: integer;
begin
  for i := 0 to Self.Count - 1 do
    if (Self[i].Name = wut) then
      Exit(i);
  result := -1;
end;

{ TSimpleMCISoundPlayer }

function SendCommand(Command: WideString): Cardinal;
begin
  result := mciSendString(PWideChar(Command), nil, 0, 0);
end;

constructor TSimpleMCISoundPlayer.Create(AOWner: TComponent);
begin
  inherited Create(AOWner);
  fFilesOpened := TList<TCopula>.Create();
end;

destructor TSimpleMCISoundPlayer.Destroy();
var
  vCurrentFile: TCopula;
begin
  if fFilesOpened.Count > 0 then
    for vCurrentFile in fFilesOpened do
    begin
      Stop(vCurrentFile.Name);
      InternalClose(vCurrentFile.Name, false);
    end;
  fFilesOpened.Free;
  inherited;
end;

function TSimpleMCISoundPlayer.InternalClose(FileName: string; removeFromList: bool = true): bool;
begin
  fLastError := SendCommand('close ' + FileName);
  if (removeFromList and CheckIfFileIsOpen(FileName)) then
    fFilesOpened.Delete(fFilesOpened.IndexOf(FileName));
  result := fLastError = 0;
  log('TSimpleMCISoundPlayer.InternalClose(%s, %s): %s', [FileName, IfThen(removeFromList, 'true', 'false'), IfThen(result, 'OK', 'Error >' + GetErrorStringFromCode(fLastError))]);
end;

function TSimpleMCISoundPlayer.Open(FileName: string): bool;
var
  vFile: TCopula;
begin
  vFile.Name := ExtractFileName(FileName);
  fLastError := SendCommand('open ' + FileName + ' type mpegvideo alias ' + vFile.Name);
  if (fLastError = 0) then
    fFilesOpened.Add(vFile);
  result := fLastError = 0;
  log('TSimpleMCISoundPlayer.Open(%s): [%s] %s', [FileName, vFile.Name, IfThen(result, 'OK', 'Error >' + GetErrorStringFromCode(fLastError))]);
end;

function TSimpleMCISoundPlayer.Close(FileName: string): bool;
var
  vFileName: string;
begin
  vFileName := ExtractFileName(FileName);
  result := InternalClose(vFileName);
  log('TSimpleMCISoundPlayer.Close(%s) %s', [FileName, IfThen(result, 'OK', 'Error >' + GetErrorStringFromCode(fLastError))]);
end;

function TSimpleMCISoundPlayer.Play(FileName: string; doRewind: bool = true; doLoop: bool = false): bool;
var
  ugo: integer;
begin
  result := false;
  FileName := ExtractFileName(FileName);
  ugo := fFilesOpened.IndexOf(FileName);
  if doRewind then
    Rewind(FileName);
  if ugo > -1 then
  begin
    fLastError := SendCommand('play ' + FileName + IfThen(doLoop, ' repeat', ''));
    result := fLastError = 0;
    fFilesOpened.List[ugo].IsPlaying := result; // ???
  end;
  log('TSimpleMCISoundPlayer.Play(%s) %s', [FileName, IfThen(result, 'OK', 'Error >' + GetErrorStringFromCode(fLastError))]);
end;

function TSimpleMCISoundPlayer.Rewind { Seek } (FileName: string): bool;
begin
  FileName := ExtractFileName(FileName);
  if CheckIfFileIsOpen(FileName) then
    fLastError := SendCommand('seek ' + FileName + ' to start');
  result := fLastError = 0;
  log('TSimpleMCISoundPlayer.Rewind(%s): %s', [FileName, IfThen(result, 'OK', 'Error >' + GetErrorStringFromCode(fLastError))]);
end;

function TSimpleMCISoundPlayer.Stop(FileName: string): bool;
var
  ugo: integer;
begin
  result := false;
  FileName := ExtractFileName(FileName);
  ugo := fFilesOpened.IndexOf(FileName);
  if ugo > -1 then
  begin
    fLastError := SendCommand('stop ' + FileName);
    result := fLastError = 0;
    fFilesOpened.List[ugo].IsPlaying := false; // ???
  end;
  log('TSimpleMCISoundPlayer.Stop(%s): %s', [FileName, IfThen(result, 'OK', 'Error >' + GetErrorStringFromCode(fLastError))]);
end;

procedure TSimpleMCISoundPlayer.StopAll();
var
  vFile: TCopula;
begin
  log('procedure TSimpleMCISoundPlayer.StopAll();');
  for vFile in fFilesOpened do
    if vFile.IsPlaying then
      Stop(vFile.Name);
end;

function TSimpleMCISoundPlayer.SetVolume(FileName: string; _volume: integer): bool;
begin
  FileName := ExtractFileName(FileName);
  if CheckIfFileIsOpen(FileName) then
    fLastError := mciSendString(PWideChar('setaudio ' + FileName + ' volume to ' + IntToStr(_volume)), nil, 0, 0);
  result := fLastError = 0;
  log('TSimpleMCISoundPlayer.SetVolume(%s, %d): %s', [FileName, _volume, IfThen(result, 'OK', 'Error >' + GetErrorStringFromCode(fLastError))]);
end;

function TSimpleMCISoundPlayer.GetVolume(FileName: string): integer;
var
  rS: PWideChar;
begin
  GetMem(rS, 128);
  FileName := ExtractFileName(FileName);
  if CheckIfFileIsOpen(FileName) then
    fLastError := mciSendString(PWideChar('status ' + FileName + ' volume'), rS, 128, 0);
  result := IfThen(fLastError = 0, StrToInt(rS), -1);
  FreeMem(rS, 128);
  log('TSimpleMCISoundPlayer.GetVolume(%s): %s', [FileName, IfThen(result > -1, 'OK', 'Error >' + GetErrorStringFromCode(fLastError))]);
end;

function TSimpleMCISoundPlayer.CheckIfFileIsOpen(FileName: string): bool;
begin
  fLastError := IfThen(fFilesOpened.IndexOf(ExtractFileName(FileName)) < 0, MCIERR_FILE_NOT_FOUND, 0);
  result := fLastError = 0;
end;

function TSimpleMCISoundPlayer.GetErrorStringFromCode(ErrorCode: Cardinal): string;
var
  rS: array [0 .. 1023] of Char;
begin
  if mciGetErrorString(ErrorCode, @rS, 1024) then
    result := string(rS).Trim
  else
    result := 'GetErrorStringFromCode [FAIL]';
  log('TSimpleMCISoundPlayer.GetErrorStringFromCode(%d): %s', [ErrorCode, IfThen(result.StartsWith('GetErrorStringFromCode'), 'Error code unknown !?!!!', 'OK')]);
end;

end.
