//
//  MobaSkillControlPackage.m
//  Moonlight
//

#import "MobaSkillControlPackage.h"

#import "MobaSkillButtonView.h"
#import "MobaSkillCastController.h"

@implementation MobaSkillControlPackage

- (instancetype)initWithControllers:(NSDictionary<MobaCanonicalSkillSlot, MobaSkillCastController *> *)controllers
                    skillButtonViews:(NSDictionary<MobaCanonicalSkillSlot, MobaSkillButtonView *> *)skillButtonViews {
    self = [super init];
    if (self) {
        _controllers = [controllers copy] ?: @{};
        _skillButtonViews = [skillButtonViews copy] ?: @{};

        NSMutableArray<id<MobaLocalInteractionResetParticipant>> *participants = [NSMutableArray array];
        for (MobaCanonicalSkillSlot slot in MobaCanonicalSkillSlots()) {
            MobaSkillButtonView *view = _skillButtonViews[slot];
            if (view != nil) {
                [participants addObject:view];
            }
        }
        _localInteractionResetParticipants = [participants copy];
    }
    return self;
}

- (BOOL)isComplete {
    if (_controllers.count != MobaCanonicalSkillSlots().count ||
        _skillButtonViews.count != MobaCanonicalSkillSlots().count) {
        return NO;
    }
    for (MobaCanonicalSkillSlot slot in MobaCanonicalSkillSlots()) {
        if (_controllers[slot] == nil || _skillButtonViews[slot] == nil) {
            return NO;
        }
    }
    return YES;
}

- (void)silentResetForReason:(MobaInputInterruptionReason)reason {
    for (MobaCanonicalSkillSlot slot in MobaCanonicalSkillSlots()) {
        MobaSkillButtonView *view = _skillButtonViews[slot];
        if (view != nil) {
            [view setMobaLocalInteractionEnabled:NO];
            [view resetMobaLocalInteractionForReason:reason];
        }
        else {
            [_controllers[slot] silentReset];
        }
    }
}

@end
