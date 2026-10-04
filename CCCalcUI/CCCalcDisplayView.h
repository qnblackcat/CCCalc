#import <UIKit/UIKit.h>

@interface CCCalcDisplayView : UIView
@property (nonatomic, retain) UILabel *labelView;
//Small line above the result showing what was calculated
@property (nonatomic, retain) UILabel *expressionView;
- (void)setText:(NSString *)text;
- (void)setExpressionText:(NSString *)text;
- (void)setPasteboardText:(NSString *)pasteboardText;
@end

@interface CCCalcLabelView : UILabel
//What "Copy" puts on the pasteboard, falls back to the displayed text
@property (nonatomic, copy) NSString *pasteboardText;
@end
