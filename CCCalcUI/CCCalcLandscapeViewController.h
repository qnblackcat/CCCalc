#import <UIKit/UIKit.h>

//The calculator laid out for landscape: display and two rows of buttons on the left, the other four rows of the keypad on the right
@interface CCCalcLandscapeViewController : UIViewController
//Whether the interface behind the view is landscape, the device orientation is wrong when the phone is tilted or lying flat
+ (BOOL)isLandscapeForView:(UIView *)view;
+ (CGFloat)preferredWidth;
+ (CGFloat)preferredHeight;
- (void)reset;
@end
