//
//  MobaProfileDecoder.h
//  Moonlight
//

#import <Foundation/Foundation.h>

#import "MobaProfileError.h"
#import "MobaProfileMigrator.h"
#import "MobaProfileModels.h"
#import "MobaProfileValidator.h"

NS_ASSUME_NONNULL_BEGIN

@interface MobaProfileDecoder : NSObject

- (instancetype)init;
- (instancetype)initWithMigrator:(id<MobaProfileMigrating>)migrator
                         validator:(id<MobaProfileValidating>)validator NS_DESIGNATED_INITIALIZER;

- (nullable MobaRuntimeProfile *)decodeRuntimeProfileData:(NSData *)data error:(NSError **)error;
- (nullable MobaInputProfile *)decodeInputProfileData:(NSData *)data error:(NSError **)error;
- (nullable MobaLayoutProfile *)decodeLayoutProfileData:(NSData *)data error:(NSError **)error;
- (nullable MobaChampionProfile *)decodeChampionProfileData:(NSData *)data error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
