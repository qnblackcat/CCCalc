#import "CCCalcLandscapeViewController.h"
#import <objc/runtime.h>

//CCCalcViewController is created through the runtime, its @implementation lives in Tweak.xm
@interface NSObject (CCCalcLandscapeHost)
- (instancetype)initWithPageSize:(CGSize)size;
- (UIView *)displayView;
- (NSDictionary<NSNumber *, UIView *> *)buttons;
- (void)hideHistory;
+ (CGRect)circleBounds;
@end

//Button identifiers of CCCalc (CCCalcButtons.h)
enum {
	LS_BTN_0 = 0, LS_BTN_1, LS_BTN_2, LS_BTN_3, LS_BTN_4, LS_BTN_5, LS_BTN_6, LS_BTN_7, LS_BTN_8, LS_BTN_9,
	LS_BTN_DECIMAL = 10, LS_BTN_DIVIDE = 11, LS_BTN_MULTIPLY = 12, LS_BTN_ADD = 14, LS_BTN_EQUAL = 15,
	LS_BTN_CLEAR = 16, LS_BTN_NEGATE = 17, LS_BTN_PERCENT = 18, LS_BTN_SUBTRACT = 19,
	LS_BTN_OPENPAREN = 40, LS_BTN_CLOSEPAREN = 41, LS_BTN_DELETE = 42, LS_BTN_HISTORY = 43
};

//Every size below is a ratio of the screen or of the module, so the layout follows the device
static const CGFloat kLandscapeHeightRatio = 332.0 / 393.0;	//of the short side, what Control Center leaves for a module
static const CGFloat kLandscapeMaxWidthRatio = 780.0 / 852.0;	//of the long side
static const CGFloat kInsetRatio = 0.04;						//of the module height
static const CGFloat kColumnToRowPitch = 80.0 / 76.0;
static const int kKeypadRows = 4;
static const int kKeypadColumns = 4;

typedef struct {
	CGFloat inset;
	CGFloat rowPitch;
	CGFloat columnPitch;
	CGSize keypadSize;
} LandscapeMetrics;

static LandscapeMetrics landscapeMetrics(CGFloat height) {
	LandscapeMetrics metrics;
	metrics.inset = height * kInsetRatio;
	metrics.rowPitch = (height - 2 * metrics.inset) / kKeypadRows;
	metrics.columnPitch = metrics.rowPitch * kColumnToRowPitch;
	metrics.keypadSize = CGSizeMake(metrics.columnPitch * kKeypadColumns, metrics.rowPitch * kKeypadRows);
	return metrics;
}

static CGFloat shortSide(void) {
	CGSize size = UIScreen.mainScreen.bounds.size;
	return MIN(size.width, size.height);
}

static CGFloat longSide(void) {
	CGSize size = UIScreen.mainScreen.bounds.size;
	return MAX(size.width, size.height);
}

//The circle every CCCalc button is drawn with
static CGFloat circleSize(void) {
	CGFloat size = [NSClassFromString(@"CCCalcButton") circleBounds].size.width;
	return size > 0 ? size : 60;
}

//CCCalcScrollView overrides setFrame: in landscape and ignores the frame it is given (it uses its old origin and the screen height), so bypass it
static void setScrollViewFrame(UIScrollView *scrollView, CGRect frame) {
	Method method = class_getInstanceMethod([UIScrollView class], @selector(setFrame:));
	((void (*)(id, SEL, CGRect))method_getImplementation(method))(scrollView, @selector(setFrame:), frame);
}

@implementation CCCalcLandscapeViewController {
	UIViewController *_calcController;
	UIView *_leftButtonsView;
	UIView *_horizontalDivider;
	UIView *_verticalDivider;
	NSArray<UIView *> *_leftButtons;
	CGSize _pageSize;
	CGRect _lastBounds;
	BOOL _buttonsArranged;
}

+ (BOOL)isLandscapeForView:(UIView *)view {
	UIWindow *window = view.window;

	if(window)
		return window.bounds.size.width > window.bounds.size.height;

	return UIDeviceOrientationIsLandscape(UIDevice.currentDevice.orientation);
}

+ (CGFloat)preferredHeight {
	return shortSide() * kLandscapeHeightRatio;
}

+ (CGFloat)preferredWidth {
	LandscapeMetrics metrics = landscapeMetrics([self preferredHeight]);
	return MIN(2 * metrics.keypadSize.width + 3 * metrics.inset, longSide() * kLandscapeMaxWidthRatio);
}

- (void)reset {
	[(id)_calcController hideHistory];
}

- (void)viewDidLoad {
	[super viewDidLoad];

	Class calcClass = NSClassFromString(@"CCCalcViewController");
	if(!calcClass)
		return;

	//The calculator lays its buttons out for a fixed page size
	_pageSize = landscapeMetrics([[self class] preferredHeight]).keypadSize;
	_calcController = [[calcClass alloc] initWithPageSize:_pageSize];

	[self addChildViewController:_calcController];
	[self.view addSubview:_calcController.view];
	[self.view addSubview:[(id)_calcController displayView]];
	[_calcController didMoveToParentViewController:self];

	_leftButtonsView = [[UIView alloc] init];
	[self.view addSubview:_leftButtonsView];

	_horizontalDivider = [self dividerView];
	_verticalDivider = [self dividerView];
}

- (UIView *)dividerView {
	UIView *divider = [[UIView alloc] init];
	divider.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.18];
	divider.userInteractionEnabled = NO;
	[self.view addSubview:divider];
	return divider;
}

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];

	CGRect bounds = self.view.bounds;

	//Setting the frame resets the scroll position, so only redo it when the size changed
	if(!_calcController || (CGRectEqualToRect(bounds, _lastBounds) && _buttonsArranged))
		return;
	_lastBounds = bounds;

	LandscapeMetrics metrics = landscapeMetrics(bounds.size.height);
	//The calculator was built for _pageSize, everything is scaled from that to the size the module really has
	CGFloat scale = metrics.keypadSize.width / _pageSize.width;

	UIScrollView *scrollView = (UIScrollView *)_calcController.view;
	CGFloat keypadLeft = bounds.size.width - metrics.inset - metrics.keypadSize.width;
	CGFloat keypadBottom = (bounds.size.height + metrics.keypadSize.height) / 2.0;

	scrollView.transform = CGAffineTransformIdentity;
	setScrollViewFrame(scrollView, CGRectMake(0, 0, _pageSize.width, _pageSize.height));
	scrollView.transform = CGAffineTransformMakeScale(scale, scale);
	scrollView.center = CGPointMake(keypadLeft + metrics.keypadSize.width / 2.0, bounds.size.height / 2.0);

	//Two rows of buttons under the display, lined up with the bottom two rows of the keypad
	CGRect leftFrame = CGRectMake(metrics.inset, keypadBottom - 2 * metrics.rowPitch, metrics.keypadSize.width, 2 * metrics.rowPitch);
	_leftButtonsView.frame = leftFrame;
	[[(id)_calcController displayView] setFrame:CGRectMake(0, 0, keypadLeft, CGRectGetMinY(leftFrame))];

	//Two lines that box the display in, so the buttons below it still read as one keypad with the digits on the right
	CGFloat thickness = 1.0 / UIScreen.mainScreen.scale;
	CGFloat dividerX = floor((CGRectGetMaxX(leftFrame) + keypadLeft) / 2.0);
	CGFloat dividerY = CGRectGetMinY(leftFrame) - metrics.inset / 2.0;
	_horizontalDivider.frame = CGRectMake(CGRectGetMinX(leftFrame), dividerY, dividerX - CGRectGetMinX(leftFrame) + thickness, thickness);
	_verticalDivider.frame = CGRectMake(dividerX, metrics.inset, thickness, dividerY - metrics.inset + thickness);

	[self arrangeButtons];

	CGFloat circle = circleSize();
	for(NSUInteger index = 0; index < [_leftButtons count]; index++) {
		UIView *button = _leftButtons[index];
		NSUInteger row = index / kKeypadColumns, column = index % kKeypadColumns;

		button.transform = CGAffineTransformIdentity;
		button.frame = CGRectMake(column * metrics.columnPitch + (metrics.columnPitch - circle) / 2.0, row * metrics.rowPitch + (metrics.rowPitch - circle) / 2.0, circle, circle);
		button.transform = CGAffineTransformMakeScale(scale, scale);
	}
}

//CCCalcViewController creates its buttons on its first layout and puts them in a 4x6 grid, here they are moved into the two landscape blocks
- (void)arrangeButtons {
	if(_buttonsArranged)
		return;

	[_calcController.view layoutIfNeeded];

	NSDictionary<NSNumber *, UIView *> *buttons = [(id)_calcController buttons];
	if(![buttons count])
		return;

	int left[2][4] = {
		{ LS_BTN_NEGATE, LS_BTN_CLEAR, LS_BTN_DELETE, LS_BTN_HISTORY },
		{ LS_BTN_OPENPAREN, LS_BTN_CLOSEPAREN, LS_BTN_PERCENT, LS_BTN_DIVIDE }
	};

	NSMutableArray<UIView *> *leftButtons = [NSMutableArray array];
	for(int row = 0; row < 2; row++) {
		for(int column = 0; column < 4; column++) {
			UIView *button = buttons[@(left[row][column])];
			[_leftButtonsView addSubview:button];
			[leftButtons addObject:button];
		}
	}
	_leftButtons = leftButtons;

	int right[4][4] = {
		{ LS_BTN_7, LS_BTN_8, LS_BTN_9, LS_BTN_MULTIPLY },
		{ LS_BTN_4, LS_BTN_5, LS_BTN_6, LS_BTN_SUBTRACT },
		{ LS_BTN_1, LS_BTN_2, LS_BTN_3, LS_BTN_ADD },
		{ LS_BTN_0, -1, LS_BTN_DECIMAL, LS_BTN_EQUAL }
	};

	//These stay on the calculator's own page, which is laid out for _pageSize
	CGFloat circle = circleSize();
	CGFloat columnPitch = _pageSize.width / kKeypadColumns;
	CGFloat rowPitch = _pageSize.height / kKeypadRows;
	for(int row = 0; row < 4; row++) {
		for(int column = 0; column < 4; column++) {
			if(right[row][column] < 0)
				continue;

			UIView *button = buttons[@(right[row][column])];
			CGFloat width = right[row][column] == LS_BTN_0 ? columnPitch + circle : circle;
			button.frame = CGRectMake(column * columnPitch + (columnPitch - circle) / 2.0, row * rowPitch + (rowPitch - circle) / 2.0, width, circle);
		}
	}

	_buttonsArranged = YES;
}

@end
