//
//  MobaCastStrategyFactory.m
//  Moonlight
//

#import "MobaCastStrategyFactory.h"

#import <math.h>

#import "../Core/MobaCADisplayLinkDriver.h"
#import "../Core/MobaInputDispatcher.h"

NSErrorDomain const MobaCastStrategyFactoryErrorDomain = @"MobaCastStrategyFactoryErrorDomain";
NSString *const MobaCastStrategyFactoryChampionIDKey = @"MobaCastStrategyFactoryChampionID";
NSString *const MobaCastStrategyFactorySkillSlotKey = @"MobaCastStrategyFactorySkillSlot";
NSString *const MobaCastStrategyFactoryFieldPathKey = @"MobaCastStrategyFactoryFieldPath";
NSString *const MobaCastStrategyFactoryOperationKey = @"MobaCastStrategyFactoryOperation";

MobaCanonicalSkillSlot const MobaCanonicalSkillSlotQ = @"Q";
MobaCanonicalSkillSlot const MobaCanonicalSkillSlotW = @"W";
MobaCanonicalSkillSlot const MobaCanonicalSkillSlotE = @"E";
MobaCanonicalSkillSlot const MobaCanonicalSkillSlotR = @"R";

const NSUInteger MobaDefaultKeyboardCancelTapDurationMs = 30;

@interface MobaCanonicalSkillDefinition : NSObject
@property (nonatomic, copy) MobaCanonicalSkillSlot skillSlot;
@property (nonatomic, copy) NSString *layoutControlName;
@end

@implementation MobaCanonicalSkillDefinition
@end

static NSArray<MobaCanonicalSkillDefinition *> *MobaCanonicalSkillDefinitions(void) {
    static NSArray<MobaCanonicalSkillDefinition *> *definitions;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableArray *items = [NSMutableArray array];
        for (NSArray<NSString *> *values in @[
            @[MobaCanonicalSkillSlotQ, @"abilityQ"],
            @[MobaCanonicalSkillSlotW, @"abilityW"],
            @[MobaCanonicalSkillSlotE, @"abilityE"],
            @[MobaCanonicalSkillSlotR, @"abilityR"],
        ]) {
            MobaCanonicalSkillDefinition *definition = [[MobaCanonicalSkillDefinition alloc] init];
            definition.skillSlot = values[0];
            definition.layoutControlName = values[1];
            [items addObject:definition];
        }
        definitions = [items copy];
    });
    return definitions;
}

NSArray<MobaCanonicalSkillSlot> *MobaCanonicalSkillSlots(void) {
    static NSArray<MobaCanonicalSkillSlot> *slots;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableArray *items = [NSMutableArray array];
        for (MobaCanonicalSkillDefinition *definition in MobaCanonicalSkillDefinitions()) {
            [items addObject:definition.skillSlot];
        }
        slots = [items copy];
    });
    return slots;
}

@implementation MobaCADisplayLinkDriverProvider
- (id<MobaDisplayLinkDriving>)newDisplayLinkDriver {
    return [[MobaCADisplayLinkDriver alloc] init];
}
@end

@interface MobaSkillRuntimeDescriptor ()
- (instancetype)initWithSkillSlot:(MobaCanonicalSkillSlot)skillSlot
                     displayLabel:(NSString *)displayLabel
                layoutControlName:(NSString *)layoutControlName
                      inputAction:(NSString *)inputAction
                      hostKeyCode:(uint16_t)hostKeyCode
                         castType:(MobaProfileSkillCastType)castType
                      allowCancel:(BOOL)allowCancel
                     skillProfile:(MobaChampionSkillProfile *)skillProfile
             layoutControlProfile:(MobaLayoutControlProfile *)layoutControlProfile
                         strategy:(id<MobaCastStrategy>)strategy
                  cursorCoalescer:(nullable MobaCursorCoalescer *)cursorCoalescer
             instantConfiguration:(nullable MobaInstantCastConfiguration *)instantConfiguration
         directionalConfiguration:(nullable MobaDirectionalCastConfiguration *)directionalConfiguration
               pointConfiguration:(nullable MobaPointCastConfiguration *)pointConfiguration;
@end

@implementation MobaSkillRuntimeDescriptor
- (instancetype)initWithSkillSlot:(MobaCanonicalSkillSlot)skillSlot
                     displayLabel:(NSString *)displayLabel
                layoutControlName:(NSString *)layoutControlName
                      inputAction:(NSString *)inputAction
                      hostKeyCode:(uint16_t)hostKeyCode
                         castType:(MobaProfileSkillCastType)castType
                      allowCancel:(BOOL)allowCancel
                     skillProfile:(MobaChampionSkillProfile *)skillProfile
             layoutControlProfile:(MobaLayoutControlProfile *)layoutControlProfile
                         strategy:(id<MobaCastStrategy>)strategy
                  cursorCoalescer:(MobaCursorCoalescer *)cursorCoalescer
             instantConfiguration:(MobaInstantCastConfiguration *)instantConfiguration
         directionalConfiguration:(MobaDirectionalCastConfiguration *)directionalConfiguration
               pointConfiguration:(MobaPointCastConfiguration *)pointConfiguration {
    self = [super init];
    if (self) {
        _skillSlot = [skillSlot copy];
        _displayLabel = [displayLabel copy];
        _layoutControlName = [layoutControlName copy];
        _inputAction = [inputAction copy];
        _hostKeyCode = hostKeyCode;
        _castType = castType;
        _allowCancel = allowCancel;
        _skillProfile = skillProfile;
        _layoutControlProfile = layoutControlProfile;
        _strategy = strategy;
        _cursorCoalescer = cursorCoalescer;
        _instantConfiguration = instantConfiguration;
        _directionalConfiguration = directionalConfiguration;
        _pointConfiguration = pointConfiguration;
    }
    return self;
}
@end

@interface MobaChampionRuntime ()
- (instancetype)initWithChampionProfile:(MobaChampionProfile *)championProfile
                        skillDescriptors:(NSDictionary<MobaCanonicalSkillSlot, MobaSkillRuntimeDescriptor *> *)skillDescriptors
          localInteractionResetParticipants:(NSArray<id<MobaLocalInteractionResetParticipant>> *)participants;
@end

@implementation MobaChampionRuntime
- (instancetype)initWithChampionProfile:(MobaChampionProfile *)championProfile
                        skillDescriptors:(NSDictionary<MobaCanonicalSkillSlot, MobaSkillRuntimeDescriptor *> *)skillDescriptors
          localInteractionResetParticipants:(NSArray<id<MobaLocalInteractionResetParticipant>> *)participants {
    self = [super init];
    if (self) {
        _championID = [championProfile.championID copy];
        _displayName = [championProfile.displayName copy];
        _displayNameZhCN = [championProfile.displayNameZhCN copy];
        _calibrationStatus = [championProfile.calibrationStatus copy];
        _skillDescriptors = [skillDescriptors copy];
        _localInteractionResetParticipants = [participants copy];
    }
    return self;
}

- (MobaSkillRuntimeDescriptor *)descriptorForSkillSlot:(MobaCanonicalSkillSlot)skillSlot {
    return self.skillDescriptors[skillSlot];
}
@end

@implementation MobaCastStrategyFactory {
    MobaInputDispatcher *_dispatcher;
    id<MobaDisplayLinkDriverProviding> _driverProvider;
}

- (instancetype)initWithDispatcher:(MobaInputDispatcher *)dispatcher
                     driverProvider:(id<MobaDisplayLinkDriverProviding>)driverProvider {
    if (dispatcher == nil || driverProvider == nil) {
        return nil;
    }
    self = [super init];
    if (self) {
        _dispatcher = dispatcher;
        _driverProvider = driverProvider;
    }
    return self;
}

- (NSError *)errorWithCode:(MobaCastStrategyFactoryErrorCode)code
                championID:(NSString *)championID
                  skillSlot:(nullable NSString *)skillSlot
                  fieldPath:(NSString *)fieldPath
                  operation:(NSString *)operation
                description:(NSString *)description
            underlyingError:(nullable NSError *)underlyingError {
    NSMutableDictionary *userInfo = [@{
        NSLocalizedDescriptionKey: [description copy],
        MobaCastStrategyFactoryChampionIDKey: [championID copy],
        MobaCastStrategyFactoryFieldPathKey: [fieldPath copy],
        MobaCastStrategyFactoryOperationKey: [operation copy],
    } mutableCopy];
    if (skillSlot != nil) {
        userInfo[MobaCastStrategyFactorySkillSlotKey] = [skillSlot copy];
    }
    if (underlyingError != nil) {
        userInfo[NSUnderlyingErrorKey] = underlyingError;
    }
    return [NSError errorWithDomain:MobaCastStrategyFactoryErrorDomain code:code userInfo:userInfo];
}

- (BOOL)failWithCode:(MobaCastStrategyFactoryErrorCode)code
           championID:(NSString *)championID
             skillSlot:(nullable NSString *)skillSlot
             fieldPath:(NSString *)fieldPath
             operation:(NSString *)operation
           description:(NSString *)description
                 error:(NSError **)error {
    if (error != NULL) {
        *error = [self errorWithCode:code
                          championID:championID
                            skillSlot:skillSlot
                            fieldPath:fieldPath
                            operation:operation
                          description:description
                      underlyingError:nil];
    }
    return NO;
}

- (nullable MobaCastCancelAction *)cancelActionForProfile:(MobaCancelCastActionProfile *)profile
                                              championID:(NSString *)championID
                                                skillSlot:(NSString *)skillSlot
                                               allowCancel:(BOOL)allowCancel
                                                     error:(NSError **)error {
    if (!allowCancel) {
        return [MobaCastCancelAction releaseOnlyAction];
    }
    switch (profile.type) {
        case MobaProfileCancelTypeKeyboard:
            if (!profile.hasKeyCode) {
                [self failWithCode:MobaCastStrategyFactoryErrorUnsupportedRuntimeCombination
                        championID:championID
                          skillSlot:skillSlot
                          fieldPath:@"$.cancelCastAction.keyCode"
                          operation:@"map-cancel-action"
                        description:@"Keyboard cancellation requires a key code."
                              error:error];
                return nil;
            }
            return [MobaCastCancelAction keyboardActionWithKeyCode:profile.keyCode
                                                        durationMs:MobaDefaultKeyboardCancelTapDurationMs];
        case MobaProfileCancelTypeRightMouse:
            return [MobaCastCancelAction rightMouseAction];
        case MobaProfileCancelTypeReleaseOnly:
            return [MobaCastCancelAction releaseOnlyAction];
    }
    [self failWithCode:MobaCastStrategyFactoryErrorUnsupportedRuntimeCombination
            championID:championID
              skillSlot:skillSlot
              fieldPath:@"$.cancelCastAction.type"
              operation:@"map-cancel-action"
            description:@"The cancel action type cannot be assembled."
                  error:error];
    return nil;
}

- (nullable MobaCursorCoalescer *)newCoalescerForSnapshot:(MobaProfileSnapshot *)snapshot
                                               championID:(NSString *)championID
                                                 skillSlot:(NSString *)skillSlot
                                                      error:(NSError **)error {
    id<MobaDisplayLinkDriving> driver = [_driverProvider newDisplayLinkDriver];
    if (driver == nil) {
        [self failWithCode:MobaCastStrategyFactoryErrorDisplayLinkCreationFailed
                championID:championID
                  skillSlot:skillSlot
                  fieldPath:@"$.mouseUpdateRateHz"
                  operation:@"create-display-link-driver"
                description:@"The display-link provider did not create a driver."
                      error:error];
        return nil;
    }
    MobaCursorCoalescer *coalescer = [[MobaCursorCoalescer alloc]
        initWithDispatcher:_dispatcher
                    driver:driver
                updateRate:(MobaCursorUpdateRate)snapshot.runtimeProfile.mouseUpdateRateHz];
    if (coalescer == nil) {
        [self failWithCode:MobaCastStrategyFactoryErrorDisplayLinkCreationFailed
                championID:championID
                  skillSlot:skillSlot
                  fieldPath:@"$.mouseUpdateRateHz"
                  operation:@"create-cursor-coalescer"
                description:@"The cursor coalescer rejected the runtime update rate."
                      error:error];
    }
    return coalescer;
}

- (nullable MobaChampionRuntime *)runtimeFromSnapshot:(MobaProfileSnapshot *)snapshot
                                                 error:(NSError **)error {
    if (error != NULL) {
        *error = nil;
    }
    if (snapshot == nil || snapshot.runtimeProfile == nil || snapshot.inputProfile == nil ||
        snapshot.layoutProfile == nil || snapshot.championProfile == nil) {
        [self failWithCode:MobaCastStrategyFactoryErrorInvalidDependency
                championID:snapshot.championProfile.championID ?: @"<unknown>"
                  skillSlot:nil
                  fieldPath:@"$"
                  operation:@"assemble-runtime"
                description:@"A complete typed profile snapshot is required."
                      error:error];
        return nil;
    }

    NSString *championID = snapshot.championProfile.championID;
    if (!snapshot.inputProfile.cancelCastAction.cancelBeforeSkillKeyUp) {
        [self failWithCode:MobaCastStrategyFactoryErrorInvalidCancelOrdering
                championID:championID
                  skillSlot:nil
                  fieldPath:@"$.cancelCastAction.cancelBeforeSkillKeyUp"
                  operation:@"validate-cancel-ordering"
                description:@"The current dispatcher requires cancellation before skill key-up."
                      error:error];
        return nil;
    }

    CGPoint heroAnchor = CGPointMake(snapshot.runtimeProfile.camera.heroAnchor.x,
                                     snapshot.runtimeProfile.camera.heroAnchor.y);
    NSMutableDictionary *descriptors = [NSMutableDictionary dictionary];
    NSMutableArray<id<MobaLocalInteractionResetParticipant>> *participants = [NSMutableArray array];

    for (MobaCanonicalSkillDefinition *definition in MobaCanonicalSkillDefinitions()) {
        NSString *skillSlot = definition.skillSlot;
        NSString *skillPath = [NSString stringWithFormat:@"$.skills.%@", skillSlot];
        MobaChampionSkillProfile *skill = snapshot.championProfile.skills[skillSlot];
        if (skill == nil) {
            [self failWithCode:MobaCastStrategyFactoryErrorMissingCanonicalSkill
                    championID:championID
                      skillSlot:skillSlot
                      fieldPath:skillPath
                      operation:@"resolve-canonical-skill"
                    description:@"The champion is missing a canonical playable skill."
                          error:error];
            return nil;
        }
        MobaLayoutControlProfile *layout = snapshot.layoutProfile.controls[definition.layoutControlName];
        if (layout == nil) {
            [self failWithCode:MobaCastStrategyFactoryErrorMissingLayoutControl
                    championID:championID
                      skillSlot:skillSlot
                      fieldPath:[NSString stringWithFormat:@"$.controls.%@", definition.layoutControlName]
                      operation:@"resolve-layout-control"
                    description:@"The canonical skill has no matching layout control."
                          error:error];
            return nil;
        }
        NSNumber *keyNumber = [snapshot.inputProfile keyCodeForAction:skill.inputAction];
        if (keyNumber == nil) {
            [self failWithCode:MobaCastStrategyFactoryErrorUnresolvedInputAction
                    championID:championID
                      skillSlot:skillSlot
                      fieldPath:[skillPath stringByAppendingString:@".inputAction"]
                      operation:@"resolve-host-key"
                    description:@"The skill input action does not resolve to a host key."
                          error:error];
            return nil;
        }

        uint16_t hostKeyCode = keyNumber.unsignedShortValue;
        id<MobaCastStrategy> strategy = nil;
        MobaCursorCoalescer *coalescer = nil;
        MobaInstantCastConfiguration *instantConfiguration = nil;
        MobaDirectionalCastConfiguration *directionalConfiguration = nil;
        MobaPointCastConfiguration *pointConfiguration = nil;

        if (skill.castType == MobaProfileSkillCastTypeInstant) {
            instantConfiguration = [[MobaInstantCastConfiguration alloc]
                initWithSkillKeyCode:hostKeyCode tapDurationMs:skill.tapDurationMs];
            strategy = [[MobaInstantCastStrategy alloc] initWithDispatcher:_dispatcher
                                                              configuration:instantConfiguration];
        }
        else {
            MobaCastCancelAction *cancelAction = [self cancelActionForProfile:snapshot.inputProfile.cancelCastAction
                                                                  championID:championID
                                                                    skillSlot:skillSlot
                                                                   allowCancel:skill.allowCancel
                                                                         error:error];
            if (cancelAction == nil) {
                return nil;
            }
            coalescer = [self newCoalescerForSnapshot:snapshot
                                          championID:championID
                                            skillSlot:skillSlot
                                                 error:error];
            if (coalescer == nil) {
                return nil;
            }

            MobaDefaultAimProfile *defaultAim = skill.defaultAim;
            if (defaultAim == nil) {
                [self failWithCode:MobaCastStrategyFactoryErrorUnsupportedRuntimeCombination
                        championID:championID
                          skillSlot:skillSlot
                          fieldPath:[skillPath stringByAppendingString:@".defaultAim"]
                          operation:@"map-default-aim"
                        description:@"An aimed skill requires default aim configuration."
                              error:error];
                return nil;
            }
            CGFloat radians = defaultAim.angleDegrees * (CGFloat)M_PI / 180.0;
            CGVector defaultDirection = CGVectorMake(cos(radians), sin(radians));

            if (skill.castType == MobaProfileSkillCastTypeDirectional) {
                MobaDirectionalRangeProfile *range = skill.directionalRange;
                MobaAimRadii radii = MobaAimRadiiMake(range.leftPx, range.rightPx, range.upPx, range.downPx);
                directionalConfiguration = [[MobaDirectionalCastConfiguration alloc]
                    initWithSkillKeyCode:hostKeyCode
                              heroAnchor:heroAnchor
                                   radii:radii
                        defaultDirection:defaultDirection
                    defaultDistanceRatio:defaultAim.distanceRatio
                            cancelAction:cancelAction];
                if (directionalConfiguration != nil) {
                    strategy = [[MobaDirectionalCastStrategy alloc] initWithDispatcher:_dispatcher
                                                                           configuration:directionalConfiguration
                                                                         cursorCoalescer:coalescer];
                }
            }
            else if (skill.castType == MobaProfileSkillCastTypePoint) {
                if (layout.wheelRadiusPt == nil) {
                    [self failWithCode:MobaCastStrategyFactoryErrorMissingAimedWheelRadius
                            championID:championID
                              skillSlot:skillSlot
                              fieldPath:[NSString stringWithFormat:@"$.controls.%@.wheelRadiusPt", definition.layoutControlName]
                              operation:@"resolve-point-wheel-radius"
                            description:@"A point-cast layout control requires wheelRadiusPt."
                                  error:error];
                    return nil;
                }
                MobaPointCastTargetMode targetMode;
                if (skill.targetMode == MobaProfilePointTargetModeGround) {
                    targetMode = MobaPointCastTargetModeGround;
                }
                else if (skill.targetMode == MobaProfilePointTargetModeUnit) {
                    targetMode = MobaPointCastTargetModeUnit;
                }
                else {
                    [self failWithCode:MobaCastStrategyFactoryErrorUnsupportedRuntimeCombination
                            championID:championID
                              skillSlot:skillSlot
                              fieldPath:[skillPath stringByAppendingString:@".targetMode"]
                              operation:@"map-point-target-mode"
                            description:@"The point target mode cannot be assembled."
                                  error:error];
                    return nil;
                }
                MobaPointRangeProfile *range = skill.pointRange;
                MobaTouchResponseProfile *response = skill.touchResponse;
                MobaAimRadii minimumRadii = MobaAimRadiiMake(range.minLeftPx, range.minRightPx,
                                                              range.minUpPx, range.minDownPx);
                MobaAimRadii maximumRadii = MobaAimRadiiMake(range.maxLeftPx, range.maxRightPx,
                                                              range.maxUpPx, range.maxDownPx);
                pointConfiguration = [[MobaPointCastConfiguration alloc]
                    initWithTargetMode:targetMode
                           skillKeyCode:hostKeyCode
                             heroAnchor:heroAnchor
                       defaultDirection:defaultDirection
                   defaultDistanceRatio:defaultAim.distanceRatio
                            wheelRadius:layout.wheelRadiusPt.doubleValue
                          deadzoneRatio:response.deadzoneRatio
                         fullRangeRatio:response.fullRangeRatio.doubleValue
                          curveExponent:response.curveExponent.doubleValue
                           minimumRadii:minimumRadii
                           maximumRadii:maximumRadii
                            cancelAction:cancelAction];
                if (pointConfiguration != nil) {
                    strategy = [[MobaPointCastStrategy alloc] initWithDispatcher:_dispatcher
                                                                      configuration:pointConfiguration
                                                                    cursorCoalescer:coalescer];
                }
            }
            else {
                [self failWithCode:MobaCastStrategyFactoryErrorUnsupportedRuntimeCombination
                        championID:championID
                          skillSlot:skillSlot
                          fieldPath:[skillPath stringByAppendingString:@".castType"]
                          operation:@"map-cast-type"
                        description:@"The skill cast type cannot be assembled."
                              error:error];
                return nil;
            }
        }

        if (strategy == nil) {
            [self failWithCode:MobaCastStrategyFactoryErrorConfigurationRejected
                    championID:championID
                      skillSlot:skillSlot
                      fieldPath:skillPath
                      operation:@"create-strategy-configuration"
                    description:@"The existing strategy configuration rejected typed profile values."
                          error:error];
            return nil;
        }

        MobaSkillRuntimeDescriptor *descriptor = [[MobaSkillRuntimeDescriptor alloc]
            initWithSkillSlot:skillSlot
                 displayLabel:skillSlot
            layoutControlName:definition.layoutControlName
                  inputAction:skill.inputAction
                  hostKeyCode:hostKeyCode
                     castType:skill.castType
                  allowCancel:skill.allowCancel
                 skillProfile:skill
         layoutControlProfile:layout
                     strategy:strategy
              cursorCoalescer:coalescer
         instantConfiguration:instantConfiguration
     directionalConfiguration:directionalConfiguration
           pointConfiguration:pointConfiguration];
        descriptors[skillSlot] = descriptor;
        if (coalescer != nil) {
            [participants addObject:coalescer];
        }
    }

    return [[MobaChampionRuntime alloc] initWithChampionProfile:snapshot.championProfile
                                               skillDescriptors:descriptors
                                 localInteractionResetParticipants:participants];
}

@end
