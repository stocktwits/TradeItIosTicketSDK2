#import "TradeItTypeDefs.h"
#import "TradeItResult.h"

@interface TradeItJsonConverter : NSObject

+ (NSMutableURLRequest *)buildJsonRequestForModel:(TIEMSJSONModel *)requestObject
                                        emsAction:(NSString *)action
                                      environment:(TradeitEmsEnvironments)env;


+ (TradeItResult *)buildResult:(TradeItResult *)tradeItResult
                    jsonString:(NSString *)jsonString;

+ (NSURL *)getEmsBaseUrlForEnvironment:(TradeitEmsEnvironments)env;
+ (NSString *)getEmsHostForEnvironment:(TradeitEmsEnvironments)env;

@end
