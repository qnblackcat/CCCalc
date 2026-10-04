#import <Foundation/Foundation.h>

//Past calculations, saved in the tweak's preferences so they survive resprings
@interface CCCalcHistory : NSObject
+ (instancetype)sharedHistory;
//Newest first, each entry has "expression" and "result" as displayed, and "value" as plain text for copying
- (NSArray<NSDictionary<NSString *, NSString *> *> *)entries;
- (void)addExpression:(NSString *)expression result:(NSString *)result value:(NSString *)value;
- (void)clear;
@end
