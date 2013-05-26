#import <AVFoundation/AVFoundation.h>
#import <sys/utsname.h>

#define PreferencesChangedNotification "com.PS.FrontHDR.settingschanged"
#define PREF_PATH @"/var/mobile/Library/Preferences/com.PS.FrontHDR.plist"
#define Bool(dict, key, defaultBoolValue) ([[dict objectForKey:key] boolValue] ?: defaultBoolValue)
#define FrontHDR Bool(prefDict, @"FrontHDREnabled", YES)

#define MODEL 	struct utsname systemInfo; \
				uname(&systemInfo); \
				NSString *modelName = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];

static NSDictionary *prefDict = nil;
static BOOL HDRIsOn;
static BOOL isFrontCamera;

// Check HDR settings from system's plist file
static void fileCheck () {
	NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.apple.mobileslideshow.plist"];
	if (dict != nil) {
		id camConfigDict = [dict objectForKey:@"CameraConfiguration"];
			if (camConfigDict != nil) {
				id camConfigHDRIsOn = [camConfigDict objectForKey:@"HDRIsOn"];
					if (camConfigHDRIsOn != nil) {
						BOOL soHDRIsOn = [camConfigHDRIsOn boolValue];
						if (soHDRIsOn) HDRIsOn = YES;
					}
			}
	}
}

static void PreferencesChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	[prefDict release];
	prefDict = [[NSDictionary alloc] initWithContentsOfFile:PREF_PATH];
}


%hook AVResolvedCaptureOptions

- (id)initWithCaptureOptionsDictionary:(id)captureOptionsDictionary // All things here are to inject HDR properties into Camera system
{
	NSMutableDictionary *cameraProperties = [captureOptionsDictionary mutableCopy];
	NSMutableDictionary *liveSourceOptions = [[cameraProperties objectForKey:@"LiveSourceOptions"] mutableCopy];
	if ([[[cameraProperties objectForKey:@"OverridePrefixes"] description] isEqualToString:@"P:"] &&
		[[[liveSourceOptions objectForKey:@"VideoPort"] description] isEqualToString:@"PortTypeFront"] &&
		FrontHDR)
		{
			[liveSourceOptions setObject:[NSNumber numberWithBool:YES] forKey:@"HDR"];
			MODEL
			if (![modelName hasPrefix:@"iPhone3"])
				[liveSourceOptions setObject:[NSNumber numberWithBool:YES] forKey:@"HDRSavePreBracketedFrameAsEV0"]; // iPhone 4 cannot add this value
			[cameraProperties setObject:liveSourceOptions forKey:@"LiveSourceOptions"];
			return %orig(cameraProperties);
		}
	return %orig;
}

%end

%hook PLCameraController

- (int)cameraDevice { return isFrontCamera && FrontHDR ? 0 : %orig; } // This will hack enable HDR label in Front Camera

- (BOOL)isHDREnabled { return HDRIsOn && isFrontCamera && FrontHDR ? YES : %orig; } // This is the important line, without this, HDR won't work

- (BOOL)supportsHDR { return isFrontCamera && FrontHDR ? YES : %orig; }

- (void)_previewStarted:(id)arg1 { %orig; if (FrontHDR && isFrontCamera) fileCheck(); }

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

- (void)_toggleCameraButtonWasPressed:(id)pressed
{
	if (isFrontCamera && FrontHDR) {
		[self performSelector:@selector(setCameraDevice:) withObject:self]; // Set Camera Device to 1 first
		[self performSelector:@selector(_reallyToggleCamera) withObject:nil afterDelay:.14]; // Then toggle it to 0
	}
	else %orig;
}

- (void)toggleHDR:(BOOL)enabled { if (FrontHDR) HDRIsOn = enabled; %orig; } // Handle HDR toggle

- (BOOL)HDRIsOn { return isFrontCamera && FrontHDR && HDRIsOn ? YES : %orig; }

- (BOOL)_optionsButtonShouldBeHidden { return isFrontCamera && FrontHDR ? NO : %orig; } // So that user can toggle HDR in Front Camera

%end

%hook PLCameraSettingsView

// Prevent from user to go into Panorama Mode in Front Camera, it won't work :P
- (void)layoutSubviews
{
	%orig;
	if (FrontHDR) {
		%class PLCameraSettingsGroupView;
		PLCameraSettingsGroupView *panoramaGroup = MSHookIvar<PLCameraSettingsGroupView *>(self, "_panoramaGroup");
		if (isFrontCamera)
			[(UIView *)panoramaGroup setAlpha:0.5];
		else
			[(UIView *)panoramaGroup setAlpha:1.0];
	}
}

- (void)_enterPanoramaMode { if (isFrontCamera && FrontHDR); else %orig; }

%end


%ctor
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	prefDict = [[NSDictionary alloc] initWithContentsOfFile:PREF_PATH];
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, PreferencesChangedCallback, CFSTR(PreferencesChangedNotification), NULL, CFNotificationSuspensionBehaviorCoalesce);
	[pool release];
}
