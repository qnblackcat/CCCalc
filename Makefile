export ARCHS = arm64 arm64e
export TARGET = iphone:clang:16.5:14.0

FINALPACKAGE = 1
DEBUG = 0

TWEAK_NAME = CCCalc

CCCalc_FILES = Tweak.xm $(wildcard CCCalcUI/*.m)
CCCalc_CFLAGS = -fobjc-arc -Wno-error=deprecated-declarations
CCCalc_PRIVATE_FRAMEWORKS = TelephonyUI

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += CCCalcModule
include $(THEOS_MAKE_PATH)/aggregate.mk
