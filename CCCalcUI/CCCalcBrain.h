#import "CCCalcButtons.h"

@interface CCCalcBrain : NSObject {
    //Alternating numbers and operators, e.g. @[@"1", @"+", @"2", @"×", @(3.5)]
    //Typed numbers are NSStrings, computed numbers are NSNumbers (or CCCalcLabeledValues
    //when they come from a function, e.g. 3 shown as "√(9)") so they keep full precision
    NSMutableArray *tokens;
    NSString *repeatOperator;
    NSString *previousExpression;
    id repeatOperand;

    BOOL isLastNumberFinal;
    BOOL isShowingResult;
    BOOL isShowingError;
}
- (void)evaluateTap:(unsigned)identifier;
- (NSString *)currentValue;
- (NSString *)currentValueWithCommas;
- (NSString *)previousExpression;
@end
