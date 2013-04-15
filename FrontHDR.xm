#import <AVFoundation/AVFoundation.h>
#import <sys/utsname.h>
#import "substrate.h"

static BOOL FrontHDR;
static BOOL useNative;
static BOOL HDRIsOn;
static BOOL isFrontCamera;

@interface PLPreviewOverlayView : UIView {}
@end

@interface PLCameraController : NSObject {}
- (void)_setCameraMode:(int)arg1 cameraDevice:(int)arg2;
@end

static void fileCheck () {
	NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.apple.mobileslideshow.plist"];
	if (dict != nil && isFrontCamera) {
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

static void FrontHDRLoader()
{
	NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.PS.FrontHDR.plist"];
	id FrontHDREnabled = [dict objectForKey:@"FrontHDREnabled"];
	FrontHDR = FrontHDREnabled ? [FrontHDREnabled boolValue] : YES;
	id useNativeEnabled = [dict objectForKey:@"useNative"];
	useNative = useNativeEnabled ? [useNativeEnabled boolValue] : NO;
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
			
			struct utsname systemInfo;
			uname(&systemInfo);
			NSString *modelName = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];

			if (![modelName hasPrefix:@"iPhone3"])
				[liveSourceOptions setObject:[NSNumber numberWithBool:YES] forKey:@"HDRSavePreBracketedFrameAsEV0"]; // iPhone 4 cannot add this value
			[cameraProperties setObject:liveSourceOptions forKey:@"LiveSourceOptions"];
			return %orig(cameraProperties);
		}
	else return %orig;
}

%end

%hook PLCameraController

- (int)cameraDevice { return isFrontCamera && FrontHDR && !useNative ? 0 : %orig; } // This will hack enable HDR label in Front Camera

- (BOOL)isHDREnabled { return HDRIsOn && isFrontCamera && FrontHDR ? YES : %orig; } // This is the important line, without this, HDR won't work

- (void)_setCameraMode:(int)arg1 cameraDevice:(int)arg2 // Check for code running only in Front Camera & Photo mode
{
	FrontHDRLoader();
	if (FrontHDR) {
		if (arg1 == 0 && arg2 == 1) // arg1 = 0 means Photo mode, arg2 = 1 means Front Camera
			isFrontCamera = YES;
		else
			isFrontCamera = NO;
	}
	%orig;
}

%end

%hook PLCameraView

- (void)_toggleCameraButtonWasPressed:(id)pressed
{
	if (isFrontCamera && FrontHDR && !useNative) {
		UIView *cameraView = MSHookIvar<PLPreviewOverlayView *>(self, "_overlayView");
		[UIView transitionFromView:cameraView toView:cameraView  
                  duration:0.7 
                  options:UIViewAnimationOptionTransitionFlipFromLeft 
                  completion:NULL];
		[[%c(PLCameraController) sharedInstance] _setCameraMode:0 cameraDevice:0];
	}
	else %orig;
}

- (void)cameraControllerPreviewDidStart:(id)arg1 { %orig; if (FrontHDR) fileCheck(); }

- (void)cameraControllerModeDidChange:(id)arg1 { %orig;	if (FrontHDR) fileCheck(); }

- (void)toggleHDR:(BOOL)arg1 { if (FrontHDR) HDRIsOn = arg1; %orig; } // Handle HDR toggle

- (BOOL)_optionsButtonShouldBeHidden { return isFrontCamera && FrontHDR ? NO : %orig; } // So that user can toggle HDR in Front Camera

- (BOOL)_flashButtonShouldBeHidden { return isFrontCamera && FrontHDR ? YES : %orig; } // From the previous hack, this line will hide Flash Button

%end

%hook PLCameraSettingsView

- (void)_enterPanoramaMode { if (isFrontCamera && FrontHDR); else %orig; } // Prevent from user to go into Panorama Mode in Front Camera, it won't work :P

%end


static void PostNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	FrontHDRLoader();
}


%ctor
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, PostNotification, CFSTR("com.PS.FrontHDR.settingschanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
	FrontHDRLoader();
	if ([[NSBundle mainBundle].bundleIdentifier isEqualToString:@"com.apple.camera"] ||
	[[NSBundle mainBundle].bundleIdentifier isEqualToString:@"com.apple.springboard"])
	%init;
	[pool release];
}
