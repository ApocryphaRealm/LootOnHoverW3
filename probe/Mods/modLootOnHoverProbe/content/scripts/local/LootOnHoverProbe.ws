// Loot on Hover - TEST PROBE, never shipped. Turns on the mod's on-screen trace (each log line also shown as a
// notification) so the in-game captures carry it. Test targets are bags of gear dropped from the inventory - the game's
// own path.

@wrapMethod(CInteractionsManager) function OnGuiInteractionChanged(newInteraction : CInteractionComponent)
{
	if (!theGame.lohShowTrace)
	{
		theGame.LohSetShowTrace(true);
		theGame.GetGuiManager().ShowNotification("LOH probe: trace on");
	}
	return wrappedMethod(newInteraction);
}
