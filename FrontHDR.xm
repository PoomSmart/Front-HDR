#import <substrate.h>

static NSDictionary *prefDict = nil;

#define PreferencesChangedNotification "com.PS.FrontHDR.settingschanged"
#define PREF_PATH @"/var/mobile/Library/Preferences/com.PS.FrontHDR.plist"
#define FrontHDR [[prefDict objectForKey:@"FrontHDREnabled"] boolValue]

static BOOL isFrontCamera;

@interface PLCameraController
- (BOOL)isCapturingVideo;
@end

static void PreferencesChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	[prefDict release];
	prefDict = [[NSDictionary alloc] initWithContentsOfFile:PREF_PATH];
}


%hook AVResolvedCaptureOptions

- (id)initWithCaptureOptionsDictionary:(NSDictionary *)captureOptionsDictionary
{
	NSMutableDictionary *cameraProperties = [captureOptionsDictionary mutableCopy];
	NSMutableDictionary *liveSourceOptions = [[cameraProperties objectForKey:@"LiveSourceOptions"] mutableCopy];
	if ([[[cameraProperties objectForKey:@"OverridePrefixes"] description] isEqualToString:@"P:"] &&
		[[[liveSourceOptions objectForKey:@"VideoPort"] description] isEqualToString:@"PortTypeFront"] &&
		FrontHDR)
		{
			[liveSourceOptions setObject:[NSNumber numberWithBool:YES] forKey:@"HDR"];
			[liveSourceOptions setObject:[NSNumber numberWithBool:YES] forKey:@"HDRSavePreBracketedFrameAsEV0"];
			[cameraProperties setObject:liveSourceOptions forKey:@"LiveSourceOptions"];
			return %orig(cameraProperties);
		}
	return %orig;
}

%end

%hook PLCameraController

- (BOOL)isHDREnabled
{
	if (FrontHDR && MSHookIvar<BOOL>(self, "_hdrEnabled") && MSHookIvar<int>(self, "_cameraDevice") == 1) {
		return [self isCapturingVideo] ? %orig : YES;
	}
	return %orig;
}

- (BOOL)supportsHDR
{
	return isFrontCamera && FrontHDR ? YES : %orig;
}

- (void)_setCameraMode:(int)arg1 cameraDevice:(int)arg2
{
	if (arg1 == 0 && arg2 == 1)
		isFrontCamera = YES;
	else
		isFrontCamera = NO;
	%orig;
}

%end

%hook PLCameraView

- (void)_updateOverlayControls
{
	PLCameraController *cameraController = MSHookIvar<PLCameraController *>(self, "_cameraController");
	if (MSHookIvar<int>(cameraController, "_cameraDevice") == 1 && FrontHDR) {
		MSHookIvar<int>(cameraController, "_cameraDevice") = 0;
		%orig;
		MSHookIvar<int>(cameraController, "_cameraDevice") = 1;
	} else %orig;
}

- (BOOL)_optionsButtonShouldBeHidden
{
	return isFrontCamera && FrontHDR ? NO : %orig;
}

%end

%hook PLCameraSettingsView

- (void)layoutSubviews
{
	%orig;
	if (FrontHDR) {
		%c(PLCameraSettingsGroupView);
		[(UIView *)MSHookIvar<PLCameraSettingsGroupView *>(self, "_panoramaGroup") setAlpha:(isFrontCamera ? 0.5 : 1.0)];
	}
}

- (void)_enterPanoramaMode
{
	if (isFrontCamera && FrontHDR);
	else %orig;
}

%end


%ctor
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	prefDict = [[NSDictionary alloc] initWithContentsOfFile:PREF_PATH];
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, PreferencesChangedCallback, CFSTR(PreferencesChangedNotification), NULL, CFNotificationSuspensionBehaviorCoalesce);
	[pool release];
}
