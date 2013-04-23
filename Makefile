include theos/makefiles/common.mk
export ARCHS = armv7 armv7s
TWEAK_NAME = FrontHDR
FrontHDR_FILES = FrontHDR.xm
FrontHDR_FRAMEWORKS = AVFoundation UIKit CoreGraphics

include $(THEOS_MAKE_PATH)/tweak.mk

BUNDLE_NAME = FrontHDRSettings
FrontHDRSettings_FILES = FrontHDRPreferenceController.m
FrontHDRSettings_INSTALL_PATH = /Library/PreferenceBundles
FrontHDRSettings_PRIVATE_FRAMEWORKS = Preferences
FrontHDRSettings_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/FrontHDR.plist$(ECHO_END)
	$(ECHO_NOTHING)find $(THEOS_STAGING_DIR) -name .DS_Store | xargs rm -rf$(ECHO_END)

