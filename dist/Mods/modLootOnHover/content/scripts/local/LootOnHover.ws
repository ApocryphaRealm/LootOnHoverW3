// Loot on Hover - the loot window opens as soon as Geralt looks at anything he can loot - chests, barrels, crates,
// corpses, loot bags, herbs - with no button press. Exploring or swimming only: never in combat.
// The buttons below only do these things while the window is up; otherwise every button is the game's own.
//
//   Opened by looking (preview): Geralt keeps walking and swimming.
//     A takes the highlighted item, Y takes everything (the button the window's own hint shows), B closes it.
//     X does nothing. It opens and closes with no sound, no rumble and no camera move; taking items sounds as usual.
//     The game's Loot merge setting applies as it does to the A press: on, a body's window lists every body nearby.
//   Herbs: with "Gather herbs without the loot window" on (Options > Mods > Loot on Hover, the default) no window opens
//     for a herb - the game's own "Gather Ingredients" prompt stays and A gathers everything, the game's way.
//
// Annotations only: no game script is replaced. The window's own buttons (A take, B close) still come from the
// game's loot movie; A, Y and B are also the mod's own three input actions (LohTake, LohTakeAll, LohClose), and
// whatever else the player's map puts on A, X, Y and B is held off while the window is up - and, for the press that
// closes it (Y takes everything and closes), until that press is over, so Y never jumps or climbs on the way out.
// Log channel: LootOnHover (-debugscripts).

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

// Every HUD frame, window or not: puts the rumble back once the quiet time is over, and off again after a take; ends
// the hold on Jump and climbing once the press that closed the window is over.
@wrapMethod(CR4ScriptedHud) function UpdateLootPopupContext()
{
	wrappedMethod();
	if (theGame.lohRumbleOff || LohGetOurPopup())
	{
		theGame.LohUpdateRumble();
	}
	if (theGame.lohCloseHold)
	{
		theGame.LohUpdateCloseHold();
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

// --- the game's Loot merge setting ----------------------------------------------------------------------------------
// Options > Gameplay "Loot merge" (gameplay.xml var Gameplay / LootMergeEnabled) is applied by the window itself: the
// game's own CR4LootPopup.PopulateData - which the preview calls unchanged - gathers every body within 15 m into the
// list when the looked-at container is a body (W3ActorRemains, not a loot bag) and the setting is on, and keeps them in
// m_mergedContainers; take, take all (TakeAllAction) and close (OnContainerClosed) already walk that list. On, the hover
// window shows the merged loot exactly as the A press would; off, only the one container.
// What the mod adds: a body that is in this window counts as this window's target. Looking from one merged body to the
// next keeps the window instead of reopening it, and the looked-at body running out of items (its own items are listed
// first) does not close the window while the other bodies' items are still in it - the window closes itself when its
// list is empty, as the game's does.
@addMethod(CR4LootPopup) public function LohHolds(container : W3Container) : bool
{
	return container && (container == _container || m_mergedContainers.Contains(container));
}

@addMethod(CR4LootPopup) function LohIsOurTarget(interaction : CInteractionComponent) : bool
{
	var container : W3Container;

	if (!interaction)
		return false;
	container = (W3Container)interaction.GetEntity();
	if (!container || !container.LohIsLootInteraction(interaction))
		return false;
	return LohHolds(container);
}

// --- herbs without the loot window ----------------------------------------------------------------------------------
// The setting: Options > Mods > Loot on Hover, "Gather herbs without the loot window" (bin\config\r4game\
// user_config_matrix\pc\LootOnHover.xml: group LootOnHover, var GatherHerbsDirectly), on by default.
// What the game itself does on A at a herb (5.01, container.ws W3Container.OnInteraction -> ProcessLoot): a W3Herb, or
// any container that skips the inventory panel (W3RefillableContainer sets skipInventoryPanel by default), never gets a
// window - Geralt plays his gathering animation ('LootHerb'), TakeAllItems hands every item over with the game's own
// looted notifications and sound, and OnContainerClosed then empties its look. W3RefillableContainer.TakeAllItems marks
// it picked (isEmpty, no focus highlight, interaction off) and its 'Refill' timer regrows it. The merged loot list
// (Loot merge) never holds a herb: CR4LootPopup.PopulateData gathers only W3ActorRemains, and only into a body's window.
// So with the setting on the mod opens no window for a herb and does nothing on its A: the "Gather Ingredients" prompt
// is the game's own and so is the gathering. A preview that is up for something else closes the moment Geralt looks at
// a herb, so one A press can never both gather the herb and take from that window. Y and B are the player's own there
// (the mod's actions only act with its window up). Off, a herb gets the hover window exactly as in 1.0.1.
@addField(CR4Game) var lohHerbDefaultWritten : bool;

@addMethod(CR4Game) public function LohMarkHerbDefaultWritten()
{
	lohHerbDefaultWritten = true;
}

// On unless the player has switched it off. A value never set (a fresh install) is written as on, once, so the menu's
// switch shows what the mod does; with no menu file installed (a manager that skips bin\) it is simply on.
function LohGatherHerbsDirectly() : bool
{
	var cfg : CInGameConfigWrapper;
	var raw : string;

	cfg = theGame.GetInGameConfigWrapper();
	if (!cfg || cfg.GetGroupIdx("LootOnHover") < 0)
		return true;
	raw = cfg.GetVarValue('LootOnHover', 'GatherHerbsDirectly');
	if (raw == "" && !theGame.lohHerbDefaultWritten)
	{
		theGame.LohMarkHerbDefaultWritten();
		cfg.SetVarValue('LootOnHover', 'GatherHerbsDirectly', "true");
		theGame.SaveUserSettings();
		LohLog("'Gather herbs without the loot window' was never set - written as on (the default)");
	}
	return raw != "false";
}

// The interaction is a herb with something on it that the game's own A gathers with no window, and the setting is on.
function LohHerbGatheredByGame(interaction : CInteractionComponent) : bool
{
	var container : W3Container;

	if (!interaction)
		return false;
	container = (W3Container)interaction.GetEntity();
	if (!container || (W3DisplayMount)container)
		return false;
	if (!container.LohIsLootInteraction(interaction))
		return false;
	if (!((W3Herb)container))
	{
		// not the herb class: only the "Gather Ingredients" prompt on a container the game loots without the panel
		if (interaction.GetActionName() != "GatherHerbs" || !container.GetSkipInventoryPanel())
			return false;
	}
	if (!container.LohHasLoot())
		return false;
	return LohGatherHerbsDirectly();
}

// --- opening on hover -------------------------------------------------------------------------------------------

@wrapMethod(CInteractionsManager) function OnGuiInteractionChanged(newInteraction : CInteractionComponent)
{
	var result : bool;
	var popup : CR4LootPopup;
	var container : W3Container;
	var herb : bool;

	result = wrappedMethod(newInteraction);

	// A herb the game gathers with no window, and the setting is on: no window for it (see "herbs without the loot
	// window" above).
	herb = LohHerbGatheredByGame(newInteraction);
	if (herb)
	{
		container = NULL;
	}
	else
	{
		container = LohLootableTarget(newInteraction);
	}

	// Another lootable straight away: the preview moves to it - unless it is already in this window (a body the game's
	// Loot merge setting gathered into it). A herb gathered the game's way closes the preview at once, so A can only
	// gather the herb and never also takes from the window. Anything else (no target, a door, a person) is left to the
	// per-frame check, which closes the preview only once the target has stayed gone - running the interaction on A
	// drops the target for a moment.
	popup = LohGetPopup();
	if (popup && popup.lohPreview && (herb || (container && !popup.LohHolds(container))))
	{
		if (herb)
		{
			LohLog("a herb - closing the preview; A gathers the herb the game's way");
		}
		else
		{
			LohLog("another lootable - moving the preview");
		}
		theGame.ClosePopup('LootPopup');
		popup = NULL;
	}

	if (herb)
	{
		if (LohPlayerCanHover())
		{
			LohLog("looking at " + ((W3Container)newInteraction.GetEntity()).GetReadableName() + " - a herb: no window, the game's Gather prompt takes everything (setting on)");
		}
		return result;
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
	var data : W3LootPopupData;

	data = (W3LootPopupData)GetPopupInitData();
	lohPreview = data && theGame.LohTakePending(data.targetContainer);
	lohLostSince = 0;
	lohFlashTakeTime = 0;
	lohPadTakePending = false;

	if (!lohPreview)
	{
		return wrappedMethod();
	}

	// The preview: the game's own OnConfigUI less three things - no "gui_loot_popup_open" sound, no EMPTY_CONTEXT
	// (the game's window freezes Geralt), and no UI stick or mouse cursor - so the window opens silently and Geralt
	// keeps walking with it open. Everything else is the game's own, in the game's order.
	super.OnConfigUI();
	LohConfigPreview();
	if (!_container)
	{
		// the game closed it (a dialogue, a menu): nothing to undo
		lohPreview = false;
		return true;
	}
	lohOpenTime = theGame.GetEngineTimeAsSeconds();
	LohBlockButtons(true);
	LohLog("preview open (silent) - context " + theInput.GetContext() + ", Loot merge " + theGame.GetInGameConfigWrapper().GetVarValue('Gameplay', 'LootMergeEnabled') + ", " + IntToString(m_mergedContainers.Size()) + " nearby container(s) merged in");
	return true;
}

@addField(CR4LootPopup) var lohOpenTime : float;

// CR4LootPopup.OnConfigUI after its super call, without the open sound, the input context, ForceUIAnalog and the cursor.
@addMethod(CR4LootPopup) function LohConfigPreview()
{
	var lootPopupData : W3LootPopupData;
	var targetSize : float;

	setupFunctions();
	lootPopupData = (W3LootPopupData)GetPopupInitData();
	_tooltipDataProvider = new W3TooltipComponent in this;
	inputContextSet = false;

	if (lootPopupData && lootPopupData.targetContainer && !theGame.IsDialogOrCutscenePlaying() && !theGame.GetGuiManager().IsAnyMenu())
	{
		_container = lootPopupData.targetContainer;
		_tooltipDataProvider.initialize(thePlayer.GetInventory(), m_flashValueStorage);
		PopulateData();
		SignalLootingReactionEvent();
		if (StringToInt(theGame.GetInGameConfigWrapper().GetVarValue('Hud', 'HudSize'), 0) == 0)
		{
			targetSize = 0.85;
		}
		else
		{
			targetSize = 1;
		}
		m_fxSetWindowScale.InvokeSelfOneArg(FlashArgNumber(targetSize));
	}
	else
	{
		ClosePopup();
	}
}

// The loot movie's own sounds (the list's highlight as it first selects a row) are kept quiet for the first half second
// of a preview: the window comes up with no sound at all. Moving through the list afterwards sounds as usual.
@wrapMethod(CR4PopupBase) function OnPlaySoundEvent(soundName : string)
{
	var loot : CR4LootPopup;

	loot = (CR4LootPopup)this;
	if (loot && loot.lohPreview && theGame.GetEngineTimeAsSeconds() - loot.lohOpenTime < 0.5)
	{
		return true;
	}
	return wrappedMethod(soundName);
}

// While the window is up, the face buttons and the D-pad belong to it. The player's own map decides what else X, Y and B
// do (vanilla: attacks, jump, roll; a custom map: swords, signs, sprint, jump, diving) and what the D-pad does (the
// quick wheel, potions, the quick item, focus), so every one of those is held off here - through the game's action
// locks and, in the input wrappers below, by swallowing the press.
// Sprint is NOT an action lock: a blocked EIAB_Sprint makes the game treat Geralt as indoors (PlayerTick sets
// movementLockType = PMLT_NoSprint, and the Exploration state's camera tick then runs UpdateCameraInterior - the close
// indoor camera, 1.5 m behind him), which zoomed the camera in every time the window opened. CanSprint is held off
// instead (below), which leaves the camera alone.
@addMethod(CR4LootPopup) function LohBlockButtons(block : bool)
{
	if (block)
	{
		thePlayer.BlockAction(EIAB_Jump, 'LootOnHover');
		thePlayer.BlockAction(EIAB_Roll, 'LootOnHover');
		thePlayer.BlockAction(EIAB_Climb, 'LootOnHover');
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
		// a save made with an earlier build of this mod may still carry its sprint lock: lift it
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

// Y: take everything - the window's own Take All.
@addMethod(CR4LootPopup) public function LohTakeAll()
{
	LohLog("Y - take all");
	OnPopupTakeAllItems();
}

@wrapMethod(CR4LootPopup) function OnClosingPopup()
{
	var wasOurs : bool;

	wasOurs = lohPreview;
	if (lohPreview)
	{
		theGame.LohQuietFor(0.5);
		theGame.LohStartCloseHold();
		LohBlockButtons(false);
	}
	lohPreview = false;

	if (!wasOurs)
	{
		return wrappedMethod();
	}
	// The preview closes the game's way less the "gui_loot_popup_close" sound and the input context, cursor and UI
	// stick it never took.
	super.OnClosingPopup();
	LohClosePreview();
	LohLog("window closed (silent)");
	return true;
}

// CR4LootPopup.OnClosingPopup after its super call, without the close sound, the context restore, the cursor and ForceUIAnalog.
@addMethod(CR4LootPopup) function LohClosePreview()
{
	var i : int;

	SignalContainerClosedEvent();
	if (ShouldProcessTutorial('TutorialLootWindow'))
	{
		FactsAdd("tutorial_container_close", 1, 1);
	}
	if (_container)
	{
		_container.OnContainerClosed();
	}
	for (i = 0; i < m_mergedContainers.Size(); i += 1)
	{
		if (m_mergedContainers[i])
		{
			m_mergedContainers[i].OnContainerClosed();
		}
	}
	if (_tooltipDataProvider)
	{
		delete _tooltipDataProvider;
	}
}

// The game's loot movie puts Take All on Y, and its button hint shows Y (popup_loot.swf, HudLootItemModule
// setupFeedbackButtons: GAMEPAD_Y, KeyCode.SPACE). With a controller the mod's own LohTakeAll action on Y takes
// everything (it reaches the window whether or not the movie gets the press); the movie's own Y press is not passed on,
// so one press takes once. The keyboard's Space stays the movie's own Take All.
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
	now = theGame.GetEngineTimeAsSeconds();
	// still looking at this window's container, or at a body merged into it - emptied or not (the window closes itself
	// when its whole list is taken)
	if (LohIsOurTarget(theGame.GetInteractionsManager().GetActiveInteraction()))
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

// --- the press that closes the window ---------------------------------------------------------------------------------
// Y takes everything and closes the window inside its own press (B closes it too). The game then goes on handling that
// same press with the window gone - the other actions the player's map puts on the button (Jump, climbing, Axii,
// swimming up, sprint) - and the exploration code polls Jump and climbing every frame, while the action locks have
// just come off. So after one of the mod's windows closes:
//   - a press that arrives within a tenth of a second (the closing press's own dispatch) is held off, and
//   - Jump and climbing stay held off until their buttons are let go: a press that began with the window up never
//     jumps or climbs. The keyboard's Space (Take All, and Jump on the vanilla map) gets the same.
// The per-frame HUD check ends the hold once both are up, so a later press is never caught by it.
@addField(CR4Game) var lohClosedAt : float;
@addField(CR4Game) var lohCloseHold : bool;

@addMethod(CR4Game) public function LohStartCloseHold()
{
	lohClosedAt = GetEngineTimeAsSeconds();
	lohCloseHold = true;
}

@addMethod(CR4Game) public function LohJustClosed() : bool
{
	return lohCloseHold && GetEngineTimeAsSeconds() - lohClosedAt < 0.1;
}

@addMethod(CR4Game) public function LohUpdateCloseHold()
{
	if (!lohCloseHold || LohJustClosed())
		return;
	if (theInput.IsActionPressed('Jump') || theInput.IsActionPressed('ExplorationInteraction'))
		return;
	lohCloseHold = false;
	LohLog("the closing press is over - jump and climb free again");
}

@addMethod(CR4Game) public function LohJumpHeldBack() : bool
{
	if (LohGetOurPopup())
		return true;
	LohUpdateCloseHold();
	return lohCloseHold;
}

// A face-button action of the game's: held off while the window is up (press and release alike), and a press that
// arrives in the moment after one of the mod's windows closed (the press that closed it).
function LohHoldPress(action : SInputAction) : bool
{
	if (LohGetOurPopup())
		return true;
	return IsPressed(action) && theGame.LohJustClosed();
}

// Jump and climbing are polled by the exploration code (CExplorationInput), not sent as presses.
@wrapMethod(CExplorationInput) function IsJumpJustPressed() : bool
{
	if (theGame.LohJumpHeldBack())
		return false;
	return wrappedMethod();
}

@wrapMethod(CExplorationInput) function IsJumpPressed() : bool
{
	if (theGame.LohJumpHeldBack())
		return false;
	return wrappedMethod();
}

@wrapMethod(CExplorationInput) function IsExplorationJustPressed() : bool
{
	if (theGame.LohJumpHeldBack())
		return false;
	return wrappedMethod();
}

@wrapMethod(CExplorationInput) function IsExplorationPressed() : bool
{
	if (theGame.LohJumpHeldBack())
		return false;
	return wrappedMethod();
}

// seconds since the climb button was last pressed: "long ago" while it is held off
@wrapMethod(CExplorationInput) function GetExplorationLastJustPressedTime() : float
{
	if (theGame.LohJumpHeldBack())
		return 1000.0;
	return wrappedMethod();
}

// --- the pad's buttons while the window is up ---------------------------------------------------------------------------------
// The mod's own three actions on the pad's face buttons - LohTake (A), LohTakeAll (Y), LohClose (B) -
// added to input.settings beside the player's own bindings in Exploration and Swimming, so they follow the buttons
// whatever the player's map puts there. Outside the window they do nothing. X has no action of the mod's: while the
// window is up whatever the map puts on X is held off and X does nothing.

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

// The game's own handlers for whatever else sits on A, X, Y and B: swallowed while the window is up, and the press that
// closed it (LohHoldPress).
@wrapMethod(CPlayerInput) function OnCbtAttackLight(action : SInputAction)
{
	if (LohHoldPress(action))
		return true;
	return wrappedMethod(action);
}

@wrapMethod(CPlayerInput) function OnCbtSpecialAttackLight(action : SInputAction)
{
	if (LohHoldPress(action))
		return true;
	return wrappedMethod(action);
}

@wrapMethod(CPlayerInput) function OnCbtAttackHeavy(action : SInputAction)
{
	if (LohHoldPress(action))
		return true;
	return wrappedMethod(action);
}

@wrapMethod(CPlayerInput) function OnCbtSpecialAttackHeavy(action : SInputAction)
{
	if (LohHoldPress(action))
		return true;
	return wrappedMethod(action);
}

@wrapMethod(CPlayerInput) function OnCommSteelSword(action : SInputAction)
{
	if (LohHoldPress(action))
		return true;
	return wrappedMethod(action);
}

@wrapMethod(CPlayerInput) function OnCommSilverSword(action : SInputAction)
{
	if (LohHoldPress(action))
		return true;
	return wrappedMethod(action);
}

@wrapMethod(CPlayerInput) function OnSelectSign(action : SInputAction)
{
	if (LohHoldPress(action))
		return true;
	return wrappedMethod(action);
}

@wrapMethod(CPlayerInput) function OnCommSprint(action : SInputAction)
{
	if (LohHoldPress(action))
		return true;
	return wrappedMethod(action);
}

@wrapMethod(CPlayerInput) function OnCommSprintToggle(action : SInputAction)
{
	if (LohHoldPress(action))
		return true;
	return wrappedMethod(action);
}

// No sprinting while the window is up - held off at the game's own sprint check rather than by an EIAB_Sprint lock,
// which would switch the camera to the indoor one (see LohBlockButtons). W3PlayerWitcher's CanSprint calls this first.
@wrapMethod(CR4Player) function CanSprint(speed : float) : bool
{
	if (LohGetOurPopup())
		return false;
	return wrappedMethod(speed);
}

@wrapMethod(CPlayerInput) function OnCbtRoll(action : SInputAction)
{
	if (LohHoldPress(action))
		return true;
	return wrappedMethod(action);
}

@wrapMethod(CPlayerInput) function OnDiving(action : SInputAction)
{
	if (LohHoldPress(action))
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
