// Loot on Hover - the loot window opens as soon as Geralt looks at something lootable, with no button press.
// Exploring or swimming only: never in combat.
//
//   Opened by looking (preview): Geralt keeps walking and swimming.
//     A takes the highlighted item, X takes everything, Y opens the window normally, B closes it.
//   Opened normally (after Y): the game's own window - Geralt stands still and the stick browses.
//     A takes, X takes everything, B closes.
//
// Annotations only: no game script is replaced. The window's own buttons (A take, B close) still come from the
// game's loot movie; X and Y reach the game as its attack (or dive) actions and are caught here while the window
// is up, so Geralt never swings or dives on them. Log channel: LootOnHover (-debugscripts).

@addField(CR4Game) var lohPendingPreview : bool;

@addMethod(CR4Game) public function LohSetPendingPreview(pending : bool)
{
	lohPendingPreview = pending;
}
@addField(CR4LootPopup) var lohPreview : bool;
@addField(CR4LootPopup) var lohHolding : bool;

function LohLog(msg : string)
{
	LogChannel('LootOnHover', msg);
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
	if (popup && (popup.lohPreview || popup.lohHolding))
		return popup;
	return NULL;
}

// The container the game's own A press would open the loot window for - nothing else.
function LohLootableTarget(interaction : CInteractionComponent) : W3Container
{
	var container : W3Container;

	if (!interaction)
		return NULL;
	if (interaction.GetActionName() != "Container")
		return NULL;
	container = (W3Container)interaction.GetEntity();
	if (!container)
		return NULL;
	if (!container.LohShowsLootWindow())
		return NULL;
	return container;
}

@addMethod(W3Container) public function LohShowsLootWindow() : bool
{
	var autoCorpseLoot : bool;

	if (!isEnabled || isInteractionBlocked || disableLooting || lockedByKey)
		return false;
	if (skipInventoryPanel || usedByCiri || (W3Herb)this)
		return false;
	if (IsEmpty())
		return false;
	autoCorpseLoot = theGame.GetInGameConfigWrapper().GetVarValue('Accessibility', 'AutoLoot') && (W3ActorRemains)this && !HasTag('lootbag');
	if (autoCorpseLoot)
		return false;
	return true;
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

	popup = LohGetPopup();
	if (popup && popup.lohPreview && popup.LohContainer() != container)
	{
		LohLog("looked away - closing the preview");
		theGame.ClosePopup('LootPopup');
		popup = NULL;
	}

	if (!container || popup || !LohPlayerCanHover())
		return result;

	LohLog("looking at " + container.GetReadableName() + " - opening the loot window");
	theGame.LohSetPendingPreview(true);
	container.OnInteraction("Container", thePlayer);
	if (theGame.lohPendingPreview)
	{
		// the press path did not reach ShowLoot (a quest container, a lock): leave the flag for no one
		theGame.LohSetPendingPreview(false);
	}
	return result;
}

// A while our window is open for this container: the window's own A has already taken the item - the game's
// interact press on the same button must not open the window again.
@wrapMethod(W3Container) function OnInteraction(actionName : string, activator : CEntity)
{
	var popup : CR4LootPopup;

	if (activator == thePlayer && !theGame.lohPendingPreview)
	{
		popup = LohGetOurPopup();
		if (popup && popup.LohContainer() == this)
		{
			LohLog("A with the window up - left to the window");
			return true;
		}
	}
	return wrappedMethod(actionName, activator);
}

@wrapMethod(CR4LootPopup) function OnConfigUI()
{
	var result : bool;

	lohPreview = theGame.lohPendingPreview;
	theGame.LohSetPendingPreview(false);
	lohHolding = false;

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

@addMethod(CR4LootPopup) function LohBlockButtons(block : bool)
{
	// B is the window's close: stop the same press jumping or rolling. X and Y are caught in the input wrappers.
	if (block)
	{
		thePlayer.BlockAction(EIAB_Jump, 'LootOnHover');
		thePlayer.BlockAction(EIAB_Roll, 'LootOnHover');
	}
	else
	{
		thePlayer.UnblockAction(EIAB_Jump, 'LootOnHover');
		thePlayer.UnblockAction(EIAB_Roll, 'LootOnHover');
	}
}

// Y: from the preview, open the window the normal way - Geralt stands still and the stick browses it.
@addMethod(CR4LootPopup) public function LohEnterNormal()
{
	if (!lohPreview)
		return;
	lohPreview = false;
	lohHolding = true;
	thePlayer.BlockAction(EIAB_Movement, 'LootOnHover');
	thePlayer.BlockAction(EIAB_RunAndSprint, 'LootOnHover');
	theGame.ForceUIAnalog(true);
	theGame.GetGuiManager().RequestMouseCursor(true);
	LohLog("Y - window opened normally");
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

	wasOurs = lohPreview || lohHolding;
	if (lohHolding)
	{
		thePlayer.UnblockAction(EIAB_Movement, 'LootOnHover');
		thePlayer.UnblockAction(EIAB_RunAndSprint, 'LootOnHover');
	}
	if (wasOurs)
	{
		LohBlockButtons(false);
	}
	lohPreview = false;
	lohHolding = false;

	result = wrappedMethod();
	if (wasOurs)
	{
		LohLog("window closed");
	}
	return result;
}

// The game's loot movie puts Take All on Y. With a controller, Y here means "open the window normally" (from the
// preview) and nothing once it is open; X is Take All. The keyboard's Space stays Take All.
@wrapMethod(CR4LootPopup) function OnPopupTakeAllItems()
{
	if ((lohPreview || lohHolding) && !theInput.LastUsedPCInput() && !lohTakingAll)
	{
		if (lohPreview)
		{
			LohEnterNormal();
		}
		return true;
	}
	wrappedMethod();
	return true;
}

@addField(CR4LootPopup) var lohTakingAll : bool;

// Every frame from the HUD: the preview closes the moment it should no longer be up.
@wrapMethod(CR4LootPopup) function UpdateInputContext()
{
	var target : W3Container;

	if (!lohPreview)
	{
		if (!lohHolding)
		{
			wrappedMethod();
		}
		return;
	}
	if (!LohPlayerCanHover())
	{
		LohLog("combat, a dialogue or a menu - closing the preview");
		ClosePopup();
		return;
	}
	target = LohLootableTarget(theGame.GetInteractionsManager().GetActiveInteraction());
	if (target != _container)
	{
		LohLog("target lost - closing the preview");
		ClosePopup();
	}
}

// --- X and Y while the window is up ---------------------------------------------------------------------------------

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

function LohOpenNormallyPressed() : bool
{
	var popup : CR4LootPopup;

	popup = LohGetOurPopup();
	if (!popup)
		return false;
	popup.LohEnterNormal();
	return true;
}

@wrapMethod(CPlayerInput) function OnCbtAttackLight(action : SInputAction)
{
	if (LohGetOurPopup())
	{
		if (IsPressed(action))
		{
			LohTakeAllPressed();
		}
		return true;
	}
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
	{
		if (IsPressed(action))
		{
			LohOpenNormallyPressed();
		}
		return true;
	}
	return wrappedMethod(action);
}

@wrapMethod(CPlayerInput) function OnCbtSpecialAttackHeavy(action : SInputAction)
{
	if (LohGetOurPopup())
		return true;
	return wrappedMethod(action);
}

// Swimming: X is Dive Down (take all) and B is Dive Up (the window's close) - neither may move Geralt.
@wrapMethod(CPlayerInput) function OnDiving(action : SInputAction)
{
	if (LohGetOurPopup())
	{
		if (action.aName == 'DiveDown' && IsPressed(action))
		{
			LohTakeAllPressed();
		}
		return true;
	}
	return wrappedMethod(action);
}
