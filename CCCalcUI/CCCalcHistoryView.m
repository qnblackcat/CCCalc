#import "CCCalcHistoryView.h"
#import "CCCalcHistory.h"

static const CGFloat HEADER_HEIGHT = 44;
static const CGFloat ROW_HEIGHT = 64;
static const CGFloat SIDE_MARGIN = 25;
static NSString *const CELL_IDENTIFIER = @"CCCalcHistoryCell";

@interface CCCalcHistoryCell : UITableViewCell
@property (nonatomic, retain) UILabel *expressionLabel;
@property (nonatomic, retain) UILabel *resultLabel;
@end

@implementation CCCalcHistoryCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];

	if(self) {
		[self setBackgroundColor:[UIColor clearColor]];
		[self setSelectionStyle:UITableViewCellSelectionStyleNone];

		_expressionLabel = [[UILabel alloc] init];
		[_expressionLabel setTextColor:[UIColor colorWithWhite:1.0 alpha:0.55]];
		[_expressionLabel setFont:[UIFont systemFontOfSize:15]];
		[_expressionLabel setTextAlignment:NSTextAlignmentRight];
		[_expressionLabel setAdjustsFontSizeToFitWidth:YES];
		[_expressionLabel setMinimumScaleFactor:0.6];
		[_expressionLabel setLineBreakMode:NSLineBreakByTruncatingHead];
		[[self contentView] addSubview:_expressionLabel];

		_resultLabel = [[UILabel alloc] init];
		[_resultLabel setTextColor:[UIColor whiteColor]];
		[_resultLabel setFont:[UIFont systemFontOfSize:28 weight:UIFontWeightLight]];
		[_resultLabel setTextAlignment:NSTextAlignmentRight];
		[_resultLabel setAdjustsFontSizeToFitWidth:YES];
		[_resultLabel setMinimumScaleFactor:0.5];
		[[self contentView] addSubview:_resultLabel];
	}

	return self;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGFloat width = [self contentView].bounds.size.width - SIDE_MARGIN * 2;
	[_expressionLabel setFrame:CGRectMake(SIDE_MARGIN, 8, width, 20)];
	[_resultLabel setFrame:CGRectMake(SIDE_MARGIN, 26, width, 34)];
}

@end

@implementation CCCalcHistoryView {
	UITableView *_tableView;
	UIButton *_clearButton;
	UIButton *_doneButton;
	UILabel *_emptyLabel;
	NSArray<NSDictionary<NSString *, NSString *> *> *_entries;
}

- (id)init {
	self = [super init];

	if(self) {
		_clearButton = [self headerButtonWithTitle:@"Clear" action:@selector(clearTapped)];
		[_clearButton setContentHorizontalAlignment:UIControlContentHorizontalAlignmentLeft];
		[self addSubview:_clearButton];

		_doneButton = [self headerButtonWithTitle:@"Done" action:@selector(doneTapped)];
		[_doneButton setContentHorizontalAlignment:UIControlContentHorizontalAlignmentRight];
		[[_doneButton titleLabel] setFont:[UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]];
		[self addSubview:_doneButton];

		_tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
		[_tableView setBackgroundColor:[UIColor clearColor]];
		[_tableView setSeparatorColor:[UIColor colorWithWhite:1.0 alpha:0.15]];
		[_tableView setSeparatorInset:UIEdgeInsetsMake(0, SIDE_MARGIN, 0, SIDE_MARGIN)];
		[_tableView setRowHeight:ROW_HEIGHT];
		[_tableView setShowsVerticalScrollIndicator:NO];
		[_tableView setTableFooterView:[[UIView alloc] init]];
		[_tableView registerClass:[CCCalcHistoryCell class] forCellReuseIdentifier:CELL_IDENTIFIER];
		[_tableView setDataSource:self];
		[_tableView setDelegate:self];
		[self addSubview:_tableView];

		_emptyLabel = [[UILabel alloc] init];
		[_emptyLabel setText:@"No History"];
		[_emptyLabel setTextColor:[UIColor colorWithWhite:1.0 alpha:0.55]];
		[_emptyLabel setFont:[UIFont systemFontOfSize:17]];
		[_emptyLabel setTextAlignment:NSTextAlignmentCenter];
		[self addSubview:_emptyLabel];
	}

	return self;
}

- (UIButton *)headerButtonWithTitle:(NSString *)title action:(SEL)action {
	UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
	[button setTitle:title forState:UIControlStateNormal];
	[button setTintColor:[UIColor whiteColor]];
	[button setTitleColor:[UIColor colorWithWhite:1.0 alpha:0.3] forState:UIControlStateDisabled];
	[[button titleLabel] setFont:[UIFont systemFontOfSize:17]];
	[button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
	return button;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGSize size = [self bounds].size;
	CGFloat buttonWidth = (size.width - SIDE_MARGIN * 2) / 2.0;

	[_clearButton setFrame:CGRectMake(SIDE_MARGIN, 0, buttonWidth, HEADER_HEIGHT)];
	[_doneButton setFrame:CGRectMake(SIDE_MARGIN + buttonWidth, 0, buttonWidth, HEADER_HEIGHT)];
	[_tableView setFrame:CGRectMake(0, HEADER_HEIGHT, size.width, size.height - HEADER_HEIGHT)];
	[_emptyLabel setFrame:[_tableView frame]];
}

- (void)reload {
	_entries = [[CCCalcHistory sharedHistory] entries];
	[_tableView reloadData];
	[_tableView setContentOffset:CGPointZero animated:NO];
	[_emptyLabel setHidden:(_entries.count > 0)];
	[_clearButton setEnabled:(_entries.count > 0)];
}

- (void)clearTapped {
	[[CCCalcHistory sharedHistory] clear];
	[self reload];
}

- (void)doneTapped {
	if(self.closeHandler)
		self.closeHandler();
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return _entries.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	CCCalcHistoryCell *cell = [tableView dequeueReusableCellWithIdentifier:CELL_IDENTIFIER forIndexPath:indexPath];
	NSDictionary<NSString *, NSString *> *entry = _entries[indexPath.row];
	[[cell expressionLabel] setText:entry[@"expression"]];
	[[cell resultLabel] setText:entry[@"result"]];
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[UIPasteboard generalPasteboard].string = _entries[indexPath.row][@"value"];
	[[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];

	//Briefly show "Copied" in place of the expression
	CCCalcHistoryCell *cell = (CCCalcHistoryCell *)[tableView cellForRowAtIndexPath:indexPath];
	[[cell expressionLabel] setText:@"Copied"];

	__weak UITableView *weakTableView = tableView;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		if(indexPath.row < [weakTableView numberOfRowsInSection:0])
			[weakTableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
	});
}

@end
