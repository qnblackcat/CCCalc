#import "CCCalcModuleProvider.h"
#import "CCCalcModule.h"

static NSString *const kModuleIdentifier = @"ai.paisseon.cccalcmodule";

@implementation CCCalcModuleProvider

- (instancetype)init {
	self = [super init];
	_moduleInstancesByIdentifier = [NSMutableDictionary new];
	return self;
}

- (NSUInteger)numberOfProvidedModules {
	return 1;
}

- (NSString *)identifierForModuleAtIndex:(NSUInteger)index {
	return kModuleIdentifier;
}

- (id)moduleInstanceForModuleIdentifier:(NSString *)identifier {
	id module = _moduleInstancesByIdentifier[identifier];

	if(!module) {
		module = [[CCCalcModule alloc] init];
		_moduleInstancesByIdentifier[identifier] = module;
	}

	return module;
}

- (NSString *)displayNameForModuleIdentifier:(NSString *)identifier {
	return @"CCCalc";
}

- (UIImage *)settingsIconForModuleIdentifier:(NSString *)identifier {
	return [UIImage systemImageNamed:@"plus.forwardslash.minus"];
}

@end
