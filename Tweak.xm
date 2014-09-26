#import <AVFoundation/AVFoundation.h>

#define PreferencesChangedNotification "com.PS.FrontHDR.prefs"
#define PREF_PATH @"/var/mobile/Library/Preferences/com.PS.FrontHDR.plist"
#define FrontHDR [[[NSDictionary dictionaryWithContentsOfFile:PREF_PATH] objectForKey:@"FrontHDREnabled"] boolValue]

@interface PLCameraController
@property(assign, nonatomic) int cameraDevice;
@property(assign, nonatomic) int cameraMode;
- (BOOL)isCapturingVideo;
@end

%group iOS6

#define isFrontCamera (self.cameraDevice == 1 && self.cameraMode == 0)

@interface PLCameraView
@property(assign, nonatomic) int cameraDevice;
@property(assign, nonatomic) int cameraMode;
@end

@interface PLCameraSettingsView
@end

@interface PLCameraSettingsGroupView : UIView
@end


%hook AVResolvedCaptureOptions

- (id)initWithCaptureOptionsDictionary:(NSDictionary *)captureOptionsDictionary
{
	NSMutableDictionary *cameraProperties = [captureOptionsDictionary mutableCopy];
	NSMutableDictionary *liveSourceOptions = [[cameraProperties objectForKey:@"LiveSourceOptions"] mutableCopy];
	if (FrontHDR) {
		if ([[cameraProperties objectForKey:@"OverridePrefixes"] isEqualToString:@"P:"]) {
			if ([[liveSourceOptions objectForKey:@"VideoPort"] isEqualToString:@"PortTypeFront"]) {
				[liveSourceOptions setObject:[NSNumber numberWithBool:YES] forKey:@"HDR"];
				[liveSourceOptions setObject:[NSNumber numberWithBool:YES] forKey:@"HDRSavePreBracketedFrameAsEV0"];
				[cameraProperties setObject:liveSourceOptions forKey:@"LiveSourceOptions"];
				return %orig(cameraProperties);
			}
			return %orig;
		}
		return %orig;
	}
	return %orig;
}

%end

%hook PLCameraController

- (BOOL)isHDREnabled
{
	if (FrontHDR) {
		if (MSHookIvar<BOOL>(self, "_hdrEnabled") && MSHookIvar<int>(self, "_cameraDevice") == 1)
			return [self isCapturingVideo] ? %orig : YES;
		return %orig;
	}
	return %orig;
}

- (BOOL)supportsHDR
{
	return isFrontCamera && FrontHDR ? YES : %orig;
}

%end

%hook PLCameraView

- (void)_updateOverlayControls
{
	PLCameraController *cameraController = MSHookIvar<PLCameraController *>(self, "_cameraController");
	#define camDevice MSHookIvar<int>(cameraController, "_cameraDevice")
	if (FrontHDR) {
		if (camDevice == 1) {
			camDevice = 0;
			%orig;
			camDevice = 1;
		} else
			%orig;
	} else
		%orig;
}

- (void)_showSettings:(BOOL)settings sender:(id)sender
{
	%orig;
	if (FrontHDR) {
		if (settings) {
			PLCameraSettingsView *settingsView = MSHookIvar<PLCameraSettingsView *>(self, "_settingsView");
			[MSHookIvar<PLCameraSettingsGroupView *>(settingsView, "_panoramaGroup") setAlpha:isFrontCamera ? 0.0 : 1.0];
		}
	}
}

- (BOOL)_optionsButtonShouldBeHidden
{
	return isFrontCamera && FrontHDR ? NO : %orig;
}

%end

%end

%group iOS78

%hook AVCaptureFigVideoDevice

- (BOOL)isHDRSupported
{
	return FrontHDR ? YES : %orig;
}

%end

%hook AVResolvedCaptureOptions

- (NSDictionary *)resolvedCaptureOptionsDictionary
{
	if (!FrontHDR)
		return %orig;
	NSMutableDictionary *orig = [%orig mutableCopy];
	[orig setValue:[NSNumber numberWithBool:YES] forKeyPath:@"LiveSourceOptions.HDR"];
	[orig setValue:[NSNumber numberWithBool:YES] forKeyPath:@"LiveSourceOptions.HDRSavePreBracketedFrameAsEV0"];
	return orig;
}

%end

Boolean (*old_MGGetBoolAnswer)(CFStringRef);
Boolean replaced_MGGetBoolAnswer(CFStringRef string)
{
	#define k(key) CFEqual(string, CFSTR(key))
	if (k("FrontFacingCameraHDRCapability") && FrontHDR)
		return YES;
	return old_MGGetBoolAnswer(string);
}

%end

%ctor
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	if (kCFCoreFoundationVersionNumber > 793.00) {
		MSHookFunction(((BOOL *)MSFindSymbol(NULL, "_MGGetBoolAnswer")), (BOOL *)replaced_MGGetBoolAnswer, (BOOL **)&old_MGGetBoolAnswer);
		%init(iOS78);
	}
	else {
		%init(iOS6);
	}
	[pool drain];
}
