//
//  MobaProfileValidator.h
//  Moonlight
//

#import <Foundation/Foundation.h>

#import "MobaProfileError.h"

NS_ASSUME_NONNULL_BEGIN

@protocol MobaProfileValidating <NSObject>
- (BOOL)validateJSONObject:(NSDictionary *)jsonObject
               profileKind:(MobaProfileKind)profileKind
                      error:(NSError **)error;
@end

// Validates migrated schema-v1 dictionaries without mutating them or creating
// model objects. Unknown fields are ignored, while unknown formal enum values
// are rejected at their exact JSON path.
@interface MobaProfileValidator : NSObject <MobaProfileValidating>
@end

NS_ASSUME_NONNULL_END
