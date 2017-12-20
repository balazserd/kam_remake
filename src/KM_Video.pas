unit KM_Video;

{$I KaM_Remake.inc}

interface

{$IFDEF PLAYVIDEO}   {$ENDIF}

{$IFDEF PLAYVIDEO}
uses
  Vcl.MPlayer, Vcl.ExtCtrls, Vcl.Forms, Vcl.Controls, Vcl.Graphics, SysUtils, Classes,
  Windows, Messages, Dialogs;

const
  VIDEOFILE_PATH = 'data\gfx\video\';

type
  TPanelTransparent = class (TPanel)
  private
    procedure CnCtlColorStatic (var Msg: TWMCtlColorStatic); message CN_CTLCOLORSTATIC;
    procedure WmEraseBkgnd (var Msg: TWMEraseBkgnd); message WM_ERASEBKGND;
    procedure Paint; override;
  end;

  TKMVideoPlayerEvent = reference to procedure;

  TKMVideoPlayer = class
  private
    FParentForm: TForm;
    FVideoList: TStringList;
    FEndVideo: TKMVideoPlayerEvent;
    FPanel: TPanelTransparent;
    FMediaPlayer: TMediaPlayer;
    procedure Init;
    procedure Clear;
    procedure PlayNextVideo;
    procedure MediaPlayerNotify(Sender: TObject);
    procedure PanelClick(Sender: TObject);
    function GetIsPlay: Boolean;
  public
    constructor Create(AParentForm: TForm);
    destructor Destroy; override;
    procedure Play(AVideoName: array of String; AEndVideo: TKMVideoPlayerEvent = nil); overload;
    procedure Play(AVideoName: String; AEndVideo: TKMVideoPlayerEvent = nil); overload;
    procedure Stop;
    procedure Resize;
    property IsPlay: Boolean read GetIsPlay;
  end;

var
  gVideoPlayer: TKMVideoPlayer;

{$ENDIF}

implementation

{$IFDEF PLAYVIDEO}

{ TKMVideoPlayer }

constructor TKMVideoPlayer.Create(AParentForm: TForm);
begin
  FParentForm := AParentForm;
  FVideoList := TStringList.Create;
end;

destructor TKMVideoPlayer.Destroy;
begin
  FVideoList.Free;
  inherited;
end;

procedure TKMVideoPlayer.Play(AVideoName: String; AEndVideo: TKMVideoPlayerEvent = nil);
begin
  Play([AVideoName], AEndVideo);
end;

procedure TKMVideoPlayer.Play(AVideoName: array of String; AEndVideo: TKMVideoPlayerEvent = nil);
var
  i: Integer;
begin
  for i := 0 to High(AVideoName) do
    if FileExists(VIDEOFILE_PATH + AVideoName[i]) then
      FVideoList.Add(AVideoName[i]);
  FEndVideo := AEndVideo;
  Init;
  PlayNextVideo;
end;

procedure TKMVideoPlayer.Init;
begin
  FPanel := TPanelTransparent.Create(FParentForm);
  FPanel.ShowCaption := False;
  FPanel.Caption := '';
  FPanel.BevelOuter := bvNone;
  FPanel.Parent := FParentForm;
  FPanel.OnClick := PanelClick;

  FMediaPlayer := TMediaPlayer.Create(FPanel);
  FMediaPlayer.Visible := False;
  FMediaPlayer.Parent := FPanel;
  FMediaPlayer.Display := FPanel;
  FMediaPlayer.OnNotify := MediaPlayerNotify;
  Application.ProcessMessages;
end;

procedure TKMVideoPlayer.Clear;
begin
  FreeAndNil(FMediaPlayer);
  FreeAndNil(FPanel);
  if Assigned(FEndVideo) then
    FEndVideo;
  FEndVideo := nil;
end;

procedure TKMVideoPlayer.MediaPlayerNotify(Sender: TObject);
begin
  case FMediaPlayer.Mode of
    mpStopped:
      PlayNextVideo;
  end;
end;

procedure TKMVideoPlayer.PlayNextVideo;
begin
  if FVideoList.Count = 0 then
  begin
    Clear;
    Exit;
  end;

  FMediaPlayer.FileName := VIDEOFILE_PATH + FVideoList[0];
  FVideoList.Delete(0);
  FMediaPlayer.Open;
  Resize;
  FMediaPlayer.Play;
  Application.ProcessMessages;
end;

function TKMVideoPlayer.GetIsPlay: Boolean;
begin
  Result := Assigned(FMediaPlayer) and (FMediaPlayer.Mode = mpPlaying);
end;

procedure TKMVideoPlayer.PanelClick(Sender: TObject);
begin
  Stop;
end;

procedure TKMVideoPlayer.Stop;
begin
  FVideoList.Clear;
  if Assigned(FMediaPlayer) then
    FMediaPlayer.Stop;
end;

procedure TKMVideoPlayer.Resize;
var
  Width, Height: Integer;
  AspectRatio: Single;
begin
  if not Assigned(FMediaPlayer) then
    Exit;

  Width := 640;// FMediaPlayer.DisplayRect.Right;
  Height := 160 * 2;// FMediaPlayer.DisplayRect.Bottom * 2;
  AspectRatio := Width / Height;

  if AspectRatio > FParentForm.ClientWidth / FParentForm.ClientHeight then
  begin
    FPanel.Width := FParentForm.ClientWidth;
    FPanel.Height := Round(FParentForm.ClientWidth / AspectRatio);
  end
  else
  begin
    FPanel.Width := Round(FParentForm.ClientHeight * AspectRatio);
    FPanel.Height := FParentForm.ClientHeight;
  end;

  FPanel.Left := FParentForm.ClientWidth div 2 - FPanel.Width div 2;
  FPanel.Top := FParentForm.ClientHeight div 2 - FPanel.Height div 2;
  FMediaPlayer.DisplayRect := Rect(0, 0, FPanel.Width, FPanel.Height);
end;

{ TPanelTransparent }

procedure TPanelTransparent.WmEraseBkgnd(var Msg: TWMEraseBkgnd);
begin
  Msg.Result := 1;
end;

procedure TPanelTransparent.CnCtlColorStatic(var Msg: TWMCtlColorStatic);
begin
  SetBKMode (Msg.ChildDC, TRANSPARENT);
  Msg.Result := GetStockObject (NULL_BRUSH);
end;

procedure TPanelTransparent.Paint;
begin
  SetBKMode (Handle, TRANSPARENT);
  //inherited;
end;

{$ENDIF}

end.
