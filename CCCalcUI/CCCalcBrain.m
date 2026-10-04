#import "CCCalcBrain.h"
#import "CCCalcFunction.h"
#import "CCCalcHistory.h"

//This object handles all of the calculations
//The whole expression is built on one line (e.g. "2×(1+3)") and evaluated on "=",
//with parentheses first, then × and ÷, then + and −

static NSString *const OP_ADD = @"+";
static NSString *const OP_SUBTRACT = @"−";
static NSString *const OP_MULTIPLY = @"×";
static NSString *const OP_DIVIDE = @"÷";
static NSString *const PAREN_OPEN = @"(";
static NSString *const PAREN_CLOSE = @")";

static const NSUInteger MAX_DIGITS = 12;
static const NSUInteger MAX_EXPRESSION_LENGTH = 60;

//Computed numbers at or beyond these magnitudes are shown in scientific notation
static const double MAX_PLAIN_VALUE = 1e16;
static const double MIN_PLAIN_VALUE = 1e-9;

//A computed number that remembers how it was made, e.g. 3 shown as "√(9)"
@interface CCCalcLabeledValue : NSObject
@property (nonatomic) double doubleValue;
@property (nonatomic, copy) NSString *label;
@end

@implementation CCCalcLabeledValue
@end

@implementation CCCalcBrain

- (id)init {
    self = [super init];
    if(self) {
        tokens = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)evaluateTap:(unsigned)identifier {
    if(isShowingError)
        [self clearAll];

    NSString *operator = [CCCalcBrain operatorForIdentifier:identifier];

    if(identifier <= 9) {
        [self appendDigit:identifier];
    }
    else if(operator) {
        [self appendOperator:operator];
    }
    else {
        switch(identifier) {
            case BTN_DECIMAL:
                [self appendDecimal];
                break;

            case BTN_OPENPAREN:
                [self openParenthesis];
                break;

            case BTN_CLOSEPAREN:
                [self closeParenthesis];
                break;

            case BTN_DELETE:
                [self deleteBackward];
                break;

            case BTN_CLEAR:
                [self clearAll];
                break;

            case BTN_NEGATE:
                [self negate];
                break;

            case BTN_PERCENT:
                [self percent];
                break;

            case BTN_EQUAL:
                [self evaluate];
                break;

            case BTN_TRIGUNITSSWITCHER:
                [CCCalcFunction.functions[@(identifier)] evaluateWithInput:0];
                break;

            case BTN_PI:
            case BTN_EULERSNUMBER:
            case BTN_RANDOM:
                //Constants: start a new number, or replace the one being typed
                if(![self endsWithNumber] && [self isFull])
                    break;
                [self multiplyAfterClosingParenthesis];
                [self setLastNumberValue:[CCCalcFunction.functions[@(identifier)] evaluateWithInput:0] label:[CCCalcBrain labelForConstant:identifier]];
                break;

            default:
                if(CCCalcFunction.functions[@(identifier)])
                    [self applyFunction:CCCalcFunction.functions[@(identifier)] identifier:identifier];
        }
    }

    if(identifier != BTN_EQUAL && identifier != BTN_TRIGUNITSSWITCHER) {
        isShowingResult = NO;
        previousExpression = nil;
    }
}

#pragma mark - Editing

- (void)appendDigit:(unsigned)digit {
    NSString *digitString = [@(digit) stringValue];

    if(![self endsWithNumber]) {
        if([self isFull])
            return;
        [self multiplyAfterClosingParenthesis];
        [self setLastNumber:digitString final:NO];
        return;
    }
    if(isLastNumberFinal) {
        //Typing after a result, constant or function starts a new number
        [self setLastNumber:digitString final:NO];
        return;
    }

    NSString *number = tokens.lastObject;
    if([CCCalcBrain digitCount:number] >= MAX_DIGITS || [self isFull])
        return;

    if([number isEqualToString:@"0"])
        number = digitString;
    else if([number isEqualToString:@"-0"])
        number = [@"-" stringByAppendingString:digitString];
    else
        number = [number stringByAppendingString:digitString];

    [self setLastNumber:number final:NO];
}

- (void)appendDecimal {
    if(![self endsWithNumber] || isLastNumberFinal) {
        if(![self endsWithNumber] && [self isFull])
            return;
        [self multiplyAfterClosingParenthesis];
        [self setLastNumber:@"0." final:NO];
        return;
    }

    NSString *number = tokens.lastObject;
    if([number containsString:@"."] || [self isFull])
        return;

    [self setLastNumber:[number stringByAppendingString:@"."] final:NO];
}

- (void)appendOperator:(NSString *)operator {
    if(tokens.count == 0)
        [tokens addObject:@"0"];

    id last = tokens.lastObject;
    if([CCCalcBrain isOperator:last]) {
        //Tapping another operator replaces the previous one
        tokens[tokens.count - 1] = operator;
    }
    else if([self endsWithOperand]) {
        if([self isFull])
            return;
        [self trimTrailingDecimal];
        [tokens addObject:operator];
    }
    //An operator right after "(" is ignored, use ± for negative numbers
    isLastNumberFinal = NO;
}

- (void)openParenthesis {
    //"(" after a result starts a new expression
    if(isShowingResult)
        [self clearAll];
    if([self isFull])
        return;

    //"2(" means "2×("
    if([self endsWithOperand]) {
        [self trimTrailingDecimal];
        [tokens addObject:OP_MULTIPLY];
    }
    [tokens addObject:PAREN_OPEN];
    isLastNumberFinal = NO;
}

- (void)closeParenthesis {
    if([CCCalcBrain openParenthesisCount:tokens] == 0 || ![self endsWithOperand] || [self isFull])
        return;

    [self trimTrailingDecimal];
    [tokens addObject:PAREN_CLOSE];
    isLastNumberFinal = NO;
}

- (void)deleteBackward {
    if(tokens.count == 0)
        return;

    id last = tokens.lastObject;
    BOOL isTypedNumber = [last isKindOfClass:[NSString class]] && ![CCCalcBrain isSymbol:last];

    if(isTypedNumber && [last length] > 1) {
        NSString *number = [last substringToIndex:[last length] - 1];
        if([number isEqualToString:@"-"])
            [tokens removeLastObject];
        else
            tokens[tokens.count - 1] = number;
    }
    else {
        //Operators, parentheses, single digits and computed numbers go in one tap
        [tokens removeLastObject];
    }

    isLastNumberFinal = tokens.count > 0 && ![tokens.lastObject isKindOfClass:[NSString class]];
    repeatOperator = nil;
}

- (void)clearAll {
    [tokens removeAllObjects];
    repeatOperator = nil;
    previousExpression = nil;
    isLastNumberFinal = NO;
    isShowingError = NO;
}

- (void)negate {
    if(![self endsWithNumber]) {
        if([self endsWithOperand] || [self isFull])
            return;
        [self setLastNumber:@"-0" final:NO];
        return;
    }

    id number = tokens.lastObject;
    if(![number isKindOfClass:[NSString class]]) {
        //Computed numbers flip their value, and their label if they have one
        NSString *label = [number isKindOfClass:[CCCalcLabeledValue class]] ? [CCCalcBrain toggleSign:[number label]] : nil;
        [self setLastNumberValue:-[number doubleValue] label:label];
        return;
    }

    [self setLastNumber:[CCCalcBrain toggleSign:number] final:isLastNumberFinal];
}

- (void)percent {
    if(![self endsWithNumber])
        return;

    double value = [tokens.lastObject doubleValue];
    NSUInteger count = tokens.count;

    //"200+10%" means 10% of 200, like the stock calculator
    if(count >= 3 && ([tokens[count - 2] isEqual:OP_ADD] || [tokens[count - 2] isEqual:OP_SUBTRACT])) {
        //Only look back as far as the innermost open parenthesis
        NSUInteger start = count - 2;
        NSInteger depth = 0;
        while(start > 0) {
            id token = tokens[start - 1];
            if([token isEqual:PAREN_CLOSE])
                depth++;
            else if([token isEqual:PAREN_OPEN] && depth-- == 0)
                break;
            start--;
        }

        if(start < count - 2) {
            double base = [CCCalcBrain evaluateTokens:[tokens subarrayWithRange:NSMakeRange(start, count - 2 - start)]];
            value = base * value / 100.0;
        }
        else {
            value = value / 100.0;
        }
    }
    else {
        value = value / 100.0;
    }

    [self setLastNumberValue:value];
}

- (void)applyFunction:(CCCalcFunction *)function identifier:(unsigned)identifier {
    if(tokens.count > 0 && ![self endsWithNumber])
        return;

    id input = [self endsWithNumber] ? tokens.lastObject : @"0";
    NSString *label = [CCCalcBrain labelForFunction:identifier input:[CCCalcBrain displayStringForNumber:input]];
    [self setLastNumberValue:[function evaluateWithInput:[input doubleValue]] label:label];
}

- (void)evaluate {
    //Tapping "=" again repeats the last operation, e.g. "2+3==" gives 8
    if(isShowingResult && repeatOperator && tokens.count == 1) {
        previousExpression = [CCCalcBrain displayStringForTokens:@[tokens[0], repeatOperator, repeatOperand]];
        [self showResult:[CCCalcBrain applyOperator:repeatOperator to:[tokens[0] doubleValue] and:[repeatOperand doubleValue]]];
        return;
    }

    [tokens setArray:[CCCalcBrain completedExpression:tokens]];
    if(tokens.count == 1 && [tokens[0] isKindOfClass:[CCCalcLabeledValue class]]) {
        //A lone function such as "√(9)" still counts as a calculation
        repeatOperator = nil;
        previousExpression = [self currentValueWithCommas];
        [self showResult:[tokens[0] doubleValue]];
        return;
    }
    if(tokens.count <= 1) {
        isLastNumberFinal = [self endsWithNumber];
        return;
    }

    NSUInteger count = tokens.count;
    if([CCCalcBrain isOperator:tokens[count - 2]] && ![tokens.lastObject isEqual:PAREN_CLOSE]) {
        repeatOperator = tokens[count - 2];
        repeatOperand = tokens.lastObject;
    }
    else {
        repeatOperator = nil;
    }
    previousExpression = [self currentValueWithCommas];
    [self showResult:[CCCalcBrain evaluateTokens:tokens]];
}

#pragma mark - State helpers

- (BOOL)endsWithNumber {
    return tokens.count > 0 && ![CCCalcBrain isSymbol:tokens.lastObject];
}

//A number or ")", anything that can be followed by an operator
- (BOOL)endsWithOperand {
    return [self endsWithNumber] || [tokens.lastObject isEqual:PAREN_CLOSE];
}

- (void)multiplyAfterClosingParenthesis {
    //"(1+2)3" means "(1+2)×3"
    if([tokens.lastObject isEqual:PAREN_CLOSE])
        [tokens addObject:OP_MULTIPLY];
}

- (void)trimTrailingDecimal {
    id number = tokens.lastObject;
    if([number isKindOfClass:[NSString class]] && [number hasSuffix:@"."])
        tokens[tokens.count - 1] = [number substringToIndex:[number length] - 1];
}

- (BOOL)isFull {
    return [self currentValueWithCommas].length >= MAX_EXPRESSION_LENGTH;
}

- (void)setLastNumber:(id)number final:(BOOL)final {
    if([self endsWithNumber])
        tokens[tokens.count - 1] = number;
    else
        [tokens addObject:number];
    isLastNumberFinal = final;
}

- (void)setLastNumberValue:(double)value {
    if(!isfinite(value)) {
        [self showError];
        return;
    }
    if(value == 0)
        value = 0; //avoid showing "-0"
    [self setLastNumber:@(value) final:YES];
}

- (void)setLastNumberValue:(double)value label:(NSString *)label {
    if(!label) {
        [self setLastNumberValue:value];
        return;
    }
    if(!isfinite(value)) {
        [self showError];
        return;
    }

    CCCalcLabeledValue *labeledValue = [[CCCalcLabeledValue alloc] init];
    labeledValue.doubleValue = (value == 0 ? 0 : value);
    labeledValue.label = label;
    [self setLastNumber:labeledValue final:YES];
}

- (void)showResult:(double)result {
    if(!isfinite(result)) {
        [self showError];
        return;
    }
    [tokens removeAllObjects];
    [self setLastNumberValue:result];
    isShowingResult = YES;

    [[CCCalcHistory sharedHistory] addExpression:previousExpression result:[self currentValueWithCommas] value:[self currentValue]];
}

- (void)showError {
    [tokens removeAllObjects];
    repeatOperator = nil;
    isShowingError = YES;
}

//What was calculated, shown above the result after "="
- (NSString *)previousExpression {
    return previousExpression;
}

#pragma mark - Math

+ (NSString *)operatorForIdentifier:(unsigned)identifier {
    switch(identifier) {
        case BTN_ADD:
            return OP_ADD;
        case BTN_SUBTRACT:
            return OP_SUBTRACT;
        case BTN_MULTIPLY:
            return OP_MULTIPLY;
        case BTN_DIVIDE:
            return OP_DIVIDE;
        default:
            return nil;
    }
}

+ (BOOL)isOperator:(id)token {
    return [token isEqual:OP_ADD] || [token isEqual:OP_SUBTRACT] || [token isEqual:OP_MULTIPLY] || [token isEqual:OP_DIVIDE];
}

//Operators and parentheses, i.e. anything that isn't a number
+ (BOOL)isSymbol:(id)token {
    return [self isOperator:token] || [token isEqual:PAREN_OPEN] || [token isEqual:PAREN_CLOSE];
}

+ (double)applyOperator:(NSString *)operator to:(double)first and:(double)second {
    if([operator isEqualToString:OP_ADD])
        return first + second;
    else if([operator isEqualToString:OP_SUBTRACT])
        return first - second;
    else if([operator isEqualToString:OP_MULTIPLY])
        return first * second;
    else
        return first / second;
}

//Drops a dangling operator or "(" at the end and closes any open parentheses, so "2×(1+" becomes "2×(1)"
+ (NSArray *)completedExpression:(NSArray *)expression {
    NSMutableArray *completed = [expression mutableCopy];
    while(completed.count > 0 && ([self isOperator:completed.lastObject] || [completed.lastObject isEqual:PAREN_OPEN]))
        [completed removeLastObject];

    for(NSInteger open = [self openParenthesisCount:completed]; open > 0; open--)
        [completed addObject:PAREN_CLOSE];

    return completed;
}

+ (NSInteger)openParenthesisCount:(NSArray *)expression {
    NSInteger count = 0;
    for(id token in expression) {
        if([token isEqual:PAREN_OPEN])
            count++;
        else if([token isEqual:PAREN_CLOSE])
            count--;
    }
    return count;
}

+ (double)evaluateTokens:(NSArray *)expression {
    NSArray *completed = [self completedExpression:expression];
    NSUInteger position = 0;
    return [self parseSum:completed position:&position];
}

//sum := product (("+" | "−") product)*
+ (double)parseSum:(NSArray *)expression position:(NSUInteger *)position {
    double result = [self parseProduct:expression position:position];
    while(*position < expression.count && ([expression[*position] isEqual:OP_ADD] || [expression[*position] isEqual:OP_SUBTRACT])) {
        NSString *operator = expression[(*position)++];
        result = [self applyOperator:operator to:result and:[self parseProduct:expression position:position]];
    }
    return result;
}

//product := factor (("×" | "÷") factor)*
+ (double)parseProduct:(NSArray *)expression position:(NSUInteger *)position {
    double result = [self parseFactor:expression position:position];
    while(*position < expression.count && ([expression[*position] isEqual:OP_MULTIPLY] || [expression[*position] isEqual:OP_DIVIDE])) {
        NSString *operator = expression[(*position)++];
        result = [self applyOperator:operator to:result and:[self parseFactor:expression position:position]];
    }
    return result;
}

//factor := number | "(" sum ")"
+ (double)parseFactor:(NSArray *)expression position:(NSUInteger *)position {
    if(*position >= expression.count)
        return 0;

    id token = expression[(*position)++];
    if([token isEqual:PAREN_OPEN]) {
        double result = [self parseSum:expression position:position];
        if(*position < expression.count && [expression[*position] isEqual:PAREN_CLOSE])
            (*position)++;
        return result;
    }
    if([self isSymbol:token])
        return 0;
    return [token doubleValue];
}

+ (NSString *)toggleSign:(NSString *)number {
    return [number hasPrefix:@"-"] ? [number substringFromIndex:1] : [@"-" stringByAppendingString:number];
}

+ (NSUInteger)digitCount:(NSString *)number {
    NSUInteger count = 0;
    for(NSUInteger i = 0; i < number.length; i++) {
        unichar c = [number characterAtIndex:i];
        if(c >= '0' && c <= '9')
            count++;
    }
    return count;
}

#pragma mark - Labels

+ (NSString *)labelForConstant:(unsigned)identifier {
    if(identifier == BTN_PI)
        return @"π";
    if(identifier == BTN_EULERSNUMBER)
        return @"e";
    return nil; //Random shows its value
}

+ (NSString *)labelForFunction:(unsigned)identifier input:(NSString *)input {
    if([input hasSuffix:@"."])
        input = [input substringToIndex:input.length - 1];

    //Exponents only need parentheses around anything other than a plain positive number: "9²" but "(-9)²"
    NSCharacterSet *notPlain = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789.,"] invertedSet];
    NSString *base = [input rangeOfCharacterFromSet:notPlain].location == NSNotFound ? input : [NSString stringWithFormat:@"(%@)", input];
    NSString *degrees = [CCCalcFunction isUsingDegrees] ? @"°" : @"";

    switch(identifier) {
        case BTN_SINE:
            return [NSString stringWithFormat:@"sin(%@%@)", input, degrees];
        case BTN_COSINE:
            return [NSString stringWithFormat:@"cos(%@%@)", input, degrees];
        case BTN_TANGENT:
            return [NSString stringWithFormat:@"tan(%@%@)", input, degrees];
        case BTN_INVERSESINE:
            return [NSString stringWithFormat:@"sin⁻¹(%@)", input];
        case BTN_INVERSECOSINE:
            return [NSString stringWithFormat:@"cos⁻¹(%@)", input];
        case BTN_INVERSETANGENT:
            return [NSString stringWithFormat:@"tan⁻¹(%@)", input];
        case BTN_SQUAREROOT:
            return [NSString stringWithFormat:@"√(%@)", input];
        case BTN_CUBEROOT:
            return [NSString stringWithFormat:@"∛(%@)", input];
        case BTN_LOGARITHM:
            return [NSString stringWithFormat:@"log(%@)", input];
        case BTN_NATURALLOGARITHM:
            return [NSString stringWithFormat:@"ln(%@)", input];
        case BTN_SQUARE:
            return [NSString stringWithFormat:@"%@²", base];
        case BTN_CUBE:
            return [NSString stringWithFormat:@"%@³", base];
        case BTN_RECIPROCAL:
            return [NSString stringWithFormat:@"%@⁻¹", base];
        case BTN_EXPONENTIAL:
            return [NSString stringWithFormat:@"e^%@", base];
        case BTN_TENRAISEDTOX:
            return [NSString stringWithFormat:@"10^%@", base];
        default:
            return nil;
    }
}

#pragma mark - Display

+ (NSNumberFormatter *)formatterWithStyle:(NSNumberFormatterStyle)style grouping:(BOOL)grouping {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.numberStyle = style;
    formatter.usesSignificantDigits = YES;
    formatter.maximumSignificantDigits = 15;
    formatter.usesGroupingSeparator = grouping;
    formatter.groupingSeparator = @",";
    formatter.decimalSeparator = @".";
    return formatter;
}

+ (NSString *)formatValue:(double)value grouping:(BOOL)grouping {
    static NSNumberFormatter *groupedFormatter;
    static NSNumberFormatter *plainFormatter;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        groupedFormatter = [self formatterWithStyle:NSNumberFormatterDecimalStyle grouping:YES];
        plainFormatter = [self formatterWithStyle:NSNumberFormatterDecimalStyle grouping:NO];
    });

    double magnitude = fabs(value);
    if(magnitude >= MAX_PLAIN_VALUE || (magnitude > 0 && magnitude < MIN_PLAIN_VALUE)) {
        //"%.10g" gives e.g. "9.9999998e+18", shortened to "9.9999998e18"
        NSString *scientific = [NSString stringWithFormat:@"%.10g", value];
        scientific = [scientific stringByReplacingOccurrencesOfString:@"e+" withString:@"e"];
        return [scientific stringByReplacingOccurrencesOfString:@"e(-?)0+(?=\\d)" withString:@"e$1" options:NSRegularExpressionSearch range:NSMakeRange(0, scientific.length)];
    }

    return [(grouping ? groupedFormatter : plainFormatter) stringFromNumber:@(value)];
}

+ (NSString *)commaFormat:(NSString *)input {
    NSString *formatted = @"";
    BOOL isNegative = NO;

    if([input hasPrefix:@"-"]) {
        isNegative = YES;
        input = [input substringFromIndex:1];
    }

    int start = input.length % 3;

    for(int c = 0; c < input.length; c++) {
        if((c - start) % 3 == 0 && c != 0) {
            formatted = [formatted stringByAppendingString:@","];
        }
        formatted = [formatted stringByAppendingString:[input substringWithRange:NSMakeRange(c, 1)]];
    }

    return isNegative ? [@"-" stringByAppendingString:formatted] : formatted;
}

+ (NSString *)displayStringForNumber:(id)number {
    if([number isKindOfClass:[CCCalcLabeledValue class]])
        return [number label];
    if([number isKindOfClass:[NSNumber class]])
        return [self formatValue:[number doubleValue] grouping:YES];

    //Typed numbers are shown exactly as typed, including a trailing "."
    NSRange decimal = [number rangeOfString:@"."];
    if(decimal.location == NSNotFound)
        return [self commaFormat:number];

    return [[self commaFormat:[number substringToIndex:decimal.location]] stringByAppendingString:[number substringFromIndex:decimal.location]];
}

//The plain value of the expression, used when copying from the display
- (NSString *)currentValue {
    if(isShowingError)
        return @"Error";

    double value = [CCCalcBrain evaluateTokens:tokens];
    if(!isfinite(value))
        return @"Error";
    return [CCCalcBrain formatValue:(value == 0 ? 0 : value) grouping:NO];
}

- (NSString *)currentValueWithCommas {
    if(isShowingError)
        return @"Error";
    if(tokens.count == 0)
        return @"0";
    return [CCCalcBrain displayStringForTokens:tokens];
}

+ (NSString *)displayStringForTokens:(NSArray *)tokens {
    NSMutableString *display = [NSMutableString string];
    for(NSUInteger i = 0; i < tokens.count; i++) {
        id token = tokens[i];
        if([self isSymbol:token]) {
            [display appendString:token];
            continue;
        }

        NSString *number = [self displayStringForNumber:token];
        //Wrap negative numbers after an operator so "5−-3" reads as "5−(-3)"
        if(i > 0 && [self isOperator:tokens[i - 1]] && [number hasPrefix:@"-"])
            [display appendFormat:@"(%@)", number];
        else
            [display appendString:number];
    }
    return display;
}

@end
