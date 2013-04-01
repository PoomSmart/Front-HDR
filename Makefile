GO_EASY_ON_ME = 1
include theos/makefiles/common.mk
export ARCHS = armv7
TWEAK_NAME = FrontHDR
FrontHDR_FILES = Tweak.xm
FrontHDR_FRAMEWORKS = AVFoundation UIKit
FrontHDR_PRIVATE_FRAMEWORKS = PhotoLibrary
include $(THEOS_MAKE_PATH)/tweak.mk
