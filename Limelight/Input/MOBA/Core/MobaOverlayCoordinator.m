//
//  MobaOverlayCoordinator.m
//  Moonlight
//

#import "MobaOverlayCoordinator.h"
#import "MobaCursorDiagnostics.h"
#import "MobaInputDispatcher.h"
#import "MoonlightMobaInputAdapter.h"
#import "MoonlightMobaInputSender.h"
#import "StreamView.h"
#import "../Casting/MobaCastStrategyFactory.h"
#import "../Controls/AttackButtonView.h"
#import "../Controls/MobaChampionSelectorView.h"
#import "../Controls/MobaAttackController.h"
#import "../Controls/MobaCancelZoneController.h"
#import "../Controls/MobaCancelZoneView.h"
#import "../Controls/MobaMovementController.h"
#import "../Controls/MobaModeToolbarView.h"
#import "../Controls/MobaSkillButtonView.h"
#import "../Controls/MobaSkillCastController.h"
#import "../Controls/MobaSkillControlPackage.h"
#import "../Controls/MobaControlLayoutPresentation.h"
#import "../Controls/MobaLayoutEditorOverlayView.h"
#import "../Controls/MoveJoystickView.h"
#import "../Profiles/MobaLayoutEditor.h"
#import "../Profiles/MobaLayoutSaveTransaction.h"
#import "../Profiles/MobaProfileStore.h"
#import "../Profiles/MobaProfileRepository.h"
#import "../Profiles/MobaChampionSelectionController.h"

#if DEBUG
#import "../Debug/MobaCursorDiagnosticPanel.h"
#endif

static const CGFloat MobaDefaultMoveCenterX = 0.14;
static const CGFloat MobaDefaultMoveCenterY = 0.82;
static const CGFloat MobaDefaultAttackCenterX = 0.94;
static const CGFloat MobaDefaultAttackCenterY = 0.90;
static const CGFloat MobaDefaultCancelZoneCenterX = 0.83;
static const CGFloat MobaDefaultCancelZoneCenterY = 0.48;
static const CGFloat MobaDefaultCancelZoneActivationInset = 8.0;

@interface MobaOverlayCoordinator () <MobaAttackControllerDelegate,
                                      MobaBattleInputGate,
                                      MobaChampionSelectionControllerDelegate,
                                      MobaChampionSelectorViewDelegate,
                                      MobaMovementControllerDelegate,
                                      MobaLayoutEditorControllerDelegate,
                                      MobaLayoutEditorOverlayViewDelegate,
                                      MobaLayoutSaveInstalling,
                                      MobaModeToolbarViewDelegate,
                                      MobaSkillCancelZoneRouting,
                                      MobaSkillCastControllerDelegate,
                                      MobaSkillControlPackageBuilding>
@end

@implementation MobaOverlayCoordinator {
    __weak StreamView *_streamView;
    MobaProfileStore *_profileStore;
    MobaProfileRepository *_profileRepository;
    MobaCADisplayLinkDriverProvider *_displayLinkDriverProvider;
    MobaCastStrategyFactory *_castStrategyFactory;
    MobaChampionSelectionController *_championSelectionController;
    MobaChampionSelectorView *_championSelectorView;
    MobaInputDispatcher *_inputDispatcher;
    MobaOverlayLifecycle *_lifecycle;
    MobaCursorDiagnostics *_cursorDiagnostics;
    MobaMovementController *_movementController;
    MoveJoystickView *_moveJoystickView;
    MobaAttackController *_attackController;
    AttackButtonView *_attackButtonView;
    MobaCancelZoneController *_cancelZoneController;
    MobaCancelZoneView *_cancelZoneView;
    MobaModeToolbarView *_modeToolbarView;
    MobaSkillControlPackage *_skillControlPackage;
    NSDictionary<MobaCanonicalSkillSlot, MobaSkillButtonView *> *_skillButtonViews;
    MobaLayoutEditorController *_layoutEditorController;
    MobaLayoutEditorOverlayView *_layoutEditorOverlayView;
    MobaLayoutSaveTransaction *_layoutSaveTransaction;
#if DEBUG
    MobaCursorDiagnosticPanel *_cursorDiagnosticPanel;
#endif
}

- (instancetype)initWithStreamView:(StreamView *)streamView {
    self = [super init];
    if (self) {
        _streamView = streamView;
        _profileStore = [[MobaProfileStore alloc] init];
        NSError *profileStoreError = nil;
        BOOL profileStoreReady = [_profileStore bootstrapDefaultsIfFeatureEnabled:YES error:&profileStoreError];
        if (!profileStoreReady) {
            // Profile storage is optional infrastructure. A failure must not
            // prevent the existing Moonlight stream from being initialized.
            NSLog(@"MOBA profile defaults bootstrap failed: %@", profileStoreError);
        }
        MoonlightMobaInputSender *sender = [[MoonlightMobaInputSender alloc] init];
        MoonlightMobaInputAdapter *adapter = [[MoonlightMobaInputAdapter alloc] initWithSender:sender];
        _inputDispatcher = [[MobaInputDispatcher alloc] initWithSink:adapter];
        _lifecycle = [[MobaOverlayLifecycle alloc] initWithEnvironment:(id<MobaOverlayLifecycleEnvironment>)streamView
                                                       inputDispatcher:_inputDispatcher];
        _profileRepository = [[MobaProfileRepository alloc] initWithStore:_profileStore];
        _displayLinkDriverProvider = [[MobaCADisplayLinkDriverProvider alloc] init];
        _castStrategyFactory = [[MobaCastStrategyFactory alloc] initWithDispatcher:_inputDispatcher
                                                                    driverProvider:_displayLinkDriverProvider];
        _cancelZoneView = [[MobaCancelZoneView alloc]
            initWithVisualDiameter:MobaCancelZoneDefaultVisualDiameter];
        MobaCancelZoneGeometry cancelZoneGeometry =
            MobaCancelZoneGeometryMake(CGPointZero,
                                       MobaCancelZoneDefaultVisualDiameter,
                                       MobaDefaultCancelZoneActivationInset);
        _cancelZoneController = [[MobaCancelZoneController alloc]
            initWithGeometry:cancelZoneGeometry
                 presentation:_cancelZoneView];
        _cancelZoneView.controller = _cancelZoneController;
        [_lifecycle registerLocalInteractionResetParticipant:_cancelZoneView];
        _championSelectionController = [[MobaChampionSelectionController alloc]
            initWithRepository:_profileRepository
                 runtimeBuilder:_castStrategyFactory
            controlPackageBuilder:self
                      lifecycle:(id<MobaChampionSelectionLifecycle>)_lifecycle];
        _championSelectionController.delegate = self;
        _championSelectorView = [[MobaChampionSelectorView alloc]
            initWithCatalogEntries:_championSelectionController.catalogEntries];
        _championSelectorView.delegate = self;
        [_championSelectorView setMode:_lifecycle.mode];
        if (profileStoreReady) {
            NSError *selectionError = nil;
            if (![_championSelectionController selectChampionID:@"caitlyn" error:&selectionError]) {
                // Runtime profiles are optional MOBA infrastructure. Failure
                // must not prevent the normal Moonlight stream from starting.
                NSLog(@"MOBA default champion runtime failed: %@", selectionError);
            }
            _championSelectorView.selectedChampionID = _championSelectionController.selectedChampionID;
        }
        MobaLayoutControlProfile *moveLayout = _profileRepository.activeSnapshot.layoutProfile.controls[@"move"];
        CGFloat initialMoveRadius = moveLayout.wheelRadiusPt != nil
            ? moveLayout.wheelRadiusPt.doubleValue : MoveJoystickDefaultWheelRadius;
        _movementController = [[MobaMovementController alloc]
            initWithInputDispatcher:_inputDispatcher
                         keyMapping:MobaDefaultMovementKeyMapping()
                        wheelRadius:initialMoveRadius
                      deadZoneRatio:MobaJoystickDefaultDeadZoneRatio
         directionHysteresisDegrees:MobaJoystickDefaultDirectionHysteresisDegrees];
        _movementController.delegate = self;
        CGSize moveVisualSize = moveLayout != nil
            ? CGSizeMake(moveLayout.visualWidthPt, moveLayout.visualHeightPt) : MoveJoystickDefaultVisualSize;
        CGFloat moveHitScale = moveLayout != nil ? moveLayout.hitAreaScale : MoveJoystickDefaultHitAreaScale;
        _moveJoystickView = [[MoveJoystickView alloc] initWithMovementController:_movementController
                                                                      visualSize:moveVisualSize
                                                                     wheelRadius:initialMoveRadius
                                                                    hitAreaScale:moveHitScale];
        [_lifecycle registerLocalInteractionResetParticipant:_moveJoystickView];
        _attackController = [[MobaAttackController alloc] initWithInputDispatcher:_inputDispatcher];
        _attackController.delegate = self;
        MobaLayoutControlProfile *attackLayout = _profileRepository.activeSnapshot.layoutProfile.controls[@"attack"];
        CGSize attackVisualSize = attackLayout != nil
            ? CGSizeMake(attackLayout.visualWidthPt, attackLayout.visualHeightPt) : AttackButtonDefaultVisualSize;
        CGFloat attackHitScale = attackLayout != nil ? attackLayout.hitAreaScale : AttackButtonDefaultHitAreaScale;
        _attackButtonView = [[AttackButtonView alloc] initWithAttackController:_attackController
                                                                    visualSize:attackVisualSize
                                                                   hitAreaScale:attackHitScale];
        [_lifecycle registerLocalInteractionResetParticipant:_attackButtonView];
        _modeToolbarView = [[MobaModeToolbarView alloc] initWithFrame:CGRectZero];
        _modeToolbarView.delegate = self;
        _modeToolbarView.battleModeAvailable = streamView.isMobaBattleModeSupported;
        [_modeToolbarView setSelectedMode:_lifecycle.mode];
        _cursorDiagnostics = [[MobaCursorDiagnostics alloc] initWithDispatcher:_inputDispatcher
                                                                     inputGate:self];
        _layoutSaveTransaction = [[MobaLayoutSaveTransaction alloc]
            initWithStore:_profileStore
            repository:_profileRepository
            runtimeBuilder:_castStrategyFactory
            controlPackageBuilder:self
            lifecycle:(id<MobaLayoutSaveLifecycle>)_lifecycle
            installer:self];
        [self applyCommittedLayoutPresentation];
#if DEBUG
        _cursorDiagnosticPanel = [[MobaCursorDiagnosticPanel alloc] initWithDiagnostics:_cursorDiagnostics];
        [_lifecycle registerLocalInteractionResetParticipant:_cursorDiagnosticPanel];
#endif
    }
    return self;
}

- (nullable MobaSkillControlPackage *)controlPackageForRuntime:(MobaChampionRuntime *)runtime
                                                         error:(NSError **)error {
    if (error != NULL) {
        *error = nil;
    }
    NSMutableDictionary<MobaCanonicalSkillSlot, MobaSkillCastController *> *controllers =
        [[NSMutableDictionary alloc] initWithCapacity:MobaCanonicalSkillSlots().count];
    NSMutableDictionary<MobaCanonicalSkillSlot, MobaSkillButtonView *> *views =
        [[NSMutableDictionary alloc] initWithCapacity:MobaCanonicalSkillSlots().count];
    for (MobaCanonicalSkillSlot slot in MobaCanonicalSkillSlots()) {
        MobaSkillRuntimeDescriptor *descriptor = [runtime descriptorForSkillSlot:slot];
        if (descriptor == nil) {
            if (error != NULL) {
                *error = [NSError errorWithDomain:MobaChampionSelectionErrorDomain
                                             code:MobaChampionSelectionErrorControlPackageBuildFailed
                                         userInfo:@{
                    NSLocalizedDescriptionKey: @"The candidate runtime is missing a canonical skill descriptor.",
                    MobaChampionSelectionChampionIDKey: runtime.championID,
                    MobaChampionSelectionOperationKey: @"build-candidate-skill-controls",
                    MobaCastStrategyFactorySkillSlotKey: slot,
                }];
            }
            break;
        }

        MobaSkillCastController *controller = [[MobaSkillCastController alloc]
            initWithDescriptor:descriptor
                     inputGate:self
              cancelZoneRouter:self];
        if (controller == nil) {
            break;
        }
        controller.delegate = self;
        controllers[slot] = controller;
        MobaSkillButtonView *view = [[MobaSkillButtonView alloc]
            initWithController:controller
            streamCoordinateView:_streamView];
        if (view == nil) {
            break;
        }
        [view setMode:_lifecycle.mode];
        views[slot] = view;
    }
    MobaSkillControlPackage *package = [[MobaSkillControlPackage alloc]
        initWithControllers:controllers skillButtonViews:views];
    if (!package.isComplete && error != NULL && *error == nil) {
        *error = [NSError errorWithDomain:MobaChampionSelectionErrorDomain
                                     code:MobaChampionSelectionErrorControlPackageBuildFailed
                                 userInfo:@{
            NSLocalizedDescriptionKey: @"The candidate skill-control package could not be completed.",
            MobaChampionSelectionChampionIDKey: runtime.championID,
            MobaChampionSelectionOperationKey: @"build-candidate-skill-controls",
        }];
    }
    return package;
}

- (void)installSkillControlPackage:(MobaSkillControlPackage *)package {
    MobaSkillControlPackage *previous = _skillControlPackage;
    for (id<MobaLocalInteractionResetParticipant> participant in previous.localInteractionResetParticipants) {
        MobaSkillButtonView *view = (MobaSkillButtonView *)participant;
        [_lifecycle unregisterLocalInteractionResetParticipant:view];
        [view removeFromSuperview];
    }

    _skillControlPackage = package;
    _skillButtonViews = package.skillButtonViews;
    for (id<MobaLocalInteractionResetParticipant> participant in package.localInteractionResetParticipants) {
        MobaSkillButtonView *view = (MobaSkillButtonView *)participant;
        [_lifecycle registerLocalInteractionResetParticipant:view];
        if (_lifecycle.isRunning) {
            [_streamView addSubview:view];
        }
    }
    if (_lifecycle.isRunning) {
        [self layoutBattleControls];
    }
}

- (MobaControlLayoutPresentation *)presentationForProfile:(MobaLayoutControlProfile *)profile
                                                  fallback:(MobaControlLayoutPresentation *)fallback {
    if (profile == nil) return fallback;
    MobaControlLayoutPresentation *presentation = [[MobaControlLayoutPresentation alloc]
        initWithCenterX:profile.centerX
        centerY:profile.centerY
        visualSize:CGSizeMake(profile.visualWidthPt, profile.visualHeightPt)
        hitAreaScale:profile.hitAreaScale
        wheelRadiusPt:profile.wheelRadiusPt
        normalOpacity:profile.opacity
        pressedOpacity:profile.pressedOpacity
        disabledOpacity:profile.disabledOpacity
        zIndex:profile.zIndex
        interactionEnabled:profile.isInteractionEnabled];
    return presentation ?: fallback;
}

- (MobaControlLayoutPresentation *)fallbackMovePresentation {
    return [[MobaControlLayoutPresentation alloc]
        initWithCenterX:MobaDefaultMoveCenterX centerY:MobaDefaultMoveCenterY
        visualSize:MoveJoystickDefaultVisualSize hitAreaScale:MoveJoystickDefaultHitAreaScale
        wheelRadiusPt:@(MoveJoystickDefaultWheelRadius)
        normalOpacity:MoveJoystickDefaultNormalOpacity
        pressedOpacity:MoveJoystickDefaultPressedOpacity
        disabledOpacity:MoveJoystickDefaultDisabledOpacity zIndex:10 interactionEnabled:YES];
}

- (MobaControlLayoutPresentation *)fallbackAttackPresentation {
    return [[MobaControlLayoutPresentation alloc]
        initWithCenterX:MobaDefaultAttackCenterX centerY:MobaDefaultAttackCenterY
        visualSize:AttackButtonDefaultVisualSize hitAreaScale:AttackButtonDefaultHitAreaScale
        wheelRadiusPt:nil normalOpacity:AttackButtonDefaultNormalOpacity
        pressedOpacity:AttackButtonDefaultPressedOpacity
        disabledOpacity:AttackButtonDefaultDisabledOpacity zIndex:24 interactionEnabled:YES];
}

- (MobaCancelZoneLayoutPresentation *)fallbackCancelPresentation {
    return [[MobaCancelZoneLayoutPresentation alloc]
        initWithCenterX:MobaDefaultCancelZoneCenterX centerY:MobaDefaultCancelZoneCenterY
        diameterPt:MobaCancelZoneDefaultVisualDiameter
        activationInsetPt:MobaDefaultCancelZoneActivationInset
        opacity:MobaCancelZoneDefaultNormalOpacity
        visibleOnlyWhileCasting:YES];
}

- (MobaControlLayoutPresentation *)currentPresentationForControlName:(NSString *)name {
    if (_layoutEditorController != nil && _lifecycle.mode == MobaOverlayModeLayoutEdit) {
        return [_layoutEditorController.draft controlNamed:name].presentation;
    }
    MobaLayoutControlProfile *profile = _profileRepository.activeSnapshot.layoutProfile.controls[name];
    if ([name isEqualToString:@"move"]) {
        return [self presentationForProfile:profile fallback:self.fallbackMovePresentation];
    }
    if ([name isEqualToString:@"attack"]) {
        return [self presentationForProfile:profile fallback:self.fallbackAttackPresentation];
    }
    return [self presentationForProfile:profile fallback:nil];
}

- (MobaCancelZoneLayoutPresentation *)currentCancelPresentation {
    if (_layoutEditorController != nil && _lifecycle.mode == MobaOverlayModeLayoutEdit) {
        return _layoutEditorController.draft.cancelZone.presentation;
    }
    MobaCancelZoneProfile *profile = _profileRepository.activeSnapshot.layoutProfile.cancelZone;
    if (profile == nil) return self.fallbackCancelPresentation;
    return [[MobaCancelZoneLayoutPresentation alloc]
        initWithCenterX:profile.centerX centerY:profile.centerY
        diameterPt:profile.diameterPt activationInsetPt:profile.activationInsetPt
        opacity:profile.opacity visibleOnlyWhileCasting:profile.visibleOnlyWhileCasting];
}

- (CGFloat)currentGlobalOpacityMultiplier {
    if (_layoutEditorController != nil && _lifecycle.mode == MobaOverlayModeLayoutEdit) {
        return _layoutEditorController.draft.globalOpacityMultiplier;
    }
    MobaRuntimeProfile *runtime = _profileRepository.activeSnapshot.runtimeProfile;
    return runtime != nil ? runtime.globalOpacityMultiplier : 1.0;
}

- (void)applyCurrentLayoutPresentation {
    CGFloat globalOpacity = self.currentGlobalOpacityMultiplier;
    MobaControlOpacityPreviewState previewState = _lifecycle.mode == MobaOverlayModeLayoutEdit
        ? _layoutEditorController.opacityPreviewState : MobaControlOpacityPreviewStateAutomatic;
    MobaControlLayoutPresentation *move = [self currentPresentationForControlName:@"move"];
    MobaControlLayoutPresentation *attack = [self currentPresentationForControlName:@"attack"];
    [_moveJoystickView applyControlLayoutPresentation:move
                              globalOpacityMultiplier:globalOpacity
                                         previewState:previewState];
    [_attackButtonView applyControlLayoutPresentation:attack
                              globalOpacityMultiplier:globalOpacity
                                         previewState:previewState];
    for (MobaCanonicalSkillSlot slot in _skillButtonViews) {
        MobaSkillButtonView *view = _skillButtonViews[slot];
        MobaControlLayoutPresentation *skill = [self currentPresentationForControlName:view.descriptor.layoutControlName];
        if (skill != nil) {
            [view applyControlLayoutPresentation:skill
                         globalOpacityMultiplier:globalOpacity
                                    previewState:previewState];
        }
    }
    [_cancelZoneView applyCancelZoneLayoutPresentation:self.currentCancelPresentation
                               globalOpacityMultiplier:globalOpacity
                                         editorPreview:_lifecycle.mode == MobaOverlayModeLayoutEdit
                                          previewState:previewState];
}

- (void)applyCommittedLayoutPresentation {
    MobaControlLayoutPresentation *move = [self presentationForProfile:
        _profileRepository.activeSnapshot.layoutProfile.controls[@"move"] fallback:self.fallbackMovePresentation];
    [_movementController updateWheelRadiusForCommittedProfile:move.wheelRadiusPt.doubleValue];
    [self applyCurrentLayoutPresentation];
    [self layoutBattleControls];
}

- (void)layoutBattleControls {
    [_streamView layoutIfNeeded];
    CGRect safeFrame = _streamView.safeAreaLayoutGuide.layoutFrame;
    CGSize moveHitAreaSize = _moveJoystickView.intrinsicContentSize;
    _moveJoystickView.bounds = (CGRect){ CGPointZero, moveHitAreaSize };
    MobaControlLayoutPresentation *moveLayout = [self currentPresentationForControlName:@"move"];
    _moveJoystickView.center = CGPointMake(CGRectGetMinX(safeFrame) +
                                           CGRectGetWidth(safeFrame) * moveLayout.centerX,
                                           CGRectGetMinY(safeFrame) +
                                           CGRectGetHeight(safeFrame) * moveLayout.centerY);

    CGSize attackHitAreaSize = _attackButtonView.intrinsicContentSize;
    _attackButtonView.bounds = (CGRect){ CGPointZero, attackHitAreaSize };
    MobaControlLayoutPresentation *attackLayout = [self currentPresentationForControlName:@"attack"];
    _attackButtonView.center = CGPointMake(CGRectGetMinX(safeFrame) +
                                           CGRectGetWidth(safeFrame) * attackLayout.centerX,
                                           CGRectGetMinY(safeFrame) +
                                           CGRectGetHeight(safeFrame) * attackLayout.centerY);

    for (MobaSkillButtonView *skillView in _skillButtonViews.allValues) {
        MobaControlLayoutPresentation *layout = [self currentPresentationForControlName:
            skillView.descriptor.layoutControlName];
        CGSize hitAreaSize = skillView.intrinsicContentSize;
        skillView.bounds = (CGRect){ CGPointZero, hitAreaSize };
        skillView.center = CGPointMake(CGRectGetMinX(safeFrame) +
                                       CGRectGetWidth(safeFrame) * layout.centerX,
                                       CGRectGetMinY(safeFrame) +
                                       CGRectGetHeight(safeFrame) * layout.centerY);
        skillView.layer.zPosition = layout.zIndex;
    }

    CGSize cancelZoneSize = _cancelZoneView.intrinsicContentSize;
    _cancelZoneView.bounds = (CGRect){ CGPointZero, cancelZoneSize };
    MobaCancelZoneLayoutPresentation *cancelLayout = self.currentCancelPresentation;
    CGPoint cancelZoneCenter = CGPointMake(CGRectGetMinX(safeFrame) +
                                           CGRectGetWidth(safeFrame) * cancelLayout.centerX,
                                           CGRectGetMinY(safeFrame) +
                                           CGRectGetHeight(safeFrame) * cancelLayout.centerY);
    _cancelZoneView.center = cancelZoneCenter;
    [_cancelZoneController updateGeometry:MobaCancelZoneGeometryMake(cancelZoneCenter,
                                                                     cancelLayout.diameterPt,
                                                                     cancelLayout.activationInsetPt)];

    CGSize toolbarSize = _modeToolbarView.intrinsicContentSize;
    _modeToolbarView.bounds = (CGRect){ CGPointZero, toolbarSize };
    _modeToolbarView.center = CGPointMake(CGRectGetMaxX(safeFrame) - toolbarSize.width * 0.5 - 12.0,
                                          CGRectGetMinY(safeFrame) + toolbarSize.height * 0.5 + 8.0);

    CGSize selectorSize = _championSelectorView.intrinsicContentSize;
    _championSelectorView.bounds = (CGRect){ CGPointZero, selectorSize };
    _championSelectorView.center = CGPointMake(CGRectGetMinX(safeFrame) + selectorSize.width * 0.5 + 12.0,
                                               CGRectGetMinY(safeFrame) + selectorSize.height * 0.5 + 8.0);
}

- (void)removeBattleControls {
    [_moveJoystickView removeFromSuperview];
    [_attackButtonView removeFromSuperview];
    for (MobaSkillButtonView *view in _skillButtonViews.allValues) {
        [view removeFromSuperview];
    }
    [_cancelZoneView removeFromSuperview];
    [_modeToolbarView removeFromSuperview];
    [_championSelectorView removeFromSuperview];
}

- (BOOL)isRunning {
    return _lifecycle.isRunning;
}

- (MobaOverlayMode)mode {
    return _lifecycle.mode;
}

- (void)setMode:(MobaOverlayMode)mode {
    [self transitionToMode:mode];
}

- (BOOL)isBattleModeAvailable {
    return [_streamView isMobaBattleModeSupported];
}

- (BOOL)isBattleInputAllowed {
    return _lifecycle.isBattleInputAllowed;
}

- (BOOL)isInputSuspended {
    return _lifecycle.isInputSuspended;
}

- (MobaChampionRuntime *)activeChampionRuntime {
    return _championSelectionController.activeChampionRuntime;
}

- (MobaChampionSelectionController *)championSelectionController {
    return _championSelectionController;
}

- (NSDictionary<NSString *, MobaSkillButtonView *> *)skillButtonViews {
    return [_skillButtonViews copy] ?: @{};
}

- (void)registerLocalInteractionResetParticipant:(id<MobaLocalInteractionResetParticipant>)participant {
    [_lifecycle registerLocalInteractionResetParticipant:participant];
}

- (void)unregisterLocalInteractionResetParticipant:(id<MobaLocalInteractionResetParticipant>)participant {
    [_lifecycle unregisterLocalInteractionResetParticipant:participant];
}

- (BOOL)transitionToMode:(MobaOverlayMode)mode {
    MobaOverlayMode previousMode = _lifecycle.mode;
    BOOL transitioned = [_lifecycle transitionToMode:mode];
    if (!transitioned) return NO;
    if (previousMode == MobaOverlayModeLayoutEdit && mode != MobaOverlayModeLayoutEdit) {
        [self discardLayoutEditorDraft];
    }
    else if (mode == MobaOverlayModeLayoutEdit && previousMode != MobaOverlayModeLayoutEdit) {
        [self beginLayoutEditing];
    }
    _modeToolbarView.battleModeAvailable = self.isBattleModeAvailable;
    [_modeToolbarView setSelectedMode:_lifecycle.mode];
    [_championSelectorView setMode:_lifecycle.mode];
    for (MobaSkillButtonView *view in _skillButtonViews.allValues) {
        [view setMode:_lifecycle.mode];
    }
    _championSelectorView.selectedChampionID = _championSelectionController.selectedChampionID;
    [self applyCurrentLayoutPresentation];
    [self layoutBattleControls];
    return YES;
}

- (void)attachLayoutEditorOverlay {
    if (_layoutEditorController == nil || !_lifecycle.isRunning ||
        _lifecycle.mode != MobaOverlayModeLayoutEdit || _layoutEditorOverlayView.superview != nil) {
        return;
    }
    _layoutEditorOverlayView = [[MobaLayoutEditorOverlayView alloc]
        initWithEditorController:_layoutEditorController];
    _layoutEditorOverlayView.delegate = self;
    _layoutEditorOverlayView.frame = _streamView.bounds;
    _layoutEditorOverlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [_streamView addSubview:_layoutEditorOverlayView];
    [_streamView bringSubviewToFront:_modeToolbarView];
}

- (BOOL)beginLayoutEditing {
    if (_layoutEditorController == nil) {
        NSError *error = nil;
        NSData *runtimeData = [_profileStore readDataAtRelativePath:MobaRuntimeProfileRelativePath error:&error];
        NSData *layoutData = [_profileStore readDataAtRelativePath:MobaActiveLayoutProfileRelativePath error:&error];
        MobaProfileSnapshot *snapshot = _profileRepository.activeSnapshot;
        if (runtimeData == nil || layoutData == nil || snapshot == nil) {
            NSLog(@"MOBA layout editor could not load its committed baseline: %@", error);
            return NO;
        }
        _layoutEditorController = [[MobaLayoutEditorController alloc]
            initWithSnapshot:snapshot
            runtimeData:runtimeData
            layoutData:layoutData
            decoder:[[MobaProfileDecoder alloc] init]
            error:&error];
        if (_layoutEditorController == nil) {
            NSLog(@"MOBA layout editor baseline was rejected: %@", error);
            return NO;
        }
        _layoutEditorController.delegate = self;
    }
    [self attachLayoutEditorOverlay];
    [self applyCurrentLayoutPresentation];
    [self layoutBattleControls];
    return YES;
}

- (void)discardLayoutEditorDraft {
    [_layoutEditorOverlayView cancelEditingInteraction];
    [_layoutEditorOverlayView removeFromSuperview];
    _layoutEditorOverlayView = nil;
    if (_layoutEditorController.isDirty) [_layoutEditorController revert];
    _layoutEditorController.delegate = nil;
    _layoutEditorController = nil;
    [self applyCommittedLayoutPresentation];
}

- (void)start {
    if (_lifecycle.isRunning) {
        return;
    }

    if (_moveJoystickView.superview == nil) {
        [_streamView addSubview:_moveJoystickView];
    }
    if (_attackButtonView.superview == nil) {
        [_streamView addSubview:_attackButtonView];
    }
    for (MobaSkillButtonView *view in _skillButtonViews.allValues) {
        if (view.superview == nil) {
            [_streamView addSubview:view];
        }
        [view setMode:_lifecycle.mode];
    }
    if (_cancelZoneView.superview == nil) {
        [_streamView addSubview:_cancelZoneView];
    }
    if (_modeToolbarView.superview == nil) {
        [_streamView addSubview:_modeToolbarView];
    }
    if (_championSelectorView.superview == nil) {
        [_streamView addSubview:_championSelectorView];
    }
    _modeToolbarView.battleModeAvailable = self.isBattleModeAvailable;
    [_modeToolbarView setSelectedMode:_lifecycle.mode];
    [_championSelectorView setMode:_lifecycle.mode];
    _championSelectorView.selectedChampionID = _championSelectionController.selectedChampionID;
    [self layoutBattleControls];

#if DEBUG
    if (_cursorDiagnosticPanel.superview == nil) {
        [_streamView addSubview:_cursorDiagnosticPanel];
        UILayoutGuide *safeArea = _streamView.safeAreaLayoutGuide;
        [NSLayoutConstraint activateConstraints:@[
            [_cursorDiagnosticPanel.topAnchor constraintEqualToAnchor:safeArea.topAnchor constant:8.0],
            [_cursorDiagnosticPanel.centerXAnchor constraintEqualToAnchor:safeArea.centerXAnchor],
        ]];
    }
#endif
    [_lifecycle start];
    if (_lifecycle.mode == MobaOverlayModeLayoutEdit) [self beginLayoutEditing];
}

- (BOOL)beginCancelZonePresentationForCastToken:(id)token {
    if (!self.isBattleInputAllowed) {
        return NO;
    }
    return [_cancelZoneController beginCastingWithToken:token];
}

- (BOOL)evaluateCancelZoneAtStreamViewPoint:(CGPoint)point
                                forCastToken:(id)token
                           insideCancelZone:(BOOL *)insideCancelZone {
    if (!self.isBattleInputAllowed) {
        return NO;
    }
    return [_cancelZoneController evaluatePoint:point
                                       forToken:token
                               insideCancelZone:insideCancelZone];
}

- (BOOL)applyCancelZoneTransitionResult:(MobaCastTransitionResult)result
                            forCastToken:(id)token {
    if (!self.isBattleInputAllowed) {
        return NO;
    }
    return [_cancelZoneController applyAcceptedTransitionResult:result forToken:token];
}

- (BOOL)endCancelZonePresentationForCastToken:(id)token {
    return [_cancelZoneController endCastingWithToken:token];
}

- (void)resetCancelZonePresentation {
    [_cancelZoneController silentReset];
}

- (void)stop {
    [self discardLayoutEditorDraft];
    [_lifecycle stop];
    [self removeBattleControls];
#if DEBUG
    [_cursorDiagnosticPanel removeFromSuperview];
#endif
}

- (BOOL)interruptAndReleaseInputsForReason:(MobaInputInterruptionReason)reason {
    return [_lifecycle interruptAndReleaseInputsForReason:reason];
}

- (void)touchesCancelled {
    [_lifecycle touchesCancelled];
}

- (void)applicationWillResignActive {
    [_layoutEditorOverlayView cancelEditingInteraction];
    [_lifecycle applicationWillResignActive];
}

- (void)applicationDidEnterBackground {
    [_layoutEditorOverlayView cancelEditingInteraction];
    [_layoutEditorOverlayView removeFromSuperview];
    _layoutEditorOverlayView = nil;
    [_lifecycle applicationDidEnterBackground];
}

- (void)applicationDidBecomeActive {
    [_lifecycle applicationDidBecomeActive];
    [self attachLayoutEditorOverlay];
}

- (void)streamDidDisconnect {
    [self discardLayoutEditorDraft];
    [_lifecycle streamDidDisconnect];
    [self removeBattleControls];
#if DEBUG
    [_cursorDiagnosticPanel removeFromSuperview];
#endif
}

- (void)viewControllerWillDisappear {
    [self discardLayoutEditorDraft];
    [_lifecycle viewControllerWillDisappear];
    [self removeBattleControls];
#if DEBUG
    [_cursorDiagnosticPanel removeFromSuperview];
#endif
}

- (void)orientationWillChange {
    [_layoutEditorOverlayView cancelEditingInteraction];
    [_lifecycle orientationWillChange];
}

- (void)orientationDidChange {
    _modeToolbarView.battleModeAvailable = self.isBattleModeAvailable;
    [self layoutBattleControls];
    [_layoutEditorOverlayView refreshFromDraft];
    [_lifecycle orientationDidChange];
}

- (void)profileWillReload {
    [_lifecycle profileWillReload];
}

- (void)profileDidReload {
    [_lifecycle profileDidReload];
}

- (void)mobaFeatureWillDisable {
    [self discardLayoutEditorDraft];
    [_lifecycle mobaFeatureWillDisable];
    [self removeBattleControls];
#if DEBUG
    [_cursorDiagnosticPanel removeFromSuperview];
#endif
}

- (void)movementControllerDidRequestTouchCancellation:(MobaMovementController *)controller {
    (void)controller;
    [_lifecycle touchesCancelled];
}

- (void)attackControllerDidRequestTouchCancellation:(MobaAttackController *)controller {
    (void)controller;
    [_lifecycle touchesCancelled];
}

- (void)skillCastControllerDidRequestTouchCancellation:(MobaSkillCastController *)controller {
    (void)controller;
    [_lifecycle touchesCancelled];
}

- (void)layoutEditorControllerDidChangeDraft:(MobaLayoutEditorController *)controller {
    (void)controller;
    if (_lifecycle.mode != MobaOverlayModeLayoutEdit) return;
    [self applyCurrentLayoutPresentation];
    [self layoutBattleControls];
    [_layoutEditorOverlayView refreshFromDraft];
}

- (void)layoutEditorOverlayDidRequestSave:(MobaLayoutEditorOverlayView *)overlay {
    if (overlay != _layoutEditorOverlayView || _lifecycle.mode != MobaOverlayModeLayoutEdit) return;
    NSError *error = nil;
    MobaLayoutSaveResult *result = [_layoutSaveTransaction saveDraft:_layoutEditorController.draft error:&error];
    if (result == nil) {
        [overlay showStatusMessage:error.localizedDescription ?: @"Save failed" error:YES];
        return;
    }
    if (![_layoutEditorController acceptSavedSnapshot:result.snapshot
                                           runtimeData:result.runtimeData
                                            layoutData:result.layoutData
                                                 error:&error]) {
        [overlay showStatusMessage:error.localizedDescription ?: @"Saved, but baseline refresh failed" error:YES];
        return;
    }
    [self applyCurrentLayoutPresentation];
    [self layoutBattleControls];
    [overlay showStatusMessage:@"Saved" error:NO];
}

- (void)layoutEditorOverlayDidRequestRestoreDefaults:(MobaLayoutEditorOverlayView *)overlay {
    if (overlay != _layoutEditorOverlayView || _lifecycle.mode != MobaOverlayModeLayoutEdit) return;
    NSError *error = nil;
    NSData *runtimeData = [_profileStore
        readBundledDefaultDataForDestinationRelativePath:MobaRuntimeProfileRelativePath error:&error];
    NSData *layoutData = [_profileStore
        readBundledDefaultDataForDestinationRelativePath:MobaActiveLayoutProfileRelativePath error:&error];
    if (runtimeData == nil || layoutData == nil ||
        ![_layoutEditorController restoreDefaultsFromRuntimeData:runtimeData layoutData:layoutData error:&error]) {
        [overlay showStatusMessage:error.localizedDescription ?: @"Defaults unavailable" error:YES];
        return;
    }
    [overlay showStatusMessage:@"Defaults previewed. Save to commit." error:NO];
}

- (BOOL)installLayoutSaveSnapshot:(MobaProfileSnapshot *)snapshot
                           runtime:(MobaChampionRuntime *)runtime
               skillControlPackage:(MobaSkillControlPackage *)skillControlPackage
                             error:(NSError **)error {
    if (![_championSelectionController commitPreparedProfileSnapshot:snapshot
                                                              runtime:runtime
                                                   skillControlPackage:skillControlPackage
                                                                error:error]) {
        return NO;
    }
    [self applyCommittedLayoutPresentation];
    return YES;
}

- (BOOL)mobaModeToolbarView:(MobaModeToolbarView *)toolbar requestMode:(MobaOverlayMode)mode {
    (void)toolbar;
    return [self transitionToMode:mode];
}

- (BOOL)mobaChampionSelectorView:(MobaChampionSelectorView *)selectorView
               requestChampionID:(NSString *)championID
                            error:(NSError **)error {
    (void)selectorView;
    BOOL selected = [_championSelectionController selectChampionID:championID error:error];
    _championSelectorView.selectedChampionID = _championSelectionController.selectedChampionID;
    return selected;
}

- (void)championSelectionController:(MobaChampionSelectionController *)controller
                    didSelectRuntime:(MobaChampionRuntime *)runtime
                 skillControlPackage:(nullable MobaSkillControlPackage *)skillControlPackage {
    (void)controller;
    (void)runtime;
    if (!skillControlPackage.isComplete) {
        [NSException raise:NSInternalInconsistencyException
                    format:@"Champion selection must provide a complete skill-control package"];
    }
    [self installSkillControlPackage:skillControlPackage];
    [self applyCommittedLayoutPresentation];
}

- (void)dealloc {
    [_layoutEditorOverlayView cancelEditingInteraction];
    [_lifecycle invalidateForDestruction];
    [_championSelectionController invalidate];
    [self removeBattleControls];
#if DEBUG
    [_cursorDiagnosticPanel removeFromSuperview];
#endif
}

@end
