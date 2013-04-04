#import <UIKit/UIKit.h>
#import <Preferences/Preferences.h>

__attribute__((visibility("hidden")))
@interface FrontHDRPreferenceController : PSListController
- (id)specifiers;
@end

@implementation FrontHDRPreferenceController

- (id)specifiers {
	if(_specifiers == nil) {
		_specifiers = [[self loadSpecifiersFromPlistName:@"FrontHDR" target:self] retain];
  }
	return _specifiers;
}

@end
