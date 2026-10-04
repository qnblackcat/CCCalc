#import "CCCalcHistory.h"

static NSString *const HISTORY_KEY = @"History";
static const NSUInteger MAX_ENTRIES = 50;

@implementation CCCalcHistory {
    NSUserDefaults *_defaults;
}

+ (instancetype)sharedHistory {
    static CCCalcHistory *sharedHistory;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sharedHistory = [[CCCalcHistory alloc] init];
    });
    return sharedHistory;
}

- (id)init {
    self = [super init];
    if(self) {
        _defaults = [[NSUserDefaults alloc] initWithSuiteName:@"ai.paisseon.cccalc"];
    }
    return self;
}

- (NSArray<NSDictionary<NSString *, NSString *> *> *)entries {
    return [_defaults arrayForKey:HISTORY_KEY] ?: @[];
}

- (void)addExpression:(NSString *)expression result:(NSString *)result value:(NSString *)value {
    if(!expression || !result || !value)
        return;

    NSMutableArray *entries = [[self entries] mutableCopy];
    [entries insertObject:@{ @"expression": expression, @"result": result, @"value": value } atIndex:0];
    if(entries.count > MAX_ENTRIES)
        [entries removeObjectsInRange:NSMakeRange(MAX_ENTRIES, entries.count - MAX_ENTRIES)];

    [_defaults setObject:entries forKey:HISTORY_KEY];
}

- (void)clear {
    [_defaults removeObjectForKey:HISTORY_KEY];
}

@end
