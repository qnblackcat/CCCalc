#import "CCCalcDisplayView.h"

static const CGFloat RESULT_FONT_SIZE = 45;
static const CGFloat EXPRESSION_FONT_SIZE = 18;

@implementation CCCalcLabelView

- (id)init {
	self = [super init];
	
	if(self) {
		[self setUserInteractionEnabled:YES];
		[self addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped)]];
		[self setAdjustsFontSizeToFitWidth:YES];
		[self setMinimumScaleFactor:0.4];
		//Long expressions keep the end (what's being typed) visible
		[self setLineBreakMode:NSLineBreakByTruncatingHead];
		[self setTextAlignment:NSTextAlignmentRight];
		[self setFont:[UIFont systemFontOfSize:RESULT_FONT_SIZE weight:UIFontWeightLight]];
	}

	return self;
}
- (void)copy:(id)sender {
	[UIPasteboard generalPasteboard].string = [self pasteboardText] ?: [self text];
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
	return action == @selector(copy:);
}
- (void)tapped {
	[self becomeFirstResponder];
	[[UIMenuController sharedMenuController] showMenuFromView:self rect:[self bounds]];
}
- (BOOL)canBecomeFirstResponder {
	return YES;
}
@end

@implementation CCCalcDisplayView
- (id)init {
	self = [super init];
	if(self) {
		_expressionView = [[UILabel alloc] init];
		[_expressionView setTextColor:[UIColor colorWithWhite:1.0 alpha:0.55]];
		[_expressionView setFont:[UIFont systemFontOfSize:EXPRESSION_FONT_SIZE]];
		[_expressionView setTextAlignment:NSTextAlignmentRight];
		[_expressionView setAdjustsFontSizeToFitWidth:YES];
		[_expressionView setMinimumScaleFactor:0.5];
		[_expressionView setLineBreakMode:NSLineBreakByTruncatingHead];
		[self addSubview:_expressionView];

		_labelView = [[CCCalcLabelView alloc] init];
		[self addSubview:_labelView];
		[_labelView becomeFirstResponder];
	}
	return self;
}
- (void)setText:(NSString *)text {
	[[self labelView] setText:text];
}

- (void)setExpressionText:(NSString *)text {
	[[self expressionView] setText:text];
}

- (void)setPasteboardText:(NSString *)pasteboardText {
	[(CCCalcLabelView *)[self labelView] setPasteboardText:pasteboardText];
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGFloat width = [self frame].size.width - 50;
	CGFloat height = [self frame].size.height + 10;

	//Line heights include some padding, so the two lines overlap a little to sit snugly together
	CGFloat expressionHeight = ceil([UIFont systemFontOfSize:EXPRESSION_FONT_SIZE].lineHeight);
	CGFloat overlap = 6;
	CGFloat topMargin = 4;

	//Shrink the result font only if the header is too short to fit both lines at 45pt
	UIFont *resultFont = [UIFont systemFontOfSize:RESULT_FONT_SIZE weight:UIFontWeightLight];
	CGFloat availableHeight = height - topMargin - expressionHeight + overlap;
	if(resultFont.lineHeight > availableHeight)
		resultFont = [UIFont systemFontOfSize:floor(RESULT_FONT_SIZE * availableHeight / resultFont.lineHeight) weight:UIFontWeightLight];
	CGFloat resultHeight = ceil(resultFont.lineHeight);

	//The result sits slightly below the middle of the header, with the expression right above it
	CGFloat resultTop = (height - resultHeight) / 2.0 + 10;
	resultTop = MAX(resultTop, topMargin + expressionHeight - overlap);
	resultTop = MIN(resultTop, height - resultHeight);

	[[self labelView] setFont:resultFont];
	[[self labelView] setFrame:CGRectMake(25, resultTop, width, resultHeight)];
	[[self expressionView] setFrame:CGRectMake(25, resultTop - expressionHeight + overlap, width, expressionHeight)];
}
@end