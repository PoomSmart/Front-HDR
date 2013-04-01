#import <AVFoundation/AVFoundation.h>
#import <PhotoLibrary/PhotoLibrary.h>

BOOL HDRIsOn;
BOOL isFrontCamera;

%group Plist

NSMutableDictionary *cameraProperties;
NSMutableDictionary *sessionProperties;
NSMutableDictionary *frontCameraLiveSourceOptions;

%hook AVCaptureFigVideoDevice

- (id)initWithProperties:(NSDictionary *)properties // All things here are to inject HDR properties into Camera system
{
	cameraProperties = [properties mutableCopy];
	[cameraProperties setObject:[NSNumber numberWithBool:YES] forKey:@"hdrSupported"];
	sessionProperties = [[cameraProperties objectForKey:@"AVCaptureSessionPresetPhoto"] mutableCopy];
		frontCameraLiveSourceOptions = [[sessionProperties objectForKey:@"LiveSourceOptions"] mutableCopy];
		[frontCameraLiveSourceOptions setObject:[NSNumber numberWithBool:YES] forKey:@"HDR"];
		[sessionProperties setObject:frontCameraLiveSourceOptions forKey:@"LiveSourceOptions"];
		[cameraProperties setObject:sessionProperties forKey:@"AVCaptureSessionPresetPhoto"];
	return %orig(cameraProperties);
	[frontCameraLiveSourceOptions release];
	[sessionProperties release];
	[cameraProperties release];
}

%end

%end


%group HDR

%hook PLCameraController

- (int)cameraDevice { return isFrontCamera ? 0 : %orig; } // This will hack enable HDR label in Front Camera
- (BOOL)supportsHDR { return isFrontCamera ? YES : %orig; } // Just add support
- (BOOL)isHDREnabled { return HDRIsOn && isFrontCamera ? YES : %orig; } // This is the important line, without this, HDR won't work

- (void)_setCameraMode:(int)arg1 cameraDevice:(int)arg2 // Check for code running only in Front Camera & Photo mode
{
	if (arg1 == 0 && arg2 == 1)
		isFrontCamera = YES;
	else
		isFrontCamera = NO;
	%orig;
}

%end

%hook PLCameraView

- (void)toggleHDR:(BOOL)arg1 { HDRIsOn = arg1; %orig; } // Handle HDR toggle
- (BOOL)_optionsButtonShouldBeHidden { return isFrontCamera ? NO : %orig; } // So that user can toggle HDR in Front Camera
- (BOOL)_flashButtonShouldBeHidden { return isFrontCamera ? YES : %orig; } // From the previous hack, this line will hide Flash Button

%end

%hook PLCameraSettingsView

- (void)_enterPanoramaMode { if (isFrontCamera); else %orig; } // Prevent from user to go into Panorama Mode in Front Camera, it won't work :P

%end

%end


%ctor
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[pool release];
	if ([[NSBundle mainBundle].bundleIdentifier isEqualToString:@"com.apple.camera"] || [[NSBundle mainBundle].bundleIdentifier isEqualToString:@"com.apple.springboard"])
	{ %init(Plist); %init(HDR) }
}
