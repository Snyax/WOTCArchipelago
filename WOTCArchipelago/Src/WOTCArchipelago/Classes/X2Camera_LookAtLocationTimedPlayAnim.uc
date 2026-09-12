class X2Camera_LookAtLocationTimedPlayAnim extends X2Camera_LookAtLocationTimed;

var string Anim;
var float Rate;
var float Intensity;
var bool bLoop;
var float DistortUI;

function Activated(TPOV CurrentPOV, X2Camera PreviousActiveCamera, X2Camera_LookAt LastActiveLookAtCamera)
{
	PlayCameraAnim(Anim, Rate, Intensity, bLoop);
	if (DistortUI > 0) `PRES.StartDistortUI(DistortUI);

	super.Activated(CurrentPOV, PreviousActiveCamera, LastActiveLookAtCamera);
}

defaultproperties
{
	Rate=1.0
	Intensity=1.0
	bLoop=false
	DistortUI=0.0
}
