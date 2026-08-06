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
#import "../Controls/MoveJoystickView.h"
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
                                      MobaModeToolbarViewDelegate,
                                      MobaSkillCancelZoneRouting,
                                      MobaSkillCastControllerDelegate>
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
    NSDictionary<MobaCanonicalSkillSlot, MobaSkillButtonView *> *_skillButtonViews;
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
        _championSelectionController = [[MobaChampionSelectionController alloc]
            initWithRepository:_profileRepository
                 runtimeBuilder:_castStrategyFactory
                      lifecycle:(id<MobaChampionSelectionLifecycle>)_lifecycle];
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
        _movementController = [[MobaMovementController alloc]
            initWithInputDispatcher:_inputDispatcher
                         keyMapping:MobaDefaultMovementKeyMapping()
                        wheelRadius:MoveJoystickDefaultWheelRadius
                      deadZoneRatio:MobaJoystickDefaultDeadZoneRatio
         directionHysteresisDegrees:MobaJoystickDefaultDirectionHysteresisDegrees];
        _movementController.delegate = self;
        _moveJoystickView = [[MoveJoystickView alloc] initWithMovementController:_movementController];
        [_lifecycle registerLocalInteractionResetParticipant:_moveJoystickView];
        _attackController = [[MobaAttackController alloc] initWithInputDispatcher:_inputDispatcher];
        _attackController.delegate = self;
        _attackButtonView = [[AttackButtonView alloc] initWithAttackController:_attackController];
        [_lifecycle registerLocalInteractionResetParticipant:_attackButtonView];
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
        if (_championSelectionController.activeChampionRuntime != nil &&
            ![self installSkillControlsForRuntime:_championSelectionController.activeChampionRuntime]) {
            NSLog(@"MOBA initial skill controls could not be created");
        }
        _championSelectionController.delegate = self;
        _modeToolbarView = [[MobaModeToolbarView alloc] initWithFrame:CGRectZero];
        _modeToolbarView.delegate = self;
        _modeToolbarView.battleModeAvailable = streamView.isMobaBattleModeSupported;
        [_modeToolbarView setSelectedMode:_lifecycle.mode];
        _cursorDiagnostics = [[MobaCursorDiagnostics alloc] initWithDispatcher:_inputDispatcher
                                                                     inputGate:self];
#if DEBUG
        _cursorDiagnosticPanel = [[MobaCursorDiagnosticPanel alloc] initWithDiagnostics:_cursorDiagnostics];
        [_lifecycle registerLocalInteractionResetParticipant:_cursorDiagnosticPanel];
#endif
    }
    return self;
}

- (nullable NSDictionary<MobaCanonicalSkillSlot, MobaSkillButtonView *> *)skillControlsForRuntime:(MobaChampionRuntime *)runtime {
    NSMutableDictionary<MobaCanonicalSkillSlot, MobaSkillButtonView *> *candidate =
        [[NSMutableDictionary alloc] initWithCapacity:MobaCanonicalSkillSlots().count];
    for (MobaCanonicalSkillSlot slot in MobaCanonicalSkillSlots()) {
        MobaSkillRuntimeDescriptor *descriptor = [runtime descriptorForSkillSlot:slot];
        if (descriptor == nil) {
            return nil;
        }

        MobaSkillCastController *controller = [[MobaSkillCastController alloc]
            initWithDescriptor:descriptor
                     inputGate:self
              cancelZoneRouter:self];
        controller.delegate = self;
        MobaSkillButtonView *view = [[MobaSkillButtonView alloc]
            initWithController:controller
            streamCoordinateView:_streamView];
        if (view == nil) {
            return nil;
        }
        [view setMode:_lifecycle.mode];
        candidate[slot] = view;
    }
    return [candidate copy];
}

- (BOOL)installSkillControlsForRuntime:(MobaChampionRuntime *)runtime {
    NSDictionary<MobaCanonicalSkillSlot, MobaSkillButtonView *> *candidate =
        [self skillControlsForRuntime:runtime];
    if (candidate == nil || candidate.count != MobaCanonicalSkillSlots().count) {
        return NO;
    }

    NSDictionary<MobaCanonicalSkillSlot, MobaSkillButtonView *> *previous = _skillButtonViews;
    for (MobaSkillButtonView *view in previous.allValues) {
        [_lifecycle unregisterLocalInteractionResetParticipant:view];
        [view removeFromSuperview];
    }

    _skillButtonViews = candidate;
    for (MobaSkillButtonView *view in _skillButtonViews.allValues) {
        [_lifecycle registerLocalInteractionResetParticipant:view];
        if (_lifecycle.isRunning) {
            [_streamView addSubview:view];
        }
    }
    if (_lifecycle.isRunning) {
        [self layoutBattleControls];
    }
    return YES;
}

- (void)layoutBattleControls {
    [_streamView layoutIfNeeded];
    CGRect safeFrame = _streamView.safeAreaLayoutGuide.layoutFrame;
    CGSize moveHitAreaSize = _moveJoystickView.intrinsicContentSize;
    _moveJoystickView.bounds = (CGRect){ CGPointZero, moveHitAreaSize };
    _moveJoystickView.center = CGPointMake(CGRectGetMinX(safeFrame) +
                                           CGRectGetWidth(safeFrame) * MobaDefaultMoveCenterX,
                                           CGRectGetMinY(safeFrame) +
                                           CGRectGetHeight(safeFrame) * MobaDefaultMoveCenterY);

    CGSize attackHitAreaSize = _attackButtonView.intrinsicContentSize;
    _attackButtonView.bounds = (CGRect){ CGPointZero, attackHitAreaSize };
    _attackButtonView.center = CGPointMake(CGRectGetMinX(safeFrame) +
                                           CGRectGetWidth(safeFrame) * MobaDefaultAttackCenterX,
                                           CGRectGetMinY(safeFrame) +
                                           CGRectGetHeight(safeFrame) * MobaDefaultAttackCenterY);

    for (MobaSkillButtonView *skillView in _skillButtonViews.allValues) {
        MobaLayoutControlProfile *layout = skillView.descriptor.layoutControlProfile;
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
    CGPoint cancelZoneCenter = CGPointMake(CGRectGetMinX(safeFrame) +
                                           CGRectGetWidth(safeFrame) * MobaDefaultCancelZoneCenterX,
                                           CGRectGetMinY(safeFrame) +
                                           CGRectGetHeight(safeFrame) * MobaDefaultCancelZoneCenterY);
    _cancelZoneView.center = cancelZoneCenter;
    [_cancelZoneController updateGeometry:MobaCancelZoneGeometryMake(cancelZoneCenter,
                                                                     MobaCancelZoneDefaultVisualDiameter,
                                                                     MobaDefaultCancelZoneActivationInset)];

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
    BOOL transitioned = [_lifecycle transitionToMode:mode];
    _modeToolbarView.battleModeAvailable = self.isBattleModeAvailable;
    [_modeToolbarView setSelectedMode:_lifecycle.mode];
    [_championSelectorView setMode:_lifecycle.mode];
    for (MobaSkillButtonView *view in _skillButtonViews.allValues) {
        [view setMode:_lifecycle.mode];
    }
    _championSelectorView.selectedChampionID = _championSelectionController.selectedChampionID;
    return transitioned;
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
    [_lifecycle applicationWillResignActive];
}

- (void)applicationDidEnterBackground {
    [_lifecycle applicationDidEnterBackground];
}

- (void)applicationDidBecomeActive {
    [_lifecycle applicationDidBecomeActive];
}

- (void)streamDidDisconnect {
    [_lifecycle streamDidDisconnect];
    [self removeBattleControls];
#if DEBUG
    [_cursorDiagnosticPanel removeFromSuperview];
#endif
}

- (void)viewControllerWillDisappear {
    [_lifecycle viewControllerWillDisappear];
    [self removeBattleControls];
#if DEBUG
    [_cursorDiagnosticPanel removeFromSuperview];
#endif
}

- (void)orientationWillChange {
    [_lifecycle orientationWillChange];
}

- (void)orientationDidChange {
    _modeToolbarView.battleModeAvailable = self.isBattleModeAvailable;
    [self layoutBattleControls];
    [_lifecycle orientationDidChange];
}

- (void)profileWillReload {
    [_lifecycle profileWillReload];
}

- (void)profileDidReload {
    [_lifecycle profileDidReload];
}

- (void)mobaFeatureWillDisable {
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
                    didSelectRuntime:(MobaChampionRuntime *)runtime {
    (void)controller;
    if (![self installSkillControlsForRuntime:runtime]) {
        // Factory validation guarantees four constructible descriptors. Keep
        // installed controls untouched if that invariant is ever violated.
        NSLog(@"MOBA selected runtime skill controls could not be installed");
    }
}

- (void)dealloc {
    [_lifecycle invalidateForDestruction];
    [_championSelectionController invalidate];
    [self removeBattleControls];
#if DEBUG
    [_cursorDiagnosticPanel removeFromSuperview];
#endif
}

@end
