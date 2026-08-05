//
//  MobaProfileMigrator.h
//  Moonlight
//

#import <Foundation/Foundation.h>

#import "MobaProfileError.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT const NSUInteger MobaProfileCurrentSchemaVersion;

@protocol MobaProfileMigrating <NSObject>
- (nullable NSDictionary *)migrateJSONObject:(NSDictionary *)jsonObject
                                  profileKind:(MobaProfileKind)profileKind
                                        error:(NSError **)error;
@end

// Schema v1 currently has an identity migration. This explicit boundary is
// replaceable so future versions can transform JSON before validation.
@interface MobaProfileMigrator : NSObject <MobaProfileMigrating>
@end

NS_ASSUME_NONNULL_END
