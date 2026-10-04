#import <UIKit/UIKit.h>

//List of past calculations shown in place of the keypad, tapping a row copies its result
@interface CCCalcHistoryView : UIView <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, copy) void (^closeHandler)(void);
- (void)reload;
@end
