#import "CCCalcModule.h"
#import "CCCalcModuleViewController.h"

@implementation CCCalcModule {
	CCCalcModuleViewController *_contentViewController;
	id _contentModuleContext;
}

//Opening the app through the context lets Control Center dismiss itself, which the Lock Screen / Notification Center needs
- (void)setContentModuleContext:(id)context {
	_contentModuleContext = context;
	_contentViewController.contentModuleContext = context;
}

- (UIViewController<CCUIContentModuleContentViewController> *)contentViewController {
	if(!_contentViewController)
		_contentViewController = [[CCCalcModuleViewController alloc] init];
		_contentViewController.contentModuleContext = _contentModuleContext;

	return _contentViewController;
}

- (UIViewController *)backgroundViewController {
	return nil;
}

@end
