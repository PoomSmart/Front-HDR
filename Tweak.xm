#import <AVFoundation/AVFoundation.h>
#import "../PS.h"

NSString *const PREF_PATH = @"/var/mobile/Library/Preferences/com.PS.FrontHDR.plist";
CFStringRef const PreferencesNotification = CFSTR("com.PS.FrontHDR.prefs");

static BOOL FrontHDR;

%group iOS6

%hook AVResolvedCaptureOptions

- (id)initWithCaptureOptionsDictionary:(NSDictionary *)captureOptionsDictionary
{
	if (FrontHDR) {
		NSMutableDictionary *cameraProperties = [captureOptionsDictionary mutableCopy];
		NSMutableDictionary *liveSourceOptions = [[cameraProperties objectForKey:@"LiveSourceOptions"] mutableCopy];
		if ([cameraProperties[@"OverridePrefixes"] isEqualToString:@"P:"]) {
			if ([liveSourceOptions[@"VideoPort"] isEqualToString:@"PortTypeFront"]) {
				[liveSourceOptions setObject:@YES forKey:@"HDR"];
				[liveSourceOptions setObject:@YES forKey:@"HDRSavePreBracketedFrameAsEV0"];
				[cameraProperties setObject:liveSourceOptions forKey:@"LiveSourceOptions"];
				return %orig(cameraProperties);
			}
		}
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
	}
	return %orig;
}

- (BOOL)supportsHDR
{
	return YES;
}

%end

%hook PLCameraView

- (void)_updateOverlayControls
{
	PLCameraController *cameraController = MSHookIvar<PLCameraController *>(self, "_cameraController");
	int camDevice = MSHookIvar<int>(cameraController, "_cameraDevice");
	if (camDevice == 1 && FrontHDR) {
		camDevice = 0;
		%orig;
		camDevice = 1;
	} else
		%orig;
}

- (void)_showSettings:(BOOL)settings sender:(id)sender
{
	%orig;
	if (settings && FrontHDR) {
		PLCameraSettingsView *settingsView = MSHookIvar<PLCameraSettingsView *>(self, "_settingsView");
		BOOL isFront = self.cameraDevice == 1 && self.cameraMode == 0;
		[MSHookIvar<PLCameraSettingsGroupView *>(settingsView, "_panoramaGroup") setAlpha:isFront ? 0.0f : 1.0f];
	}
}

- (BOOL)_optionsButtonShouldBeHidden
{
	return self.cameraDevice == 1 && self.cameraMode == 0 && FrontHDR ? NO : %orig;
}

%end

%end

%group iOS8_App

%hook CAMCaptureController

- (BOOL)supportsHDRForDevice:(AVCaptureDevice *)device mode:(int)mode
{
	BOOL isStillMode = (mode == 0 || mode == 4);
	BOOL isFront = self.cameraDevice == 1;
	return isStillMode && isFront && FrontHDR ? YES : %orig;
}

%end

%hook AVCaptureDevice

- (BOOL)isHDRSupported
{
	return YES;
}

%end

%hook AVCaptureDevice_FigRecorder

- (BOOL)isHDRSupported
{
	return YES;
}

%end

%hook AVCaptureFigVideoDevice_FigRecorder

- (BOOL)isHDRSupported
{
	return YES;
}

%end

%end

%group iOS8_process

%hook FigCaptureSourceFormat

- (BOOL)isHDRSupported
{
	return YES;
}

%end

%end

%group iOS78

%hook AVCaptureFigVideoDevice

- (BOOL)isHDRSupported
{
	return YES;
}

%end

%hook AVResolvedCaptureOptions

- (NSDictionary *)resolvedCaptureOptionsDictionary
{
	NSMutableDictionary *orig = [%orig mutableCopy];
	[orig setValue:@YES forKeyPath:@"LiveSourceOptions.HDR"];
	[orig setValue:@YES forKeyPath:@"LiveSourceOptions.HDRSavePreBracketedFrameAsEV0"];
	return orig;
}

%end

Boolean (*old_MGGetBoolAnswer)(CFStringRef);
Boolean replaced_MGGetBoolAnswer(CFStringRef string)
{
	#define k(key) CFEqual(string, CFSTR(key))
	if (k("FrontFacingCameraHDRCapability"))
		return FrontHDR;
	return old_MGGetBoolAnswer(string);
}

%end

BOOL is_mediaserverd()
{
	NSArray *args = [[NSClassFromString(@"NSProcessInfo") processInfo] arguments];
	NSUInteger count = [args count];
	if (count != 0) {
		NSString *executablePath = [args objectAtIndex:0];
		return [[executablePath lastPathComponent] isEqualToString:@"mediaserverd"];
	}
	return NO;
}

static void FrontHDRPrefs()
{
	NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH];
	FrontHDR = [prefs[@"FrontHDREnabled"] boolValue];
}

static void PostNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	system("killall Camera mediaserverd");
	FrontHDRPrefs();
}

%ctor
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	if (!is_mediaserverd())
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, PostNotification, PreferencesNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
	FrontHDRPrefs();
	if (isiOS7Up) {
		if (!is_mediaserverd()) {
			MSHookFunction((BOOL *)MSFindSymbol(NULL, "_MGGetBoolAnswer"), (BOOL *)replaced_MGGetBoolAnswer, (BOOL **)&old_MGGetBoolAnswer);
			%init(iOS78);
			if (isiOS8) {
				%init(iOS8_App);
			}
		}
		if (isiOS8) {
			dlopen("/System/Library/PrivateFrameworks/Celestial.framework/Celestial", RTLD_LAZY);
			%init(iOS8_process);
		}
	}
	else {
		if (!is_mediaserverd()) {
			%init(iOS6);
		}
	}
	[pool drain];
}
