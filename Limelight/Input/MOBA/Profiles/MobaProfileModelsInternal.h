//
//  MobaProfileModelsInternal.h
//  Moonlight
//

#import "MobaProfileModels.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT MobaRuntimeProfile *MobaRuntimeProfileFromValidatedJSON(NSDictionary *json);
FOUNDATION_EXPORT MobaInputProfile *MobaInputProfileFromValidatedJSON(NSDictionary *json);
FOUNDATION_EXPORT MobaLayoutProfile *MobaLayoutProfileFromValidatedJSON(NSDictionary *json);
FOUNDATION_EXPORT MobaChampionProfile *MobaChampionProfileFromValidatedJSON(NSDictionary *json);

NS_ASSUME_NONNULL_END
