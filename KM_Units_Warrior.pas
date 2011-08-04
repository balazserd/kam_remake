unit KM_Units_Warrior;
{$I KaM_Remake.inc}
interface
uses Classes, SysUtils, KromUtils, Math,
  KM_CommonTypes, KM_Defaults, KM_Utils, KM_Units, KM_Houses, KM_Points;

type
  TKMTurnDirection = (tdNone, tdCW, tdCCW);

  //Possibly melee warrior class? with Archer class separate?
  TKMUnitWarrior = class(TKMUnit)
  private
  {Individual properties}
    fFlagAnim:cardinal;
    fRequestedFood:boolean;
    fTimeSinceHungryReminder:integer;
    fState:TWarriorState; //This property is individual to each unit, including commander
    fOrder:TWarriorOrder;
    fTargetCanBeReached:boolean;
    fOrderLoc:TKMPointDir; //Dir is the direction to face after order
    fOrderTargetUnit: TKMUnit; //Unit we are ordered to attack. This property should never be accessed, use public OrderTarget instead.
    fOrderTargetHouse: TKMHouse; //House we are ordered to attack. This property should never be accessed, use public OrderHouseTarget instead.
    fCommander:TKMUnitWarrior; //ID of commander unit, if nil then unit is commander itself and has a shtandart
  {Commander properties}
    fUnitsPerRow:integer;
    fMembers:TList;

    function GetRandomFoeFromMembers: TKMUnitWarrior;
    function RePosition:boolean; //Used by commander to check if troops are standing in the correct position. If not this will tell them to move and return false
    procedure SetUnitsPerRow(aVal:integer);
    function CanInterruptAction:boolean;
    procedure UpdateHungerMessage;

    procedure ClearOrderTarget;
    procedure SetOrderTarget(aUnit:TKMUnit);
    function GetOrderTarget:TKMUnit;
    function GetOrderHouseTarget:TKMHouse;
  public
  {MapEdProperties} //Don't need to be accessed nor saved during gameplay
    fMapEdMembersCount:integer;
    constructor Create(aOwner: shortint; PosX, PosY:integer; aUnitType:TUnitType);
    constructor Load(LoadStream:TKMemoryStream); override;
    procedure SyncLoad; override;
    procedure CloseUnit(aRemoveTileUsage:boolean=true); override;
    destructor Destroy; override;

    procedure KillUnit; override;

    procedure AddMember(aWarrior:TKMUnitWarrior);
    function GetCommander:TKMUnitWarrior;
    function IsCommander:boolean;
    function GetMemberCount:integer;
    property RequestedFood:boolean write fRequestedFood; //Cleared by Serf delivering food
    procedure SetGroupFullCondition;
    procedure SetOrderHouseTarget(aHouse:TKMHouse);
    property GetWarriorState: TWarriorState read fState;

  //Commands from player
    procedure OrderHalt(aTurnAmount:TKMTurnDirection=tdNone; aLineAmount:shortint=0);
    procedure OrderLinkTo(aNewCommander:TKMUnitWarrior); //Joins entire group to NewCommander
    procedure OrderFood;
    procedure OrderSplit; //Split group in half and assign another commander
    procedure OrderStorm;
    procedure OrderSplitLinkTo(aNewCommander:TKMUnitWarrior; aNumberOfMen:integer); //Splits X number of men from the group and adds them to the new commander
    procedure OrderWalk(aLoc:TKMPointDir; aOnlySetMembers:boolean=false; aTargetCanBeReached:boolean=true); reintroduce; overload;
    procedure OrderWalk(aLoc:TKMPoint); reintroduce; overload;
    procedure OrderAttackUnit(aTargetUnit:TKMUnit; aOnlySetMembers:boolean=false);
    procedure OrderAttackHouse(aTargetHouse:TKMHouse);

    function GetFightMinRange:single;
    function GetFightMaxRange:single;
    property UnitsPerRow:integer read fUnitsPerRow write SetUnitsPerRow;
    property OrderTarget:TKMUnit read GetOrderTarget write SetOrderTarget;
    property OrderLocDir:TKMPointDir read fOrderLoc write fOrderLoc;
    property GetOrder:TWarriorOrder read fOrder;
    function GetRow:integer;
    function ArmyCanTakeOrders:boolean;
    function ArmyInFight:boolean;
    procedure ReissueOrder;

    function IsSameGroup(aWarrior:TKMUnitWarrior):boolean;
    function IsRanged:boolean;
    function FindLinkUnit(aLoc:TKMPoint):TKMUnitWarrior;

    procedure SetActionGoIn(aAction: TUnitActionType; aGoDir: TGoInDirection; aHouse:TKMHouse); override;

    function CheckForEnemy:boolean;
    function FindEnemy:TKMUnit;
    procedure FightEnemy(aEnemy:TKMUnit);

    procedure Save(SaveStream:TKMemoryStream); override;
    function UpdateState:boolean; override;
    procedure Paint; override;
  end;


implementation
uses KM_DeliverQueue, KM_Game, KM_TextLibrary, KM_PlayersCollection, KM_Render, KM_Terrain, KM_UnitTaskAttackHouse,
  KM_UnitActionAbandonWalk, KM_UnitActionFight, KM_UnitActionGoInOut, KM_UnitActionWalkTo, KM_UnitActionStay,
  KM_UnitActionStormAttack, KM_ResourceGFX;


{ TKMUnitWarrior }
constructor TKMUnitWarrior.Create(aOwner: shortint; PosX, PosY:integer; aUnitType:TUnitType);
begin
  Inherited;
  fCommander         := nil;
  fOrderTargetUnit   := nil;
  fOrderTargetHouse  := nil;
  fRequestedFood     := false;
  fFlagAnim          := 0;
  fTimeSinceHungryReminder := 0;
  fOrder             := wo_None;
  fState             := ws_None;
  fOrderLoc          := KMPointDir(KMPoint(PosX, PosY), dir_NA);
  fUnitsPerRow       := 1;
  fMembers           := nil; //Only commander units will have it initialized
  fMapEdMembersCount := 0; //Used only in MapEd
end;


constructor TKMUnitWarrior.Load(LoadStream:TKMemoryStream);
var i,aCount:integer; W:TKMUnitWarrior;
begin
  Inherited;
  LoadStream.Read(fCommander, 4); //subst on syncload
  LoadStream.Read(fOrderTargetUnit, 4); //subst on syncload
  LoadStream.Read(fOrderTargetHouse, 4); //subst on syncload
  LoadStream.Read(fFlagAnim);
  LoadStream.Read(fRequestedFood);
  LoadStream.Read(fTimeSinceHungryReminder);
  LoadStream.Read(fOrder, SizeOf(fOrder));
  LoadStream.Read(fState, SizeOf(fState));
  LoadStream.Read(fOrderLoc,SizeOf(fOrderLoc));
  LoadStream.Read(fTargetCanBeReached);
  LoadStream.Read(fUnitsPerRow);
  LoadStream.Read(aCount);
  if aCount <> 0 then
  begin
    fMembers := TList.Create;
    for i := 1 to aCount do
    begin
      LoadStream.Read(W, 4); //subst on syncload
      fMembers.Add(W);
    end;
  end else
    fMembers := nil;
end;


procedure TKMUnitWarrior.SyncLoad;
var i:integer;
begin
  Inherited;
  fCommander := TKMUnitWarrior(fPlayers.GetUnitByID(cardinal(fCommander)));
  fOrderTargetUnit := TKMUnitWarrior(fPlayers.GetUnitByID(cardinal(fOrderTargetUnit)));
  fOrderTargetHouse := fPlayers.GetHouseByID(cardinal(fOrderTargetHouse));
  if fMembers<>nil then
    for i:=0 to fMembers.Count-1 do
      fMembers.Items[i] := TKMUnitWarrior(fPlayers.GetUnitByID(cardinal(fMembers.Items[i])));
end;


procedure TKMUnitWarrior.CloseUnit;
begin
  fPlayers.CleanUpUnitPointer(fOrderTargetUnit);
  fPlayers.CleanUpHousePointer(fOrderTargetHouse);
  FreeAndNil(fMembers);
  fState := ws_None;
  fOrder := wo_None;
  fCommander := nil; //Otherwise if this closed unit is saved memory errors can occur (fCommander does not use pointer tracking)
  Inherited;
end;


destructor TKMUnitWarrior.Destroy;
begin
  fPlayers.CleanUpUnitPointer(fOrderTargetUnit);
  fPlayers.CleanUpHousePointer(fOrderTargetHouse);

  FreeAndNil(fMembers);
  Inherited;
end;


procedure TKMUnitWarrior.KillUnit;
var i,NewCommanderID:integer; Test,Nearest:single; NewCommander:TKMUnitWarrior;
begin
  if IsDeadOrDying then
  begin
    //Due to fKillASAP reassigning the commander etc. has already happened, we just need to finish the kill with Inherited
    Inherited;
    exit;
  end;

  //Kill group member
  if fCommander <> nil then
  begin
    fCommander.fMembers.Remove((Self));
    fCommander.SetUnitsPerRow(fCommander.UnitsPerRow); //Shortcut to ensure UnitsPerRow <= fMembers.Count
    //Now make the group reposition if they were idle (halt has IsDead check in case commander is dead too)
    if (fCommander.fState <> ws_Walking) and (not (fUnitTask is TTaskAttackHouse))
    and not fCommander.ArmyInFight then
      fCommander.OrderHalt;
  end;

  //Kill group commander
  if fCommander = nil then
  begin
    NewCommander := nil;
    if (fMembers <> nil) and (fMembers.Count <> 0) then
    begin
      //Get nearest neighbour and give him the Flag
      NewCommanderID := 0;
      Nearest := maxSingle;
      for i:=0 to fMembers.Count-1 do begin
        Test := GetLength(GetPosition, TKMUnitWarrior(fMembers.Items[i]).GetPosition);
        if Test < Nearest then begin
          Nearest := Test;
          NewCommanderID := i;
        end;
      end;

      NewCommander := TKMUnitWarrior(fMembers.Items[NewCommanderID]);
      NewCommander.fCommander := nil; //Become a commander
      NewCommander.fUnitsPerRow := fUnitsPerRow; //Transfer group properties
      NewCommander.fMembers := TList.Create;

      //Transfer all members to new commander
      for i:=0 to fMembers.Count-1 do
        if i <> NewCommanderID then begin
          TKMUnitWarrior(fMembers.Items[i]).fCommander := NewCommander; //Reassign new Commander
          NewCommander.fMembers.Add(fMembers.Items[i]); //Reassign membership
        end;

      //Make sure units per row is still valid
      NewCommander.fUnitsPerRow := min(NewCommander.fUnitsPerRow,NewCommander.fMembers.Count+1);
      //Now make the new commander reposition or keep walking where we are going (don't stop group walking because leader dies, we could be in danger)
      NewCommander.fOrderLoc := fOrderLoc;
      NewCommander.SetOrderTarget(fOrderTargetUnit);
      NewCommander.SetOrderHouseTarget(fOrderTargetHouse);

      //Transfer walk/attack
      if (GetUnitAction is TUnitActionWalkTo) and (fState = ws_Walking) then
      begin
        if GetOrderTarget <> nil then
          NewCommander.fOrder := wo_AttackUnit
        else
          NewCommander.fOrder := wo_Walk;
      end;
      if fUnitTask is TTaskAttackHouse then
        NewCommander.fOrder := wo_AttackHouse
      else
        //If we were walking/attacking then it is handled above. Otherwise just reposition
        if (fState <> ws_Walking) and not NewCommander.ArmyInFight then
          NewCommander.OrderWalk(KMPointDir(NewCommander.GetPosition,fOrderLoc.Dir)); //Else use position of new commander and direction of group

      //Now set ourself to new commander, so that we have some way of referencing units after they die(?)
      fCommander := NewCommander;
    end;
    fPlayers.Player[fOwner].AI.CommanderDied(Self, NewCommander); //Tell our AI that we have died so it can update defence positions, etc.
  end;

  ClearOrderTarget; //This ensures that pointer usage tracking is reset

  Inherited;
end;


//Members should added only to commanders
//fMembers list is not initialized until first memeber is added
procedure TKMUnitWarrior.AddMember(aWarrior:TKMUnitWarrior);
begin
  Assert(IsCommander);
  if fMembers = nil then fMembers := TList.Create;
  fMembers.Add(aWarrior);
  aWarrior.fCommander := Self;
end;


procedure TKMUnitWarrior.SetGroupFullCondition;
var i:integer;
begin
  SetFullCondition;
  if (fMembers <> nil) then //If we have members then give them full condition too
    for i:=0 to fMembers.Count-1 do
      TKMUnitWarrior(fMembers.Items[i]).SetFullCondition;
end;


{Note that this function returns Members count, Groups count with commander is +1}
function TKMUnitWarrior.GetMemberCount:integer;
begin
  if (fCommander <> nil) or (fMembers = nil) then
    Result := 0
  else
    Result := fMembers.Count;
end;


//Return Commander or Self if unit is single
function TKMUnitWarrior.GetCommander:TKMUnitWarrior;
begin
  if fCommander <> nil then
    Result := fCommander
  else
    Result := Self;
end;


//If we don't have a commander, then we are Commander, at least to ourselves
function TKMUnitWarrior.IsCommander:boolean;
begin
  Result := fCommander = nil;
end;


function TKMUnitWarrior.RePosition:boolean;
var ClosestTile:TKMPoint;
begin
  Result := true;
  if (fState = ws_None) and (Direction <> fOrderLoc.Dir) then
    fState := ws_RepositionPause; //Make sure we always face the right way if somehow state is gets to None without doing this

  if fOrderLoc.Loc.X = 0 then exit;

  if fState = ws_None then
    ClosestTile := fTerrain.GetClosestTile(fOrderLoc.Loc, GetPosition, CanWalk);

  //See if we are in position already or if we can't reach the position, (closest tile differs from target tile) because we don't retry for that case.
  if (fState = ws_None) and (KMSamePoint(GetPosition,fOrderLoc.Loc) or (not fTargetCanBeReached) or (not KMSamePoint(ClosestTile,fOrderLoc.Loc))) then
    exit;

  //This means we are not in position, return false and move into position (unless we are currently walking)
  Result := false;
  if CanInterruptAction and (fState = ws_None) and (not (GetUnitAction is TUnitActionWalkTo)) then
  begin
    SetActionWalkToSpot(fOrderLoc.Loc);
    fState := ws_Walking;
  end;
end;


procedure TKMUnitWarrior.OrderHalt(aTurnAmount:TKMTurnDirection=tdNone; aLineAmount:shortint=0);
var HaltPoint: TKMPointDir;
begin
  if IsDead then exit; //Can happen e.g. when entire group dies at once due to hunger
  //Pass command to Commander unit, but avoid recursively passing command to Self
  if (fCommander <> nil) and (fCommander <> Self) then
  begin
    fCommander.OrderHalt(aTurnAmount,aLineAmount);
    exit;
  end;

  if fOrderLoc.Loc.X = 0 then //If it is invalid, use commander's values
    HaltPoint := KMPointDir(NextPosition, Direction)
  else
    if fState = ws_Walking then //If we are walking use commander's location, but order Direction
      HaltPoint := KMPointDir(NextPosition, fOrderLoc.Dir)
    else
      HaltPoint := fOrderLoc;

  case aTurnAmount of
    tdCW:   HaltPoint.Dir := KMNextDirection(HaltPoint.Dir);
    tdCCW:  HaltPoint.Dir := KMPrevDirection(HaltPoint.Dir);
  end;

  fOrderLoc.Dir := HaltPoint.Dir;
  Assert(fOrderLoc.Dir <> dir_NA);

  if fMembers <> nil then
    SetUnitsPerRow(fUnitsPerRow+aLineAmount);

  if (aTurnAmount <> tdNone) or (aLineAmount <> 0) then
    ReissueOrder //When changing formation/direction do not interupt walks/other orders
  else
    OrderWalk(HaltPoint);
end;


procedure TKMUnitWarrior.OrderLinkTo(aNewCommander:TKMUnitWarrior); //Joins entire group to NewCommander
var i:integer;
begin
  //Redirect command so that both units are Commanders
  if (GetCommander<>Self) or (aNewCommander.GetCommander<>aNewCommander) then begin
    GetCommander.OrderLinkTo(aNewCommander.GetCommander);
    exit;
  end;

  //Only link to same group type
  if UnitGroups[fUnitType] <> UnitGroups[aNewCommander.fUnitType] then exit;

  //Can't link to self for obvious reasons
  if aNewCommander = Self then exit;

  //Move our members and self to the new commander
  if fMembers <> nil then
  begin
    for i:=0 to fMembers.Count-1 do
    begin
      //Add the commander in the middle of his members
      if i = fUnitsPerRow div 2 then
        aNewCommander.AddMember(Self);

      aNewCommander.AddMember(TKMUnitWarrior(fMembers.Items[i]));
    end;
    FreeAndNil(fMembers); //We are not a commander now so nil our memebers list (they have been moved to new commander)
  end;
  //If we haven't added ourself yet (happens if we have <= 1 members) then add ourself now
  if fCommander <> aNewCommander then
    aNewCommander.AddMember(Self);

  //Tell commander to reissue the order so that the new members do it
  fCommander.ReissueOrder;
end;


procedure TKMUnitWarrior.OrderSplit; //Split group in half and assign another commander
var i, DeletedCount: integer; NewCommander:TKMUnitWarrior; MultipleTypes: boolean;
begin
  if GetMemberCount = 0 then exit; //Only commanders have members

  //If there are different unit types in the group, split should just split them first
  MultipleTypes := false;
  NewCommander  := nil; //init
  for i := 0 to fMembers.Count-1 do
    if TKMUnitWarrior(fMembers.Items[i]).UnitType <> fUnitType then
    begin
      MultipleTypes := true;
      NewCommander := TKMUnitWarrior(fMembers.Items[i]); //New commander is first unit of different type, for simplicity
      break;
    end;

  //Choose the new commander (if we haven't already due to multiple types) and remove him from members
  if not MultipleTypes then
    NewCommander := fMembers.Items[((fMembers.Count+1) div 2)+(min(fUnitsPerRow,(fMembers.Count+1) div 2) div 2)-1];
  fMembers.Remove(NewCommander);

  NewCommander.fUnitsPerRow := fUnitsPerRow;
  NewCommander.fTimeSinceHungryReminder := fTimeSinceHungryReminder; //If we are hungry then don't repeat message each time we split, give new commander our counter
  NewCommander.fCommander := nil;
  //Commander OrderLoc must always be valid, but because this guy wasn't a commander it might not be
  NewCommander.fOrderLoc := KMPointDir(NewCommander.GetPosition, fOrderLoc.Dir);

  DeletedCount := 0;
  for i := 0 to fMembers.Count-1 do
  begin
    //Either split evenly, or when there are multiple types, split if they are different to the commander (us)
    if (MultipleTypes and(TKMUnitWarrior(fMembers.Items[i-DeletedCount]).UnitType <> fUnitType)) or
      ((not MultipleTypes)and(i-DeletedCount >= fMembers.Count div 2)) then
    begin
      NewCommander.AddMember(fMembers.Items[i-DeletedCount]); //Join new commander
      fMembers.Delete(i-DeletedCount); //Leave this commander
      inc(DeletedCount);
    end; //Else stay with this commander
  end;

  if GetMemberCount = 0 then FreeAndNil(fMembers); //If we had a group of only 2 units

  //Make sure units per row is still valid for both groups
  fUnitsPerRow := min(fUnitsPerRow, GetMemberCount+1);
  NewCommander.fUnitsPerRow := min(fUnitsPerRow, NewCommander.GetMemberCount+1);

  //Tell both commanders to reposition
  OrderHalt;
  NewCommander.OrderHalt;
end;


//Splits X number of men from the group and adds them to the new commander
procedure TKMUnitWarrior.OrderSplitLinkTo(aNewCommander:TKMUnitWarrior; aNumberOfMen:integer);
var i, DeletedCount: integer;
begin
  Assert(aNumberOfMen < GetMemberCount+1); //Not allowed to take the commander, only members (if you want the command too use normal LinkTo)
    
  //Take units from the end of fMembers
  DeletedCount := 0;
  for i := fMembers.Count-1 downto 0 do
    if DeletedCount < aNumberOfMen then
    begin
      aNewCommander.AddMember(fMembers.Items[i]);
      fMembers.Delete(i);
      inc(DeletedCount);
    end;

  //Make sure units per row is still valid
  fUnitsPerRow := min(fUnitsPerRow, fMembers.Count+1);

  if fMembers.Count = 0 then
    FreeAndNil(fMembers);

  //Tell both commanders to reposition
  OrderHalt;
  aNewCommander.OrderHalt;
end;


//Order some food for troops
procedure TKMUnitWarrior.OrderFood;
var i:integer;
begin
  if (fCondition<(UNIT_MAX_CONDITION*TROOPS_FEED_MAX)) and not (fRequestedFood) then begin
    fPlayers.Player[fOwner].DeliverList.AddNewDemand(nil, Self, rt_Food, 1, dt_Once, di_High);
    fRequestedFood := true;
  end;
  //Commanders also tell troops to ask for some food
  if (fCommander = nil) and (fMembers <> nil) then
    for i := 0 to fMembers.Count-1 do
      TKMUnitWarrior(fMembers.Items[i]).OrderFood;
  OrderHalt;
end;


procedure TKMUnitWarrior.OrderStorm;
var i:integer;
begin
  fOrder := wo_Storm;
  fState := ws_None; //Clear other states
  SetOrderTarget(nil);
  SetOrderHouseTarget(nil);

  if (fCommander = nil) and (fMembers <> nil) then
    for i := 0 to fMembers.Count-1 do
      TKMUnitWarrior(fMembers.Items[i]).OrderStorm;
end;


procedure TKMUnitWarrior.ClearOrderTarget;
begin
  //Set fOrderTargets to nil, removing pointer if it's still valid
  fPlayers.CleanUpUnitPointer(fOrderTargetUnit);
  fPlayers.CleanUpHousePointer(fOrderTargetHouse);
end;


procedure TKMUnitWarrior.SetOrderTarget(aUnit:TKMUnit);
begin
  //Remove previous value
  ClearOrderTarget;
  if aUnit <> nil then
    fOrderTargetUnit := aUnit.GetUnitPointer; //Else it will be nil from ClearOrderTarget
end;


function TKMUnitWarrior.GetOrderTarget:TKMUnit;
begin
  //If the target unit has died then clear it
  if (fOrderTargetUnit <> nil) and (fOrderTargetUnit.IsDead) then ClearOrderTarget;
  Result := fOrderTargetUnit;
end;


procedure TKMUnitWarrior.SetOrderHouseTarget(aHouse:TKMHouse);
begin
  //Remove previous value
  ClearOrderTarget;
  if aHouse <> nil then
    fOrderTargetHouse := aHouse.GetHousePointer; //Else it will be nil from ClearOrderTarget
end;


function TKMUnitWarrior.GetOrderHouseTarget:TKMHouse;
begin
  //If the target house has been destroyed then clear it
  if (fOrderTargetHouse <> nil) and (fOrderTargetHouse.IsDestroyed) then ClearOrderTarget;
  Result := fOrderTargetHouse;
end;


//Check which row we are in
function TKMUnitWarrior.GetRow:integer;
var i: integer;
begin
  Result := 1;
  if not IsCommander then
    for i:=1 to fCommander.fMembers.Count do
      if Self = TKMUnitWarrior(fCommander.fMembers.Items[i-1]) then
      begin
        Result := (i div fCommander.UnitsPerRow)+1; //First row is 1 not 0
        Exit;
      end;
end;


//Get random unit from those our squad is fighting with
function TKMUnitWarrior.GetRandomFoeFromMembers: TKMUnitWarrior;
var
  i:Integer;
  Foes: TList; //List of found foes
  Test, BestLength : single;
begin
  Assert(IsCommander); //This should only be called for commanders
  Foes := TList.Create;
  if (GetUnitAction is TUnitActionFight) and (TUnitActionFight(GetUnitAction).GetOpponent <> nil)
  and (TUnitActionFight(GetUnitAction).GetOpponent is TKMUnitWarrior) then
    Foes.Add(TUnitActionFight(GetUnitAction).GetOpponent);

  //Check through fellow members to see who is in fight with enemy forces (excluding Citizen)
  if fMembers <> nil then
    for i:=0 to fMembers.Count-1 do
      if (TKMUnitWarrior(fMembers.Items[i]).GetUnitAction is TUnitActionFight)
      and (TUnitActionFight(TKMUnitWarrior(fMembers.Items[i]).GetUnitAction).GetOpponent is TKMUnitWarrior) then
        Foes.Add(TUnitActionFight(TKMUnitWarrior(fMembers.Items[i]).GetUnitAction).GetOpponent);

  Result := nil;
  BestLength := MaxSingle;
  if Foes.Count > 0 then
    for i:=0 to Foes.Count - 1 do
    begin
      Test := GetLength(GetPosition, TKMUnitWarrior(Foes.Items[i]).GetPosition);
      if Test < BestLength then
      begin
        BestLength := Test;
        Result := TKMUnitWarrior(Foes.Items[KaMRandom(Foes.Count)]);
      end;
    end;

  Foes.Free;
end;


//If the player is allowed to issue orders to group
function TKMUnitWarrior.ArmyCanTakeOrders:boolean;
begin
  Result := IsRanged or not ArmyInFight; //Ranged units can always take orders
end;


//If the group is in fight with someone
function TKMUnitWarrior.ArmyInFight:boolean;
var i: integer;
begin
  Assert(fCommander = nil); //This should only be called for commanders
  Result := false;
  if (GetUnitAction is TUnitActionStormAttack)
  or ((GetUnitAction is TUnitActionFight)and(TUnitActionFight(GetUnitAction).GetOpponent is TKMUnitWarrior)) then
    Result := true //We are busy if the commander is storm attacking or fighting a warrior
  else
    //Busy if a member is fighting a warrior
    if fMembers <> nil then
      for i:=0 to fMembers.Count-1 do
        if (TKMUnitWarrior(fMembers.Items[i]).GetUnitAction is TUnitActionFight)
        and(TUnitActionFight(TKMUnitWarrior(fMembers.Items[i]).GetUnitAction).GetOpponent is TKMUnitWarrior)
        and not(TUnitActionFight(TKMUnitWarrior(fMembers.Items[i]).GetUnitAction).GetOpponent.IsDeadOrDying) then
        begin
          Result := true;
          Exit;
        end;
end;


//At which range we can fight
function TKMUnitWarrior.GetFightMaxRange:single;
begin
  case fUnitType of
    ut_Bowman:      Result := RANGE_BOWMAN_MAX;
    ut_Arbaletman:  Result := RANGE_ARBALETMAN_MAX;
    else            Result := 1.42; //slightly bigger than sqrt(2) for diagonal fights
  end;
end;


//At which range we can fight
function TKMUnitWarrior.GetFightMinRange:single;
begin
  case fUnitType of
    ut_Bowman:      Result := RANGE_BOWMAN_MIN;
    ut_Arbaletman:  Result := RANGE_ARBALETMAN_MIN;
    else            Result := 1; //Any tile that is not our own
  end;
end;


//See if we are in the same group as aWarrior by comparing commanders
function TKMUnitWarrior.IsSameGroup(aWarrior:TKMUnitWarrior):boolean;
begin
  Result := (GetCommander = aWarrior.GetCommander);
end;


function TKMUnitWarrior.IsRanged:boolean;
begin
  Result := WarriorFightType[UnitType] = ft_Ranged;
end;


function TKMUnitWarrior.FindLinkUnit(aLoc:TKMPoint):TKMUnitWarrior;
var i,k:integer; FoundUnit:TKMUnit;
begin
  Result := nil;

  //Replacing it with fTerrain.UnitsHitTestWithinRad sounds plausible, but would require
  //to change input parameters to include TKMUnitWarrior, fOwner, UnitType.
  //I think thats just not worth it
  for i:=-LINK_RADIUS to LINK_RADIUS do
  for k:=-LINK_RADIUS to LINK_RADIUS do
  if GetLength(i,k) < LINK_RADIUS then //Check within circle area
  begin
    FoundUnit := fTerrain.UnitsHitTest(aLoc.X+i, aLoc.Y+k); //off-map coords will be skipped
    if (FoundUnit is TKMUnitWarrior) and
       (FoundUnit.GetOwner = fOwner) and
       (UnitGroups[FoundUnit.UnitType] = UnitGroups[fUnitType]) then //They must be the same group type
    begin
      Result := TKMUnitWarrior(FoundUnit);
      exit;
    end;
  end;
end;


procedure TKMUnitWarrior.SetActionGoIn(aAction: TUnitActionType; aGoDir: TGoInDirection; aHouse:TKMHouse);
begin
  Assert(aGoDir = gd_GoOutside, 'Walking inside is not implemented yet');
  Assert(aHouse.GetHouseType = ht_Barracks, 'Only Barracks so far');
  Inherited;
  fOrder := wo_WalkOut;
end;


procedure TKMUnitWarrior.SetUnitsPerRow(aVal:integer);
begin
  if (fCommander = nil) and (fMembers <> nil) then
    fUnitsPerRow := EnsureRange(aVal,1,fMembers.Count+1);
  if (fCommander = nil) and (fMembers = nil) and (fMapEdMembersCount<>0) then //Special case for MapEd
    fUnitsPerRow := EnsureRange(aVal,1,fMapEdMembersCount+1);
end;


//Reissue our current order, or just halt if we don't have one
procedure TKMUnitWarrior.ReissueOrder;
begin
  Assert(fCommander = nil);

  if (fUnitTask is TTaskAttackHouse) and (fOrderTargetHouse <> nil) then
    OrderAttackHouse(fOrderTargetHouse)
  else
    if (fOrderTargetUnit <> nil) and (fState = ws_Walking) then
      OrderAttackUnit(fOrderTargetUnit)
    else
      if fState = ws_Walking then
        OrderWalk(fOrderLoc)
      else
        OrderHalt;
end;


//Notice: any warrior can get Order (from its commander), but only commander should get Orders from Player
procedure TKMUnitWarrior.OrderWalk(aLoc:TKMPointDir; aOnlySetMembers:boolean=false; aTargetCanBeReached:boolean=true);
var i:integer; NewLoc:TKMPoint; NewLocCanBeReached: boolean;
begin
  if KMSamePoint(aLoc.Loc, KMPoint(0,0)) then exit;
  if (fCommander <> nil) or (not aOnlySetMembers) then
  begin
    fOrder    := wo_Walk;
    fState    := ws_None; //Clear other states
    fOrderLoc := aLoc;
    fTargetCanBeReached := aTargetCanBeReached;
    SetOrderTarget(nil);
    SetOrderHouseTarget(nil);
  end;

  if (fCommander=nil)and(fMembers <> nil) then //Don't give group orders if unit has no crew
  for i:=1 to fMembers.Count do begin
    NewLoc := GetPositionInGroup2(aLoc.Loc.X, aLoc.Loc.Y, aLoc.Dir,
                                  i+1, fUnitsPerRow, fTerrain.MapX, fTerrain.MapY, NewLocCanBeReached); //Allow off map positions so GetClosestTile works properly
    TKMUnitWarrior(fMembers.Items[i-1]).OrderWalk(KMPointDir(NewLoc,aLoc.Dir),false,NewLocCanBeReached)
  end;
end;


procedure TKMUnitWarrior.OrderWalk(aLoc:TKMPoint);
var NewP:TKMPointDir;
begin
  //keep old direction if group had an order to walk somewhere
  if (fOrderLoc.Loc.X <> 0) then
    NewP := KMPointDir(aLoc, fOrderLoc.Dir)
  else
    NewP := KMPointDir(aLoc, Direction);

  OrderWalk(NewP);
end;


//Attack works like this: Commander tracks target unit in walk action. Members are ordered to walk to formation with commaner at target unit's location.
//If target moves in WalkAction, commander will reissue PlaceOrder with aOnlySetMembers = true, so members will walk to new location.
procedure TKMUnitWarrior.OrderAttackUnit(aTargetUnit:TKMUnit; aOnlySetMembers:boolean=false);
begin
  //todo: Support archers attacking units that cannot be reached by foot, e.g. ones up on a wall.
  if (fCommander <> nil) or (not aOnlySetMembers) then
  begin
    fOrder := wo_AttackUnit; //Only commander has order Attack, other units have walk to (this means they walk in formation and not in a straight line meeting the enemy one at a time
    fState := ws_None; //Clear other states
    fOrderLoc := KMPointDir(aTargetUnit.GetPosition,fOrderLoc.Dir);
    SetOrderHouseTarget(nil);
    SetOrderTarget(aTargetUnit);
  end;
  //Only the commander tracks the target, group members are just told to walk to the position
  OrderWalk(KMPointDir(aTargetUnit.GetPosition,fOrderLoc.Dir),true); //Only set members
end;


{ Attack House works like this:
All units are assigned TTaskAttackHouse which does everything for us
(move to position, hit house, abandon, etc.) }
procedure TKMUnitWarrior.OrderAttackHouse(aTargetHouse:TKMHouse);
var i: integer;
begin
  fOrder := wo_AttackHouse;
  fState := ws_None; //Clear other states
  SetOrderTarget(nil);
  SetOrderHouseTarget(aTargetHouse);

  //Transmit order to all members if we have any
  if (fCommander = nil) and (fMembers <> nil) then
    for i:=0 to fMembers.Count-1 do
      TKMUnitWarrior(fMembers.Items[i]).OrderAttackHouse(aTargetHouse);
end;


procedure TKMUnitWarrior.Save(SaveStream:TKMemoryStream);
var i:integer;
begin
  Inherited;
  if fCommander <> nil then
    SaveStream.Write(fCommander.ID) //Store ID
  else
    SaveStream.Write(Integer(0));
  if fOrderTargetUnit <> nil then
    SaveStream.Write(fOrderTargetUnit.ID) //Store ID
  else
    SaveStream.Write(Integer(0));
  if fOrderTargetHouse <> nil then
    SaveStream.Write(fOrderTargetHouse.ID) //Store ID
  else
    SaveStream.Write(Integer(0));
  SaveStream.Write(fFlagAnim);
  SaveStream.Write(fRequestedFood);
  SaveStream.Write(fTimeSinceHungryReminder);
  SaveStream.Write(fOrder, SizeOf(fOrder));
  SaveStream.Write(fState, SizeOf(fState));
  SaveStream.Write(fOrderLoc,SizeOf(fOrderLoc));
  SaveStream.Write(fTargetCanBeReached);
  SaveStream.Write(fUnitsPerRow);
  //Only save members if we are a commander
  if (fMembers <> nil) and (fCommander = nil) then
  begin
    SaveStream.Write(fMembers.Count);
    for i:=1 to fMembers.Count do
      if TKMUnitWarrior(fMembers.Items[i-1]) <> nil then
        SaveStream.Write(TKMUnitWarrior(fMembers.Items[i-1]).ID) //Store ID
      else
        SaveStream.Write(Integer(0));
  end else
    SaveStream.Write(Integer(0));
end;


//Tell the player to feed us if we are hungry
procedure TKMUnitWarrior.UpdateHungerMessage;
var i:integer; SomeoneHungry:boolean;
begin
  if (fCommander = nil) then
  begin
    SomeoneHungry := (fCondition < UNIT_MIN_CONDITION); //Check commander
    if (fMembers <> nil) and (not SomeoneHungry) then
      for i:=0 to fMembers.Count-1 do
      begin
        SomeoneHungry := SomeoneHungry or (TKMUnitWarrior(fMembers.List[i]).Condition < UNIT_MIN_CONDITION);
        if SomeoneHungry then break;
      end;

    if SomeoneHungry then
    begin
      dec(fTimeSinceHungryReminder);
      if fTimeSinceHungryReminder < 1 then
      begin
        if (fOwner = MyPlayer.PlayerIndex) then
          fGame.fGamePlayInterface.MessageIssue(msgUnit,fTextLibrary.GetTextString(296),GetPosition);
        fTimeSinceHungryReminder := TIME_BETWEEN_MESSAGES; //Don't show one again until it is time
      end;
    end
    else
      fTimeSinceHungryReminder := 0;
  end;
end;


function TKMUnitWarrior.CheckForEnemy:boolean;
var FoundEnemy: TKMUnit;
begin
  Result := false; //Didn't find anyone to fight
  FoundEnemy := FindEnemy;
  if FoundEnemy = nil then exit;
  FightEnemy(FoundEnemy);
  Result := true; //Found someone
end;


function TKMUnitWarrior.FindEnemy:TKMUnit;
var TestDir:TKMDirection;
begin
  Result := nil; //No one to fight
  if not ENABLE_FIGHTING then exit;
  if not CanInterruptAction then exit;

  if IsRanged then
  begin
    //We are busy with an action (e.g. in a fight)
    if (GetUnitAction <> nil) and GetUnitAction.Locked then Exit;

    //We are shooting at house
    if (fUnitTask <> nil) and (fUnitTask is TTaskAttackHouse) then Exit;

    //Archers should only look for opponents when they are idle or when they are finishing another fight (function is called by TUnitActionFight)
    if (GetUnitAction is TUnitActionWalkTo)
    and ((GetOrderTarget = nil) or GetOrderTarget.IsDeadOrDying or not InRange(GetLength(NextPosition, GetOrderTarget.GetPosition), GetFightMinRange, GetFightMaxRange))
    then
      Exit;
  end;

  if IsRanged then
    TestDir := Direction //Use direction for ranged attacks, if it was not already specified
  else
    TestDir := dir_NA;

  //This function should not be run too often, as it will take some time to execute (e.g. with lots of warriors in the range area to check)
  Result := fTerrain.UnitsHitTestWithinRad(GetPosition, GetFightMinRange, GetFightMaxRange, GetOwner, at_Enemy, TestDir);

  //Only stop attacking a house if it's a warrior
  if (fUnitTask <> nil) and (fUnitTask is TTaskAttackHouse) and (GetUnitAction is TUnitActionStay) and not (Result is TKMUnitWarrior) then
    Result := nil;
end;


procedure TKMUnitWarrior.FightEnemy(aEnemy:TKMUnit);
begin
  Assert(aEnemy <> nil, 'Fight no one?');

  //Free the task or set it up to be resumed afterwards
  if GetUnitTask <> nil then
  begin
    if (GetUnitTask is TTaskAttackHouse) and not (aEnemy is TKMUnitWarrior) then
      TTaskAttackHouse(GetUnitTask).Phase := 0 //Reset task so it will resume after the fight
    else
      FreeAndNil(fUnitTask); //e.g. TaskAttackHouse
  end;

  //Attempt to resume walks/attacks after interuption
  if (GetUnitAction is TUnitActionWalkTo) and (fState = ws_Walking) and not (aEnemy is TKMUnitWarrior) then
  begin
    if GetOrderTarget <> nil then
      fOrder := wo_AttackUnit
    else
      fOrder := wo_Walk;
  end;

  SetActionFight(ua_Work, aEnemy);
  if aEnemy is TKMUnitWarrior then
  begin
    TKMUnitWarrior(aEnemy).CheckForEnemy; //Let opponent know he is attacked
    if fCommander = nil then fOrderLoc := KMPointDir(GetPosition,fOrderLoc.Dir); //so that after the fight we stay where we are
  end;
end;


{ See if we can abandon other actions in favor of more important things }
function TKMUnitWarrior.CanInterruptAction:boolean;
begin
  if GetUnitAction is TUnitActionWalkTo      then Result := TUnitActionWalkTo(GetUnitAction).CanAbandonExternal and GetUnitAction.StepDone else //Only when unit is idling during Interaction pauses
  if(GetUnitAction is TUnitActionStay) and
    (GetUnitTask   is TTaskAttackHouse)      then Result := true else //We can abandon attack house if the action is stay
  if GetUnitAction is TUnitActionStay        then Result := not GetUnitAction.Locked else //Initial pause before leaving barracks is locked
  if GetUnitAction is TUnitActionAbandonWalk then Result := GetUnitAction.StepDone and not GetUnitAction.Locked else //Abandon walk should never be abandoned, it will exit within 1 step anyway
  if GetUnitAction is TUnitActionGoInOut     then Result := not GetUnitAction.Locked else //Never interupt leaving barracks
  if GetUnitAction is TUnitActionStormAttack then Result := not GetUnitAction.Locked else //Never interupt storm attack
  if GetUnitAction is TUnitActionFight       then Result := IsRanged or not GetUnitAction.Locked //Only allowed to interupt ranged fights
  else Result := true;
end;


function TKMUnitWarrior.UpdateState:boolean;
var
  i:integer;
  PositioningDone:boolean;
  ChosenFoe: TKMUnitWarrior;
begin
  if IsDeadOrDying then
  begin
    Result:=true; //Required for override compatibility
    Inherited UpdateState;
    exit;
  end;

  if fCommander <> nil then
  begin
    if fCommander.IsDeadOrDying then raise ELocError.Create('fCommander.IsDeadOrDying',GetPosition);
    if fCommander.fCommander <> nil then raise ELocError.Create('fCommander.fCommander <> nil',GetPosition);
  end;
  if GetCommander.fCommander <> nil then raise ELocError.Create('GetCommander.fCommander <> nil',GetPosition);

  inc(fFlagAnim);
  if fCondition < UNIT_MIN_CONDITION then fThought := th_Eat; //th_Death checked in parent UpdateState
  if fFlagAnim mod 10 = 0 then UpdateHungerMessage;

  //Choose a random foe from our commander, then use that from here on (only if needed and not every tick)
  if GetCommander.ArmyInFight and (not (GetUnitAction is TUnitActionFight))
  and (not (GetUnitAction is TUnitActionStormAttack)) and not (fState = ws_Engage) then
    ChosenFoe := GetCommander.GetRandomFoeFromMembers
  else
    ChosenFoe := nil;

  if (fState = ws_Engage) and ((not GetCommander.ArmyInFight) or (not(GetUnitAction is TUnitActionWalkTo))) then
  begin
    fState := ws_None; //As soon as combat is over set the state back
    //Tell commanders to reposition after a fight
    if (fCommander = nil) and (not GetCommander.ArmyInFight) then
      OrderWalk(GetPosition); //Don't use halt because that returns us to fOrderLoc
  end;

  //Help out our fellow group members in combat if we are not fighting and someone else is
  if (fState <> ws_Engage) and (ChosenFoe <> nil) then
    if IsRanged then
    begin
      //Archers should abandon walk to start shooting if there is a foe
      if InRange(GetLength(NextPosition, ChosenFoe.GetPosition), GetFightMinRange, GetFightMaxRange)
      and(GetUnitAction is TUnitActionWalkTo)and(not TUnitActionWalkTo(GetUnitAction).DoingExchange) then
        AbandonWalk;
      //But if we are already idle then just start shooting right away
      if InRange(GetLength(GetPosition, ChosenFoe.GetPosition), GetFightMinRange, GetFightMaxRange)
        and(GetUnitAction is TUnitActionStay) then
      begin
        //Archers - If foe is reachable then turn in that direction and CheckForEnemy
        Direction := KMGetDirection(GetPosition, ChosenFoe.GetPosition);
        AnimStep := UnitStillFrames[Direction];
        CheckForEnemy;
      end;
    end
    else
    begin
      //Melee
      //todo: Try to avoid making a route through other units. Path finding should weight tiles with units high,
      //      tiles with fighting (locked) units very high so we route around the locked the battle rather
      //      than getting stuck trying to walk through fighting units (this will make the fighting system appear smarter)
      fOrder := wo_AttackUnit;
      fState := ws_Engage; //Special state so we don't issue this order continuously
      SetOrderTarget(ChosenFoe);
    end;

  //Override current action if there's an Order in queue paying attention
  //to unit WalkTo current position (let the unit arrive on next tile first!)
  //As well let the unit finish it's curent Attack action before taking a new order
  //This should make units response a bit delayed.


  //New walking order
  if (fOrder=wo_Walk) then begin
    //Change WalkTo
    if (GetUnitAction is TUnitActionWalkTo)and(not TUnitActionWalkTo(GetUnitAction).DoingExchange) then begin
      if GetUnitTask <> nil then FreeAndNil(fUnitTask); //e.g. TaskAttackHouse
      TUnitActionWalkTo(GetUnitAction).ChangeWalkTo(fOrderLoc.Loc, 0, fCommander <> nil, fTargetCanBeReached);
      fOrder := wo_None;
      fState := ws_Walking;
    end
    else
    //Set WalkTo
    if CanInterruptAction then
    begin
      if GetUnitTask <> nil then FreeAndNil(fUnitTask);
      if fCommander = nil then
        SetActionWalkToSpot(fOrderLoc.Loc)
      else
        SetActionWalkToNear(fOrderLoc.Loc, ua_Walk, fTargetCanBeReached);
      fOrder := wo_None;
      fState := ws_Walking;
    end;
  end;


  //Make sure attack order is still valid
  if (fOrder=wo_AttackUnit) and (GetOrderTarget = nil) then fOrder := wo_None;
  if (fOrder=wo_AttackHouse) and (GetOrderHouseTarget = nil) then fOrder := wo_None;

  //Change walk in order to attack
  if (fOrder=wo_AttackUnit) and (GetUnitAction is TUnitActionWalkTo) //If we are already walking then change the walk to the new location
  and(not TUnitActionWalkTo(GetUnitAction).DoingExchange) then begin
    if GetUnitTask <> nil then FreeAndNil(fUnitTask); //e.g. TaskAttackHouse
    //If we are not the commander then walk to near
    //todo: Do not WalkTo enemies location if we are archers, stay in place
    TUnitActionWalkTo(GetUnitAction).ChangeWalkTo(GetOrderTarget.NextPosition, GetFightMaxRange, fCommander <> nil, true, GetOrderTarget);
    fOrder := wo_None;
    if (fState <> ws_Engage) then fState := ws_Walking;
  end;

  //Take attack order
  if (fOrder=wo_AttackUnit)
  and CanInterruptAction
  and (GetOrderTarget <> nil)
  and not InRange(GetLength(NextPosition, GetOrderTarget.GetPosition), GetFightMinRange, GetFightMaxRange) then
  begin
    if GetUnitTask <> nil then FreeAndNil(fUnitTask); //e.g. TaskAttackHouse
    SetActionWalkToUnit(GetOrderTarget, GetFightMaxRange, ua_Walk);
    fOrder := wo_None;
    //todo: We need a ws_AttackingUnit to make this work properly for archers, so they know to shoot the enemy after finishing the walk and follow him if he keeps moving away.
    //todo: If an archer is too close to attack, move back
    if (fState <> ws_Engage) then fState := ws_Walking; //Difference between walking and attacking is not noticable, since when we reach the enemy we start fighting
  end;

  //Abandon walk so we can take attack house or storm attack order
  if ((fOrder=wo_AttackHouse) or (fOrder=wo_Storm)) and (GetUnitAction is TUnitActionWalkTo)
  and(not TUnitActionWalkTo(GetUnitAction).DoingExchange) then
    AbandonWalk;

  //Take attack house order
  if (fOrder=wo_AttackHouse) and CanInterruptAction then
  begin
    if GetUnitTask <> nil then FreeAndNil(fUnitTask); //e.g. TaskAttackHouse
    SetUnitTask := TTaskAttackHouse.Create(Self,GetOrderHouseTarget);
    fOrderLoc := KMPointDir(GetPosition,fOrderLoc.Dir); //Once the house is destroyed we will position where we are standing
    fOrder := wo_None;
  end;

  //Storm
  if (fOrder=wo_Storm) and CanInterruptAction then
  begin
    if GetUnitTask <> nil then FreeAndNil(fUnitTask); //e.g. TaskAttackHouse
    SetActionStorm(GetRow);
    fOrder := wo_None;
    fState := ws_None; //Not needed for storm attack
  end;

  if (fFlagAnim mod 5 = 0) and (fState <> ws_RepositionPause) then CheckForEnemy; //Split into seperate procedure so it can be called from other places

  Result:=true; //Required for override compatibility
  if Inherited UpdateState then exit;


  //This means we are idle, so make sure our direction is right and if we are commander reposition our troops if needed
  PositioningDone := true;
  if fCommander = nil then
  if (fState = ws_Walking) or (fState = ws_RepositionPause) then
  begin
    //Wait for self and all team members to be in position before we set fState to None (means we no longer worry about group position)
    if (not (GetUnitTask is TTaskAttackHouse)) and (not (GetUnitAction is TUnitActionWalkTo)) and
       (not KMSamePoint(GetPosition,fOrderLoc.Loc)) and fTerrain.Route_CanBeMade(GetPosition,fOrderLoc.Loc,GetDesiredPassability,0, false) then
    begin
      SetActionWalkToSpot(fOrderLoc.Loc); //Walk to correct position
      fState := ws_Walking;
    end;

    //If we have no crew then just exit
    if fMembers <> nil then
      //Tell everyone to reposition
      for i:=0 to fMembers.Count-1 do
        //Must wait for unit(s) to get into position before we have truely finished walking
        PositioningDone := TKMUnitWarrior(fMembers.Items[i]).RePosition and PositioningDone; //NOTE: RePosition function MUST go before PositioningDone variable otherwise it won't check the second value if the first is true!!!
  end;

  //Make sure we didn't get given an action above
  if GetUnitAction <> nil then exit;
    
  if fState = ws_Walking then
  begin
    fState := ws_RepositionPause; //Means we are in position and waiting until we turn
    SetActionLockedStay(4+KaMRandom(2),ua_Walk); //Pause 0.5 secs before facing right direction. Slight random amount so they don't look so much like robots ;) (actually they still do, we need to add more randoms)
    //Do not check for enemy, let archers face right direction first (enemies could be behind = unattackable)
  end
  else
  begin
    if fState = ws_RepositionPause then
    begin
      Direction := fOrderLoc.Dir; //Face the way we were told to after our walk (this creates a short pause before we fix direction)
      CheckForEnemy; //Important for archers, check for enemy once we are in position
      if PositioningDone then
        fState := ws_None;
    end;
    if (GetUnitAction = nil) then //CheckForEnemy could have assigned an action
    begin
      if PositioningDone then
        SetActionStay(50,ua_Walk) //Idle if we did not receive a walk action above
      else
        SetActionStay(5,ua_Walk);
    end;
  end;

  if fCurrentAction = nil then
    raise ELocError.Create('Warrior '+fResource.UnitDat[UnitType].UnitName+' has no action',GetPosition);
end;


procedure TKMUnitWarrior.Paint;

  procedure PaintFlag(XPaintPos, YPaintPos:single; AnimDir:TKMDirection; UnitTyp:TUnitType);
  var
    TeamColor: cardinal;
    FlagXPaintPos, FlagYPaintPos: single;
  begin
    FlagXPaintPos := XPaintPos + FlagXOffset[UnitGroups[UnitTyp],AnimDir]/CELL_SIZE_PX;
    FlagYPaintPos := YPaintPos + FlagYOffset[UnitGroups[UnitTyp],AnimDir]/CELL_SIZE_PX;

    if (fPlayers.Selected is TKMUnitWarrior) and (TKMUnitWarrior(fPlayers.Selected).GetCommander = Self) then
      TeamColor := $FFFFFFFF //Highlight with White color
    else
      TeamColor := fPlayers.Player[fOwner].FlagColor; //Normal color

    //In MapEd mode we borrow the anim step from terrain, as fFlagAnim is not updated
    if fGame.GameState = gsEditor then
      fRender.RenderUnitFlag(UnitTyp, 9, AnimDir, fTerrain.AnimStep, FlagXPaintPos, FlagYPaintPos, TeamColor, XPaintPos, YPaintPos, false)
    else
      fRender.RenderUnitFlag(UnitTyp, 9, AnimDir, fFlagAnim, FlagXPaintPos, FlagYPaintPos, TeamColor, XPaintPos, YPaintPos, false);
  end;

var
  AnimAct:byte;
  XPaintPos, YPaintPos: single;
  i,k:integer;
  UnitPosition: TKMPoint;
  DoesFit:boolean;
begin
  Inherited;
  if not fVisible then exit;
  AnimAct  := byte(fCurrentAction.GetActionType); //should correspond with UnitAction

  XPaintPos := fPosition.X + 0.5 + GetSlide(ax_X);
  YPaintPos := fPosition.Y + 1   + GetSlide(ax_Y);

  fRender.RenderUnit(fUnitType, AnimAct, Direction, AnimStep, XPaintPos, YPaintPos, fPlayers.Player[fOwner].FlagColor, true);

  if IsCommander and not IsDeadOrDying then
    PaintFlag(XPaintPos, YPaintPos, Direction, fUnitType); //Paint flag over the top of the unit

  //For half of the directions the flag should go UNDER the unit, so render the unit again as a child of the parent unit
  if Direction in [dir_SE, dir_S, dir_SW, dir_W] then
    fRender.RenderUnit(fUnitType, AnimAct, Direction, AnimStep, XPaintPos, YPaintPos, fPlayers.Player[fOwner].FlagColor, false);

  if fThought<>th_None then
    fRender.RenderUnitThought(fThought, XPaintPos, YPaintPos);

  //Paint members in MapEd mode
  if fMapEdMembersCount<>0 then
  for i:=1 to fMapEdMembersCount do begin
    UnitPosition := GetPositionInGroup2(GetPosition.X, GetPosition.Y, Direction, i+1, fUnitsPerRow, fTerrain.MapX, fTerrain.MapY, DoesFit);
    if not DoesFit then continue; //Don't render units that are off the map in the map editor
    XPaintPos := UnitPosition.X + 0.5; //MapEd units don't have sliding anyway
    YPaintPos := UnitPosition.Y + 1  ;
    fRender.RenderUnit(fUnitType, AnimAct, Direction, AnimStep, XPaintPos, YPaintPos, fPlayers.Player[fOwner].FlagColor, true);
  end;

  if SHOW_ATTACK_RADIUS then
    if IsRanged then
    for i:=-round(RANGE_BOWMAN_MAX)-1 to round(RANGE_BOWMAN_MAX) do
    for k:=-round(RANGE_BOWMAN_MAX)-1 to round(RANGE_BOWMAN_MAX) do
    if InRange(GetLength(i,k),RANGE_BOWMAN_MIN,RANGE_BOWMAN_MAX) then
    if fTerrain.TileInMapCoords(GetPosition.X+k,GetPosition.Y+i) then
      fRender.RenderDebugQuad(GetPosition.X+k,GetPosition.Y+i);
end;


end.
