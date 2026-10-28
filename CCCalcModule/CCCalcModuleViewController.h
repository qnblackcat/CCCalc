#import <UIKit/UIKit.h>
#import <ControlCenterUIKit/CCUIContentModuleContentViewController-Protocol.h>

@interface CCCalcModuleViewController : UIViewController <CCUIContentModuleContentViewController>
@property (nonatomic, weak) id contentModuleContext;
@end
