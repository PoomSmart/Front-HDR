#import <AVFoundation/AVFoundation.h>
#import "../PS.h"

#define PREF_PATH @"/var/mobile/Library/Preferences/com.PS.FrontHDR.plist"
#define FrontHDR [[NSDictionary dictionaryWithContentsOfFile:PREF_PATH][@"FrontHDREnabled"] boolValue]

@interface PLCameraController
@property(assign, nonatomic) int cameraDevice;
@property(assign, nonatomic) int cameraMode;
- (BOOL)isCapturingVideo;
@end

@interface CAMCaptureController
@property(assign, nonatomic) int cameraDevice;
+ (BOOL)isStillImageMode:(int)mode;
@end

@interface PLCameraView
@property(assign, nonatomic) int cameraDevice;
@property(assign, nonatomic) int cameraMode;
@end

@interface PLCameraSettingsView
@end

@interface PLCameraSettingsGroupView : UIView
@end

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
		[MSHookIvar<PLCameraSettingsGroupView *>(settingsView, "_panoramaGroup") setAlpha:isFront ? 0.0 : 1.0];
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

%ctor
{
	if (isiOS7Up) {
		if (is_mediaserverd()) {
			%init(iOS8_process);
		} else {
			MSHookFunction(((BOOL *)MSFindSymbol(NULL, "_MGGetBoolAnswer")), (BOOL *)replaced_MGGetBoolAnswer, (BOOL **)&old_MGGetBoolAnswer);
			%init(iOS78);
			if (isiOS8) {
				%init(iOS8_App);
			}
		}
	}
	else {
		if (!is_mediaserverd()) {
			%init(iOS6);
		}
	}
}
