class WOTCArchipelago_UISL_Avenger extends UIScreenListener;

// This happens regularly outside of the geoscape and in mostly non-intrusive places
// Popups in OnInit end up being scuffed and breaking transition animations
event OnReceiveFocus(UIScreen Screen)
{
	if (UIFacilityGrid(Screen) == none) return;
	`APCLIENT.DoChores();
	`APCLIENT.SendTick();
}
