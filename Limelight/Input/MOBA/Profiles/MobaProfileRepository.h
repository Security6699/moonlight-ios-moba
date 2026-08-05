//
//  MobaProfileRepository.h
//  Moonlight
//

#import <Foundation/Foundation.h>

#import "MobaProfileDecoder.h"
#import "MobaProfileModels.h"
#import "MobaProfileStore.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const MobaRuntimeProfileRelativePath;
FOUNDATION_EXPORT NSString *const MobaInputProfileRelativePath;
FOUNDATION_EXPORT NSString *const MobaActiveLayoutProfileRelativePath;

// Owns only candidate loading and transactional active-snapshot replacement.
// It never writes profiles and never mutates Coordinator or input state.
@interface MobaProfileRepository : NSObject

@property (atomic, strong, readonly, nullable) MobaProfileSnapshot *activeSnapshot;

- (instancetype)initWithStore:(MobaProfileStore *)store;
- (instancetype)initWithStore:(MobaProfileStore *)store
                       decoder:(MobaProfileDecoder *)decoder NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (BOOL)reloadWithChampionRelativePath:(NSString *)championRelativePath
                                  error:(NSError **)error;

- (BOOL)loadRuntimeRelativePath:(NSString *)runtimeRelativePath
              inputRelativePath:(NSString *)inputRelativePath
             layoutRelativePath:(NSString *)layoutRelativePath
           championRelativePath:(NSString *)championRelativePath
                          error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
