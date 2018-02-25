unit KM_UnitTaskGoOutShowHungry;
{$I KaM_Remake.inc}
interface
uses
  Classes, KM_Defaults, KM_Units, SysUtils, KM_Points;

type
  TKMTaskGoOutShowHungry = class(TKMUnitTask)
  public
    constructor Create(aUnit:TKMUnit);
    function Execute:TKMTaskResult; override;
  end;


implementation
uses
  KM_CommonUtils;


{ TTaskGoOutShowHungry }
constructor TKMTaskGoOutShowHungry.Create(aUnit:TKMUnit);
begin
  inherited Create(aUnit);
  fTaskName := utn_GoOutShowHungry;
end;


function TKMTaskGoOutShowHungry.Execute:TKMTaskResult;
begin
  Result := tr_TaskContinues;
  if fUnit.GetHome.IsDestroyed then
  begin
    Result := tr_TaskDone;
    Exit;
  end;

  with fUnit do
  case fPhase of
    0: begin
         Thought := th_Eat;
         SetActionStay(20,ua_Walk);
       end;
    1: begin
         SetActionGoIn(ua_Walk,gd_GoOutside,fUnit.GetHome);
         GetHome.SetState(hst_Empty);
       end;
    2: SetActionLockedStay(4,ua_Walk);
    3: SetActionWalkToSpot(fUnit.GetHome.PointBelowEntrance);
    4: SetActionGoIn(ua_Walk,gd_GoInside,fUnit.GetHome);
    5: begin
         SetActionStay(20+KaMRandom(10),ua_Walk);
         GetHome.SetState(hst_Idle);
       end;
    else begin
         Thought := th_None;
         Result := tr_TaskDone;
       end;
  end;
  inc(fPhase);
end;


end.
