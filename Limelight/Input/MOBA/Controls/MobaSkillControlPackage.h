//
//  MobaSkillControlPackage.h
//  Moonlight
//

#import <Foundation/Foundation.h>

#import "../Casting/MobaCastStrategyFactory.h"
#import "../Core/MobaOverlayLifecycle.h"

@class MobaSkillButtonView;
@class MobaSkillCastController;

NS_ASSUME_NONNULL_BEGIN

// A fully prepared, still-detached set of Q/W/E/R controls. Champion
// selection validates this package before committing the candidate snapshot.
@interface MobaSkillControlPackage : NSObject

@property (nonatomic, copy, readonly) NSDictionary<MobaCanonicalSkillSlot, MobaSkillCastController *> *controllers;
@property (nonatomic, copy, readonly) NSDictionary<MobaCanonicalSkillSlot, MobaSkillButtonView *> *skillButtonViews;
@property (nonatomic, copy, readonly) NSArray<id<MobaLocalInteractionResetParticipant>> *localInteractionResetParticipants;
@property (nonatomic, readonly, getter=isComplete) BOOL complete;

- (instancetype)initWithControllers:(NSDictionary<MobaCanonicalSkillSlot, MobaSkillCastController *> *)controllers
                    skillButtonViews:(NSDictionary<MobaCanonicalSkillSlot, MobaSkillButtonView *> *)skillButtonViews NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

// Candidate cleanup only. No configured cancel action or remote input is sent.
- (void)silentResetForReason:(MobaInputInterruptionReason)reason;

@end

@protocol MobaSkillControlPackageBuilding <NSObject>

- (nullable MobaSkillControlPackage *)controlPackageForRuntime:(MobaChampionRuntime *)runtime
                                                         error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
