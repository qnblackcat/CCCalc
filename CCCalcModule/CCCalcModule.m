#import "CCCalcModule.h"
#import "CCCalcModuleViewController.h"

@implementation CCCalcModule {
	CCCalcModuleViewController *_contentViewController;
}

- (UIViewController<CCUIContentModuleContentViewController> *)contentViewController {
	if(!_contentViewController)
		_contentViewController = [[CCCalcModuleViewController alloc] init];

	return _contentViewController;
}

- (UIViewController *)backgroundViewController {
	return nil;
}

@end
