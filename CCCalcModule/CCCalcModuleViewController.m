#import "CCCalcModuleViewController.h"
#import <objc/runtime.h>

//The calculator lives in the CCCalc tweak, which is already loaded in SpringBoard, so it is only reached through the runtime
@interface NSObject (CCCalcHost)
- (instancetype)initWithPageSize:(CGSize)size;
- (UIView *)displayView;
- (void)hideHistory;
- (void)reset;
+ (BOOL)isLandscapeForView:(UIView *)view;
+ (CGFloat)preferredWidth;
+ (CGFloat)preferredHeight;
@end

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (BOOL)openApplicationWithBundleID:(NSString *)bundleID;
@end

//Every size below is a ratio of the screen or of the module, so the layout follows the device
//Portrait: display on top, keypad below
static const CGFloat kPortraitWidthRatio = 321.0 / 393.0;	//of the short side of the screen
//Heights of the three parts, as ratios of the module width
static const CGFloat kHeaderToWidth = 120.0 / 321.0;		//display, taller than the stock module's so the expression and result have room
static const CGFloat kKeypadToWidth = 456.0 / 321.0;		//six rows that keep the spacing of the stock module
static const CGFloat kFooterToWidth = 24.0 / 321.0;			//gap under the keypad that the stock module keeps for its footer
static const CGFloat kPortraitHeightRatio = kHeaderToWidth + kKeypadToWidth + kFooterToWidth;	//of the module width

static CGFloat shortSide(void) {
	CGSize size = UIScreen.mainScreen.bounds.size;
	return MIN(size.width, size.height);
}

static CGFloat portraitWidth(void) {
	return shortSide() * kPortraitWidthRatio;
}

static CGFloat portraitHeight(void) {
	return portraitWidth() * kPortraitHeightRatio;
}

//CCCalcScrollView overrides setFrame: in landscape and ignores the frame it is given, so bypass it
static void setScrollViewFrame(UIScrollView *scrollView, CGRect frame) {
	Method method = class_getInstanceMethod([UIScrollView class], @selector(setFrame:));
	((void (*)(id, SEL, CGRect))method_getImplementation(method))(scrollView, @selector(setFrame:), frame);
}

@implementation CCCalcModuleViewController {
	UIImageView *_glyphView;
	UIViewController *_portraitController;
	UIViewController *_landscapeController;
	UITapGestureRecognizer *_tapGesture;
}

//Landscape is laid out by the calculator itself, the CCCalc tweak is a dependency of this module
- (Class)landscapeClass {
	return NSClassFromString(@"CCCalcLandscapeViewController");
}

- (BOOL)isLandscape {
	return [self landscapeClass] && [[self landscapeClass] isLandscapeForView:self.viewIfLoaded];
}

- (CGFloat)preferredExpandedContentWidth {
	return [self isLandscape] ? [[self landscapeClass] preferredWidth] : portraitWidth();
}

- (CGFloat)preferredExpandedContentHeight {
	return [self isLandscape] ? [[self landscapeClass] preferredHeight] : portraitHeight();
}

- (BOOL)providesOwnPlatter {
	return NO;
}

- (BOOL)shouldBeginTransitionToExpandedContentModule {
	return YES;
}

- (void)viewDidLoad {
	[super viewDidLoad];

	UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:24 weight:UIImageSymbolWeightMedium];
	_glyphView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"plus.forwardslash.minus" withConfiguration:configuration]];
	_glyphView.tintColor = [UIColor whiteColor];
	_glyphView.contentMode = UIViewContentModeCenter;
	[self.view addSubview:_glyphView];

	_tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openCalculator)];
	[self.view addGestureRecognizer:_tapGesture];
}

- (void)openCalculator {
	//Off the main thread, the workspace call blocks SpringBoard for seconds otherwise
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
		[[NSClassFromString(@"LSApplicationWorkspace") defaultWorkspace] openApplicationWithBundleID:@"com.apple.calculator"];
	});
}

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];

	CGRect bounds = self.view.bounds;
	_glyphView.frame = bounds;
	_landscapeController.view.frame = bounds;

	if(!_portraitController)
		return;

	//Split whatever height the module really has in the same proportions
	CGFloat keypadHeight = bounds.size.height * kKeypadToWidth / kPortraitHeightRatio;
	CGFloat headerHeight = bounds.size.height * kHeaderToWidth / kPortraitHeightRatio;
	[[(id)_portraitController displayView] setFrame:CGRectMake(0, 0, bounds.size.width, headerHeight)];
	setScrollViewFrame((UIScrollView *)_portraitController.view, CGRectMake(0, headerHeight, bounds.size.width, keypadHeight));
}

- (void)addController:(UIViewController *)controller {
	[self addChildViewController:controller];
	[self.view addSubview:controller.view];
	[controller didMoveToParentViewController:self];
}

- (void)loadPortraitCalculator {
	Class calcClass = NSClassFromString(@"CCCalcViewController");
	if(!calcClass)
		return;

	//The calculator lays its buttons out for a fixed page size
	_portraitController = [[calcClass alloc] initWithPageSize:CGSizeMake(portraitWidth(), portraitWidth() * kKeypadToWidth)];
	[self addController:_portraitController];
	[self.view addSubview:[(id)_portraitController displayView]];
}

- (void)loadLandscapeCalculator {
	_landscapeController = [[[self landscapeClass] alloc] init];
	_landscapeController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self addController:_landscapeController];
}

- (void)willTransitionToExpandedContentMode:(BOOL)willTransition {
	//The tap recognizer would otherwise swallow touches meant for the calculator buttons
	_tapGesture.enabled = !willTransition;

	BOOL landscape = willTransition && [self isLandscape];

	if(willTransition) {
		if(landscape && !_landscapeController)
			[self loadLandscapeCalculator];
		else if(!landscape && !_portraitController)
			[self loadPortraitCalculator];
	}

	_portraitController.view.hidden = !(willTransition && !landscape);
	[(id)_portraitController displayView].hidden = _portraitController.view.hidden;
	_landscapeController.view.hidden = !landscape;
	_glyphView.hidden = willTransition && (landscape ? _landscapeController : _portraitController);

	if(!willTransition) {
		[(id)_portraitController hideHistory];
		[(id)_landscapeController reset];
	}

	[self.view setNeedsLayout];
}

@end
