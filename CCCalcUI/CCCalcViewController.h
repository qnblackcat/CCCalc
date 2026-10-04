#import "CCCalcButton.h"
#import "CCCalcBrain.h"
#import "CCCalcDisplayView.h"
#import "CCCalcScrollView.h"
#import "CCCalcPage.h"
#import "CCCalcHistoryView.h"

@interface CCCalcViewController : UIViewController <CCCalcDelegate, UIScrollViewDelegate> {
    CCCalcScrollView *_scrollView;
    CCCalcPage *_pageOne;
    CCCalcPage *_pageTwo;
    CCCalcHistoryView *_historyView;
    BOOL _didLayout;
}
@property (nonatomic, retain) NSMutableDictionary<NSNumber *, CCCalcButton *> *buttons;
@property (nonatomic, retain) CCCalcDisplayView *displayView;
@property (nonatomic, retain) CCCalcBrain *brain;
- (void)buttonTapped:(unsigned)identifier;
- (void)showHistory;
- (void)hideHistory;
- (BOOL)_canShowWhileLocked;
@end
