// Loot on Hover - the loot window opens as soon as Geralt looks at anything he can loot - chests, barrels, crates,
// corpses, loot bags, herbs - with no button press. Exploring or swimming only: never in combat.
// The buttons below only do these things while the window is up; otherwise every button is the game's own.
//
//   Opened by looking (preview): Geralt keeps walking and swimming.
//     A takes the highlighted item, X takes everything, B closes it. Y does nothing.
//
// Annotations only: no game script is replaced. The window's own buttons (A take, B close) still come from the
// game's loot movie; X and Y are the mod's own two input actions on those buttons, and whatever else the player's
// map puts on X, Y and B is held off while the window is up. Log channel: LootOnHover (-debugscripts).

// The container a preview was just asked for, and when: the window may build a frame later, so its OnConfigUI
// takes the preview only when it is for this container and the request is fresh.
@addField(CR4Game) var lohPendingContainer : W3Container;
@addField(CR4Game) var lohPendingTime : float;

@addMethod(CR4Game) public function LohSetPending(container : W3Container)
{
	lohPendingContainer = container;
	lohPendingTime = GetEngineTimeAsSeconds();
}

@addMethod(CR4Game) public function LohTakePending(container : W3Container) : bool
{
	var fresh : bool;

	fresh = container && lohPendingContainer == container && GetEngineTimeAsSeconds() - lohPendingTime < 2.0;
	lohPendingContainer = NULL;
	return fresh;
}

@addMethod(CR4Game) public function LohIsPending(container : W3Container) : bool
{
	return container && lohPendingContainer == container;
}

@addField(CR4LootPopup) var lohPreview : bool;

// Set only by the test probe: each log line is also shown on screen, so captures carry the trace.
@addField(CR4Game) var lohShowTrace : bool;

@addMethod(CR4Game) public function LohSetShowTrace(show : bool)
{
	lohShowTrace = show;
}

@addField(CR4Game) var lohTraceLines : array<string>;

@addMethod(CR4Game) public function LohTrace(msg : string)
{
	var text : string;
	var i : int;

	lohTraceLines.PushBack(FloatToStringPrec(GetEngineTimeAsSeconds(), 1) + " " + msg);
	while (lohTraceLines.Size() > 6)
	{
		lohTraceLines.Erase(0);
	}
	for (i = 0; i < lohTraceLines.Size(); i += 1)
	{
		if (i > 0)
			text += "<br>";
		text += lohTraceLines[i];
	}
	GetGuiManager().ShowNotification("LOH<br>" + text);
}

function LohLog(msg : string)
{
	LogChannel('LootOnHover', msg);
	if (theGame.lohShowTrace)
	{
		theGame.LohTrace(msg);
	}
}

function LohPlayerCanHover() : bool
{
	var stateName : name;

	if (!thePlayer || !GetWitcherPlayer())
		return false;
	if ((W3ReplacerCiri)thePlayer)
		return false;
	if (thePlayer.IsInCombat())
		return false;
	if (theGame.IsDialogOrCutscenePlaying() || theGame.GetGuiManager().IsAnyMenu())
		return false;
	stateName = thePlayer.GetCurrentStateName();
	return stateName == 'Exploration' || stateName == 'Swimming';
}

function LohGetPopup() : CR4LootPopup
{
	return (CR4LootPopup)theGame.GetGuiManager().GetPopup('LootPopup');
}

// The loot window that is up right now, if this mod opened it.
function LohGetOurPopup() : CR4LootPopup
{
	var popup : CR4LootPopup;

	popup = LohGetPopup();
	if (popup && popup.lohPreview)
		return popup;
	return NULL;
}

// Anything with a loot window behind it: every lootable in the game is a W3Container (chests, barrels, crates, corpses,
// loot bags, herbs, beehives, treasure-hunt stashes). Armour and weapon stands are W3Containers too, but they hold
// gear Geralt hangs up, not loot.
function LohLootableTarget(interaction : CInteractionComponent) : W3Container
{
	var container : W3Container;

	if (!interaction)
		return NULL;
	container = (W3Container)interaction.GetEntity();
	if (!container || (W3DisplayMount)container)
		return NULL;
	if (!container.LohIsLootInteraction(interaction))
		return NULL;
	if (!container.LohHasLoot())
		return NULL;
	return container;
}

// The container's own loot prompt - not its lock, medallion or examine prompts.
@addMethod(W3Container) public function LohIsLootInteraction(interaction : CInteractionComponent) : bool
{
	var action : string;

	if (lootInteractionComponent && interaction == lootInteractionComponent)
		return true;
	action = interaction.GetActionName();
	return action == "Container" || action == "GatherHerbs";
}

@addMethod(W3Container) public function LohHasLoot() : bool
{
	var autoCorpseLoot : bool;

	if (!isEnabled || isInteractionBlocked || disableLooting || lockedByKey || usedByCiri)
		return false;
	if (IsEmpty())
		return false;
	// the player's own Auto-loot corpses setting: those corpses are emptied on A, with no window by choice
	autoCorpseLoot = theGame.GetInGameConfigWrapper().GetVarValue('Accessibility', 'AutoLoot') && (W3ActorRemains)this && !HasTag('lootbag');
	if (autoCorpseLoot)
		return false;
	return true;
}

// What the A press does before it shows the window (container.ws OnInteraction), then the window itself - without
// the press's animation: a corpse or animated chest would otherwise have Geralt kneel at everything he glances at.
@addMethod(W3Container) public function LohOpenPreview()
{
	var schematics : array< name >;

	if (StrLen(factOnContainerOpened) > 0 && !FactsDoesExist(factOnContainerOpened))
	{
		FactsAdd(factOnContainerOpened, 1, -1);
	}
	if (FactsQuerySum("NewGamePlus") > 0)
	{
		schematics = GetWitcherPlayer().GetCraftingSchematicsNames();
		AddWolfNewGamePlusSchematics();
		KeepWolfWitcherSetSchematics(schematics);
	}
	ProcessSpoonCollector(thePlayer);
	InjectItemsOnLevels();
	if (IsEmpty())
		return;
	theGame.LohSetPending(this);
	theGame.LohQuietFor(1.0);
	ShowLoot();
}

// --- no rumble on hover ----------------------------------------------------------------------------------------------
// From the moment the window is asked for until half a second after it closes, the pad's vibration is switched off
// (theGame.SetVibrationEnabled, the switch the game's quests use) and then put back as it was; a player whose own
// vibration setting is off is never touched. A take (A or X) lets the game's own take rumble through for a moment -
// the vanilla game rumbles when herbs and armour are taken.
@addField(CR4Game) var lohRumbleOff : bool;
@addField(CR4Game) var lohQuietUntil : float;
@addField(CR4Game) var lohTakeRumbleUntil : float;

@addMethod(CR4Game) public function LohQuietFor(seconds : float)
{
	lohQuietUntil = MaxF(lohQuietUntil, GetEngineTimeAsSeconds() + seconds);
	LohUpdateRumble();
}

@addMethod(CR4Game) public function LohLetTakeRumble()
{
	lohTakeRumbleUntil = GetEngineTimeAsSeconds() + 0.75;
	LohUpdateRumble();
}

@addMethod(CR4Game) public function LohUpdateRumble()
{
	var now : float;
	var quiet : bool;

	now = GetEngineTimeAsSeconds();
	quiet = (LohGetOurPopup() || now < lohQuietUntil) && now >= lohTakeRumbleUntil;
	if (quiet && !lohRumbleOff && IsVibrationEnabled())
	{
		SetVibrationEnabled(false);
		lohRumbleOff = true;
		LohLog("rumble off");
	}
	else if (!quiet && lohRumbleOff)
	{
		SetVibrationEnabled(true);
		lohRumbleOff = false;
		LohLog("rumble back on");
	}
}

// Every HUD frame, window or not: puts the rumble back once the quiet time is over, and off again after a take.
@wrapMethod(CR4ScriptedHud) function UpdateLootPopupContext()
{
	wrappedMethod();
	if (theGame.lohRumbleOff || LohGetOurPopup())
	{
		theGame.LohUpdateRumble();
	}
}

// A herb (any refillable container) is only marked picked - empty look, regrow timer - by its take-everything path.
@addMethod(W3RefillableContainer) public function LohMarkPickedIfEmpty()
{
	var inv : CInventoryComponent;

	inv = GetInventory();
	if (!isEmpty && (!inv || inv.IsEmpty(true)))
	{
		TakeAllItems();
	}
}

@addMethod(CR4LootPopup) public function LohContainer() : W3Container
{
	return _container;
}

// --- opening on hover -------------------------------------------------------------------------------------------

@wrapMethod(CInteractionsManager) function OnGuiInteractionChanged(newInteraction : CInteractionComponent)
{
	var result : bool;
	var popup : CR4LootPopup;
	var container : W3Container;

	result = wrappedMethod(newInteraction);

	container = LohLootableTarget(newInteraction);

	// Another lootable straight away: the preview moves to it. Anything else (no target, a door, a person) is left to
	// the per-frame check, which closes the preview only once the target has stayed gone - running the interaction
	// on A drops the target for a moment.
	popup = LohGetPopup();
	if (popup && popup.lohPreview && container && popup.LohContainer() != container)
	{
		LohLog("another lootable - moving the preview");
		theGame.ClosePopup('LootPopup');
		popup = NULL;
	}

	if (!container || popup || !LohPlayerCanHover())
		return result;

	LohLog("looking at " + container.GetReadableName() + " - opening the loot window");
	container.LohOpenPreview();
	return result;
}

// A while our window is open for this container: the window (or the mod's own A action) takes the item - the game's
// interact press on the same button must not run as well. Every container class with its own A handler is wrapped:
// an animated container's (corpses, loot bags, some chests) would otherwise play Geralt's kneel, which closes the
// window and reopens it the normal way.
function LohSwallowA(container : W3Container, activator : CEntity) : bool
{
	var popup : CR4LootPopup;

	if (activator != thePlayer)
		return false;
	popup = LohGetOurPopup();
	if (popup && popup.LohContainer() == container)
	{
		LohLog("A with the window up - left to the window");
		return true;
	}
	return false;
}

@wrapMethod(W3Container) function OnInteraction(actionName : string, activator : CEntity)
{
	if (LohSwallowA(this, activator))
		return true;
	return wrappedMethod(actionName, activator);
}

@wrapMethod(W3AnimatedContainer) function OnInteraction(actionName : string, activator : CEntity)
{
	if (LohSwallowA(this, activator))
		return true;
	return wrappedMethod(actionName, activator);
}

@wrapMethod(W3CookingPlace) function OnInteraction(actionName : string, activator : CEntity)
{
	if (LohSwallowA(this, activator))
		return true;
	return wrappedMethod(actionName, activator);
}

@wrapMethod(CBeehiveEntity) function OnInteraction(actionName : string, activator : CEntity)
{
	if (LohSwallowA(this, activator))
		return true;
	return wrappedMethod(actionName, activator);
}

@wrapMethod(W3BeehiveStandingEntity) function OnInteraction(actionName : string, activator : CEntity)
{
	if (LohSwallowA(this, activator))
		return true;
	return wrappedMethod(actionName, activator);
}

@wrapMethod(CR4LootPopup) function OnConfigUI()
{
	var result : bool;

	var data : W3LootPopupData;

	data = (W3LootPopupData)GetPopupInitData();
	lohPreview = data && theGame.LohTakePending(data.targetContainer);
	lohLostSince = 0;
	lohFlashTakeTime = 0;
	lohPadTakePending = false;

	result = wrappedMethod();

	if (lohPreview)
	{
		if (!_container)
		{
			// the game closed it (a dialogue, a menu): nothing to undo
			lohPreview = false;
			return result;
		}
		// The game's window freezes Geralt (EMPTY_CONTEXT), hands the stick to the window and shows the cursor.
		// The preview gives all three back, so he keeps walking with it open.
		if (inputContextSet && theInput.GetContext() == 'EMPTY_CONTEXT')
		{
			theInput.RestoreContext('EMPTY_CONTEXT', false);
		}
		inputContextSet = false;
		theGame.ForceUIAnalog(false);
		theGame.GetGuiManager().RequestMouseCursor(false);
		LohBlockButtons(true);
		LohLog("preview open - context " + theInput.GetContext());
	}
	return result;
}

// While the window is up, the face buttons and the D-pad belong to it. The player's own map decides what else X, Y and B
// do (vanilla: attacks, jump, roll; a custom map: swords, signs, sprint, jump, diving) and what the D-pad does (the
// quick wheel, potions, the quick item, focus), so every one of those is held off here - through the game's action
// locks and, in the input wrappers below, by swallowing the press.
@addMethod(CR4LootPopup) function LohBlockButtons(block : bool)
{
	if (block)
	{
		thePlayer.BlockAction(EIAB_Jump, 'LootOnHover');
		thePlayer.BlockAction(EIAB_Roll, 'LootOnHover');
		thePlayer.BlockAction(EIAB_Climb, 'LootOnHover');
		thePlayer.BlockAction(EIAB_Sprint, 'LootOnHover');
		thePlayer.BlockAction(EIAB_DrawWeapon, 'LootOnHover');
		thePlayer.BlockAction(EIAB_Signs, 'LootOnHover');
		thePlayer.BlockAction(EIAB_LightAttacks, 'LootOnHover');
		thePlayer.BlockAction(EIAB_HeavyAttacks, 'LootOnHover');
		thePlayer.BlockAction(EIAB_Dive, 'LootOnHover');
		thePlayer.BlockAction(EIAB_RadialMenu, 'LootOnHover');
		thePlayer.BlockAction(EIAB_QuickSlots, 'LootOnHover');
		thePlayer.BlockAction(EIAB_UsableItem, 'LootOnHover');
		thePlayer.BlockAction(EIAB_ThrowBomb, 'LootOnHover');
		thePlayer.BlockAction(EIAB_Crossbow, 'LootOnHover');
	}
	else
	{
		thePlayer.UnblockAction(EIAB_Jump, 'LootOnHover');
		thePlayer.UnblockAction(EIAB_Roll, 'LootOnHover');
		thePlayer.UnblockAction(EIAB_Climb, 'LootOnHover');
		thePlayer.UnblockAction(EIAB_Sprint, 'LootOnHover');
		thePlayer.UnblockAction(EIAB_DrawWeapon, 'LootOnHover');
		thePlayer.UnblockAction(EIAB_Signs, 'LootOnHover');
		thePlayer.UnblockAction(EIAB_LightAttacks, 'LootOnHover');
		thePlayer.UnblockAction(EIAB_HeavyAttacks, 'LootOnHover');
		thePlayer.UnblockAction(EIAB_Dive, 'LootOnHover');
		thePlayer.UnblockAction(EIAB_RadialMenu, 'LootOnHover');
		thePlayer.UnblockAction(EIAB_QuickSlots, 'LootOnHover');
		thePlayer.UnblockAction(EIAB_UsableItem, 'LootOnHover');
		thePlayer.UnblockAction(EIAB_ThrowBomb, 'LootOnHover');
		thePlayer.UnblockAction(EIAB_Crossbow, 'LootOnHover');
	}
}

// X: take everything - the window's own Take All.
@addMethod(CR4LootPopup) public function LohTakeAll()
{
	LohLog("X - take all");
	OnPopupTakeAllItems();
}

@wrapMethod(CR4LootPopup) function OnClosingPopup()
{
	var result : bool;
	var wasOurs : bool;

	wasOurs = lohPreview;
	if (lohPreview)
	{
		theGame.LohQuietFor(0.5);
		LohBlockButtons(false);
	}
	lohPreview = false;

	result = wrappedMethod();
	if (wasOurs)
	{
		LohLog("window closed");
	}
	return result;
}

// The game's loot movie puts Take All on Y. With a controller, X is Take All here and Y does nothing.
// The keyboard's Space stays Take All.
@wrapMethod(CR4LootPopup) function OnPopupTakeAllItems()
{
	if (lohPreview && !theInput.LastUsedPCInput() && !lohTakingAll)
	{
		return true;
	}
	if (lohPreview)
	{
		theGame.LohLetTakeRumble();
	}
	wrappedMethod();
	return true;
}

@addField(CR4LootPopup) var lohTakingAll : bool;

@addField(CR4LootPopup) var lohLostSince : float;
@addField(CR4LootPopup) var lohFlashTakeTime : float;
@addField(CR4LootPopup) var lohPadTakeTime : float;
@addField(CR4LootPopup) var lohPadTakePending : bool;

// The window's own movie takes the highlighted item on A when it gets the press; the mod's A action takes it when the
// movie did not, so one press takes one item either way.
@wrapMethod(CR4LootPopup) function OnPopupTakeItem(Id : int)
{
	lohFlashTakeTime = theGame.GetEngineTimeAsSeconds();
	lohPadTakePending = false;
	if (lohPreview)
	{
		theGame.LohLetTakeRumble();
	}
	return wrappedMethod(Id);
}

@addMethod(CR4LootPopup) public function LohPadTake()
{
	var now : float;

	now = theGame.GetEngineTimeAsSeconds();
	if (lohFlashTakeTime > 0 && now - lohFlashTakeTime < 0.3)
		return;
	lohPadTakeTime = now;
	lohPadTakePending = true;
}

@addMethod(CR4LootPopup) function LohPadTakeCheck()
{
	var index : int;

	if (!lohPadTakePending || theGame.GetEngineTimeAsSeconds() - lohPadTakeTime < 0.15)
		return;
	lohPadTakePending = false;
	if (m_cachedItems.Size() == 0)
		return;
	index = Clamp(m_indexToSelect, 0, m_cachedItems.Size() - 1);
	LohLog("A - take item " + index);
	OnPopupTakeItem(index);
}

// Every frame from the HUD.
@wrapMethod(CR4LootPopup) function UpdateInputContext()
{
	var target : W3Container;
	var now : float;

	if (!lohPreview)
	{
		wrappedMethod();
		return;
	}
	LohPadTakeCheck();
	if (!LohPlayerCanHover())
	{
		LohLog("combat, a dialogue or a menu - closing the preview");
		ClosePopup();
		return;
	}
	target = LohLootableTarget(theGame.GetInteractionsManager().GetActiveInteraction());
	now = theGame.GetEngineTimeAsSeconds();
	if (target == _container)
	{
		lohLostSince = 0;
		return;
	}
	if (lohLostSince <= 0)
	{
		lohLostSince = now;
		return;
	}
	if (now - lohLostSince > 0.35)
	{
		LohLog("target lost - closing the preview");
		ClosePopup();
	}
}

// --- the pad's buttons while the window is up ---------------------------------------------------------------------------------
// The mod's own three actions on the pad's face buttons - LohTake (A), LohTakeAll (X), LohClose (B) -
// added to input.settings beside the player's own bindings in Exploration and Swimming, so they follow the buttons
// whatever the player's map puts there. Outside the window they do nothing.

function LohTakeAllPressed() : bool
{
	var popup : CR4LootPopup;

	popup = LohGetOurPopup();
	if (!popup)
		return false;
	popup.lohTakingAll = true;
	popup.LohTakeAll();
	popup = LohGetPopup();
	if (popup)
	{
		popup.lohTakingAll = false;
	}
	return true;
}

@wrapMethod(CPlayerInput) function Initialize(isFromLoad : bool, optional previousInput : CPlayerInput)
{
	wrappedMethod(isFromLoad, previousInput);
	theInput.RegisterListener(this, 'OnLohTake', 'LohTake');
	theInput.RegisterListener(this, 'OnLohTakeAll', 'LohTakeAll');
	theInput.RegisterListener(this, 'OnLohClose', 'LohClose');
}

@addMethod(CPlayerInput) event OnLohTake(action : SInputAction)
{
	var popup : CR4LootPopup;

	if (IsPressed(action))
	{
		popup = LohGetOurPopup();
		if (popup)
		{
			popup.LohPadTake();
		}
	}
}

@addMethod(CPlayerInput) event OnLohClose(action : SInputAction)
{
	if (IsPressed(action) && LohGetOurPopup())
	{
		LohLog("B - close");
		theGame.ClosePopup('LootPopup');
	}
}

@addMethod(CPlayerInput) event OnLohTakeAll(action : SInputAction)
{
	if (IsPressed(action))
	{
		LohTakeAllPressed();
	}
}

// The game's own handlers for whatever else sits on X, Y and B: swallowed while the window is up.
@wrapMethod(CPlayerInput) function OnCbtAttackLight(action : SInputAction)
{
	if (LohGetOurPopup())
		return true;
	return wrappedMethod(action);
}

@wrapMethod(CPlayerInput) function OnCbtSpecialAttackLight(action : SInputAction)
{
	if (LohGetOurPopup())
		return true;
	return wrappedMethod(action);
}

@wrapMethod(CPlayerInput) function OnCbtAttackHeavy(action : SInputAction)
{
	if (LohGetOurPopup())
		return true;
	return wrappedMethod(action);
}

@wrapMethod(CPlayerInput) function OnCbtSpecialAttackHeavy(action : SInputAction)
{
	if (LohGetOurPopup())
		return true;
	return wrappedMethod(action);
}

@wrapMethod(CPlayerInput) function OnCommSteelSword(action : SInputAction)
{
	if (LohGetOurPopup())
		return true;
	return wrappedMethod(action);
}

@wrapMethod(CPlayerInput) function OnCommSilverSword(action : SInputAction)
{
	if (LohGetOurPopup())
		return true;
	return wrappedMethod(action);
}

@wrapMethod(CPlayerInput) function OnSelectSign(action : SInputAction)
{
	if (LohGetOurPopup())
		return true;
	return wrappedMethod(action);
}

@wrapMethod(CPlayerInput) function OnCommSprint(action : SInputAction)
{
	if (LohGetOurPopup())
		return true;
	return wrappedMethod(action);
}

@wrapMethod(CPlayerInput) function OnCommSprintToggle(action : SInputAction)
{
	if (LohGetOurPopup())
		return true;
	return wrappedMethod(action);
}

@wrapMethod(CPlayerInput) function OnCbtRoll(action : SInputAction)
{
	if (LohGetOurPopup())
		return true;
	return wrappedMethod(action);
}

@wrapMethod(CPlayerInput) function OnDiving(action : SInputAction)
{
	if (LohGetOurPopup())
		return true;
	return wrappedMethod(action);
}

// The D-pad moves through the window's list; whatever the player's map also puts there - the quick wheel, the potions,
// the quick item, focus - is swallowed while the window is up. Only a press that began with the window up is held off,
// release and all: a button already held when the window opened gets its release, so nothing is left half done.
@addField(CPlayerInput) var lohHeldOff : array<name>;

@addMethod(CPlayerInput) function LohHoldOff(action : SInputAction) : bool
{
	if (IsReleased(action))
	{
		if (lohHeldOff.Contains(action.aName))
		{
			lohHeldOff.Remove(action.aName);
			return true;
		}
		return false;
	}
	if (!LohGetOurPopup())
	{
		// a press with the window down: any release still owed from an earlier window is stale
		lohHeldOff.Remove(action.aName);
		return false;
	}
	if (IsPressed(action) && !lohHeldOff.Contains(action.aName))
	{
		lohHeldOff.PushBack(action.aName);
	}
	return true;
}

@wrapMethod(CR4HudModuleRadialMenu) function OnRadialMenu(action : SInputAction)
{
	if (thePlayer.GetInputHandler().LohHoldOff(action))
		return true;
	return wrappedMethod(action);
}

@wrapMethod(CPlayerInput) function OnCommDrinkPotion1(action : SInputAction)
{
	if (LohHoldOff(action))
		return true;
	return wrappedMethod(action);
}

@wrapMethod(CPlayerInput) function OnCommDrinkPotion2(action : SInputAction)
{
	if (LohHoldOff(action))
		return true;
	return wrappedMethod(action);
}

@wrapMethod(CPlayerInput) function OnCommDrinkpotionUpperHeld(action : SInputAction)
{
	if (LohHoldOff(action))
		return true;
	return wrappedMethod(action);
}

@wrapMethod(CPlayerInput) function OnCommDrinkpotionLowerHeld(action : SInputAction)
{
	if (LohHoldOff(action))
		return true;
	return wrappedMethod(action);
}

@wrapMethod(CPlayerInput) function OnCbtThrowItem(action : SInputAction)
{
	if (LohHoldOff(action))
		return true;
	return wrappedMethod(action);
}

@wrapMethod(CPlayerInput) function OnCbtThrowItemHold(action : SInputAction)
{
	if (LohHoldOff(action))
		return true;
	return wrappedMethod(action);
}

@wrapMethod(CPlayerInput) function OnExpFocus(action : SInputAction)
{
	if (LohHoldOff(action))
		return true;
	return wrappedMethod(action);
}

// A herb emptied one item at a time through the window: mark it picked before the game checks it on close.
@wrapMethod(W3Container) function OnContainerClosed()
{
	var refillable : W3RefillableContainer;

	refillable = (W3RefillableContainer)this;
	if (refillable)
	{
		refillable.LohMarkPickedIfEmpty();
	}
	wrappedMethod();
}

// The face buttons' other actions are held off while the window is up; the game would announce each attempt
// ("You cannot do that now") - those messages are kept quiet while the window is up.
@wrapMethod(CR4Player) function DisplayActionDisallowedHudMessage(action : EInputActionBlock, optional isCombatLock : bool, optional isPlaceLock : bool, optional isTimeLock : bool, optional isDangerous : bool)
{
	if (LohGetOurPopup())
		return;
	wrappedMethod(action, isCombatLock, isPlaceLock, isTimeLock, isDangerous);
}
