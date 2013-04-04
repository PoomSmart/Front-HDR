#import <AVFoundation/AVFoundation.h>
#import <PhotoLibrary/PhotoLibrary.h>

static BOOL FrontHDR;
BOOL HDRIsOn;
BOOL isFrontCamera;
@interface PLPreviewOverlayView : UIView { }
@end

@interface PLCameraController : NSObject
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

%group Plist

%hook AVResolvedCaptureOptions

- (id)initWithCaptureOptionsDictionary:(id)captureOptionsDictionary // All things here are to inject HDR properties into Camera system
{
	if (FrontHDR) {
		NSMutableDictionary *cameraProperties = [captureOptionsDictionary mutableCopy];
		if ([[[cameraProperties objectForKey:@"OverridePrefixes"] description] isEqualToString:@"P:"]) {
			NSMutableDictionary *liveSourceOptions = [[cameraProperties objectForKey:@"LiveSourceOptions"] mutableCopy];
			if ([[[liveSourceOptions objectForKey:@"VideoPort"] description] isEqualToString:@"PortTypeFront"]) {
				[liveSourceOptions setObject:[NSNumber numberWithBool:YES] forKey:@"HDR"];
				[liveSourceOptions setObject:[NSNumber numberWithBool:YES] forKey:@"HDRSavePreBracketedFrameAsEV0"];
				[cameraProperties setObject:liveSourceOptions forKey:@"LiveSourceOptions"];
				return %orig(cameraProperties);
			}
			else return %orig;
		}
		else
			return %orig;
	}
	else return %orig;
}

%end

%end


%group HDR

%hook PLCameraController

- (int)cameraDevice { return isFrontCamera && FrontHDR ? 0 : %orig; } // This will hack enable HDR label in Front Camera
- (BOOL)supportsHDR { return isFrontCamera && FrontHDR ? YES : %orig; } // Just add support
- (BOOL)isHDREnabled { return HDRIsOn && isFrontCamera && FrontHDR ? YES : %orig; } // This is the important line, without this, HDR won't work

- (void)_setCameraMode:(int)arg1 cameraDevice:(int)arg2 // Check for code running only in Front Camera & Photo mode
{
	if (FrontHDR) {
		if (arg1 == 0 && arg2 == 1)
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
	if (isFrontCamera && FrontHDR) {
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

- (void)toggleHDR:(BOOL)arg1 { HDRIsOn = arg1; %orig; } // Handle HDR toggle
- (BOOL)HDRIsOn { return HDRIsOn && isFrontCamera && FrontHDR ? YES : %orig; }
- (BOOL)_optionsButtonShouldBeHidden { return isFrontCamera && FrontHDR ? NO : %orig; } // So that user can toggle HDR in Front Camera
- (BOOL)_flashButtonShouldBeHidden { return isFrontCamera && FrontHDR ? YES : %orig; } // From the previous hack, this line will hide Flash Button

%end

%hook PLCameraSettingsView

- (void)_enterPanoramaMode { if (isFrontCamera && FrontHDR); else %orig; } // Prevent from user to go into Panorama Mode in Front Camera, it won't work :P

%end

%end


static void FrontHDRLoader()
{
  NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.PS.FrontHDR.plist"];
  id FrontHDREnabled = [dict objectForKey:@"FrontHDREnabled"];
  FrontHDR = FrontHDREnabled ? [FrontHDREnabled boolValue] : YES;
}

static void PostNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	FrontHDRLoader();
}


%ctor
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, PostNotification, CFSTR("com.PS.FrontHDR.settingschanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
	FrontHDRLoader();
	[pool drain];
	if ([[NSBundle mainBundle].bundleIdentifier isEqualToString:@"com.apple.camera"] || [[NSBundle mainBundle].bundleIdentifier isEqualToString:@"com.apple.springboard"])
	{ %init(Plist); %init(HDR) }
}
