#import <AVFoundation/AVFoundation.h>
#import "IOKitDefines.h"

#define PreferencesChangedNotification "com.PS.FrontHDR.settingschanged"
#define PREF_PATH @"/var/mobile/Library/Preferences/com.PS.FrontHDR.plist"
#define FrontHDR [[prefDict objectForKey:@"FrontHDREnabled"] boolValue]

static NSDictionary *prefDict = nil;
static void PreferencesChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	[prefDict release];
	prefDict = [[NSDictionary alloc] initWithContentsOfFile:PREF_PATH];
}

%group iOS6

#define isFrontCamera (self.cameraDevice == 1 && self.cameraMode == 0)

@interface AVCaptureFigVideoDevice : AVCaptureDevice
@end

@interface PLCameraView
@property(assign, nonatomic) int cameraDevice;
@property(assign, nonatomic) int cameraMode;
@end

@interface PLCameraSettingsView
@end

@interface PLCameraSettingsGroupView : UIView
@end

@interface PLCameraController
@property(assign, nonatomic) int cameraDevice;
@property(assign, nonatomic) int cameraMode;
- (BOOL)isCapturingVideo;
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
		} else %orig;
	} else %orig;
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

%group iOS7

static CFTypeRef (*orig_registryEntry)(io_registry_entry_t entry,  CFStringRef key, CFAllocatorRef allocator, IOOptionBits options);
CFTypeRef replaced_registryEntry(io_registry_entry_t entry,  CFStringRef key, CFAllocatorRef allocator, IOOptionBits options) {
    CFTypeRef retval = NULL;
    retval = orig_registryEntry(entry, key, allocator, options);
    const UInt8 enable[3] = {1, 0, 0};
    if (CFEqual(key, CFSTR("front-hdr")) && FrontHDR)
        retval = CFDataCreate(kCFAllocatorDefault, enable, 4);
    return retval;
}

%end


%ctor
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	prefDict = [[NSDictionary alloc] initWithContentsOfFile:PREF_PATH];
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, PreferencesChangedCallback, CFSTR(PreferencesChangedNotification), NULL, CFNotificationSuspensionBehaviorCoalesce);
	if (kCFCoreFoundationVersionNumber > 793.00) {
		%init(iOS7);
		MSHookFunction((void *)IORegistryEntryCreateCFProperty, (void *)replaced_registryEntry, (void **)&orig_registryEntry);
	} else
		%init(iOS6);
	[pool drain];
}
