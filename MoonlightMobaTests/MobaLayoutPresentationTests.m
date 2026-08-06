//
//  MobaLayoutPresentationTests.m
//  MoonlightMobaTests
//

#import <XCTest/XCTest.h>

#import "../Limelight/Input/MOBA/Controls/AttackButtonView.h"
#import "../Limelight/Input/MOBA/Controls/MobaAttackController.h"
#import "../Limelight/Input/MOBA/Controls/MobaCancelZoneView.h"
#import "../Limelight/Input/MOBA/Controls/MobaControlLayoutPresentation.h"
#import "../Limelight/Input/MOBA/Controls/MobaMovementController.h"
#import "../Limelight/Input/MOBA/Controls/MoveJoystickView.h"
#import "../Limelight/Input/MOBA/Core/MobaInputDispatcher.h"

@interface MobaLayoutPresentationSink : NSObject <MobaInputSink>
@end
@implementation MobaLayoutPresentationSink
- (void)setKeyCode:(uint16_t)keyCode down:(BOOL)down { (void)keyCode; (void)down; }
- (void)moveCursorToCanvasPoint:(CGPoint)point { (void)point; }
- (void)sendMouseButton:(int)button down:(BOOL)down { (void)button; (void)down; }
@end

@interface MobaLayoutPresentationTests : XCTestCase
@end

@implementation MobaLayoutPresentationTests

- (MobaInputDispatcher *)dispatcher {
    return [[MobaInputDispatcher alloc] initWithSink:[[MobaLayoutPresentationSink alloc] init]];
}

- (MobaControlLayoutPresentation *)presentationWithNormal:(CGFloat)normal
                                                   pressed:(CGFloat)pressed
                                                  disabled:(CGFloat)disabled
                                               interaction:(BOOL)interaction {
    return [[MobaControlLayoutPresentation alloc]
        initWithCenterX:0.5 centerY:0.5 visualSize:CGSizeMake(120, 100)
        hitAreaScale:1.5 wheelRadiusPt:nil normalOpacity:normal
        pressedOpacity:pressed disabledOpacity:disabled zIndex:33 interactionEnabled:interaction];
}

- (void)prepareViewForHitTesting:(UIView *)view {
    CGSize size = view.intrinsicContentSize;
    view.frame = CGRectMake(0.0, 0.0, size.width, size.height);
    [view setNeedsLayout];
    [view layoutIfNeeded];
}

- (UIView *)centerHitForView:(UIView *)view {
    return [view hitTest:CGPointMake(CGRectGetMidX(view.bounds), CGRectGetMidY(view.bounds))
               withEvent:nil];
}

- (void)testEffectiveOpacityMultipliesAndClamps {
    XCTAssertEqualWithAccuracy(MobaEffectiveControlOpacity(0.8, 0.5), 0.4, 0.000001);
    XCTAssertEqual(MobaEffectiveControlOpacity(2.0, 1.0), 1.0);
    XCTAssertEqual(MobaEffectiveControlOpacity(-1.0, 1.0), 0.0);
}

- (void)testAttackNormalOpacityUsesGlobalMultiplier {
    MobaAttackController *controller = [[MobaAttackController alloc] initWithInputDispatcher:self.dispatcher];
    AttackButtonView *view = [[AttackButtonView alloc] initWithAttackController:controller];
    [view applyControlLayoutPresentation:[self presentationWithNormal:0.8 pressed:0.9 disabled:0.3 interaction:YES]
                  globalOpacityMultiplier:0.5 previewState:MobaControlOpacityPreviewStateNormal];
    [self prepareViewForHitTesting:view];
    XCTAssertEqualWithAccuracy(view.alpha, 1.0, 0.000001);
    XCTAssertEqualWithAccuracy(view.effectiveVisualOpacity, 0.4, 0.000001);
    XCTAssertEqual([self centerHitForView:view], view);
    XCTAssertTrue(controller.isInteractionEnabled);
    XCTAssertEqual(view.visualSize.width, 120);
    XCTAssertEqual(view.hitAreaScale, 1.5);
    XCTAssertEqual(view.layer.zPosition, 33);
}

- (void)testPressedAndDisabledPreviewAreVisualOnly {
    MobaAttackController *controller = [[MobaAttackController alloc] initWithInputDispatcher:self.dispatcher];
    AttackButtonView *view = [[AttackButtonView alloc] initWithAttackController:controller];
    MobaControlLayoutPresentation *presentation = [self presentationWithNormal:0.8 pressed:0.6 disabled:0 interaction:YES];
    [view applyControlLayoutPresentation:presentation globalOpacityMultiplier:0.5
                            previewState:MobaControlOpacityPreviewStatePressed];
    [self prepareViewForHitTesting:view];
    XCTAssertEqualWithAccuracy(view.alpha, 1.0, 0.000001);
    XCTAssertEqualWithAccuracy(view.effectiveVisualOpacity, 0.3, 0.000001);
    XCTAssertEqual([self centerHitForView:view], view);
    XCTAssertTrue(controller.isInteractionEnabled);
    XCTAssertFalse(view.isPressed);
    [view applyControlLayoutPresentation:presentation globalOpacityMultiplier:0.5
                            previewState:MobaControlOpacityPreviewStateDisabled];
    XCTAssertEqualWithAccuracy(view.alpha, 1.0, 0.000001);
    XCTAssertEqualWithAccuracy(view.effectiveVisualOpacity, 0.0, 0.000001);
    XCTAssertEqual([self centerHitForView:view], view);
    XCTAssertTrue(controller.isInteractionEnabled);
    XCTAssertFalse(view.isPressed);
}

- (void)testZeroOpacityDoesNotDisableBattleHitTesting {
    MobaAttackController *controller = [[MobaAttackController alloc] initWithInputDispatcher:self.dispatcher];
    AttackButtonView *view = [[AttackButtonView alloc] initWithAttackController:controller];
    [view applyControlLayoutPresentation:[self presentationWithNormal:0 pressed:0 disabled:0 interaction:YES]
                  globalOpacityMultiplier:1 previewState:MobaControlOpacityPreviewStateAutomatic];
    [self prepareViewForHitTesting:view];
    XCTAssertEqual(view.alpha, 1.0);
    XCTAssertEqual(view.effectiveVisualOpacity, 0.0);
    XCTAssertTrue(view.userInteractionEnabled);
    XCTAssertTrue(controller.isInteractionEnabled);
    XCTAssertEqual([self centerHitForView:view], view);
}

- (void)testZeroGlobalOpacityDoesNotDisableBattleHitTesting {
    MobaAttackController *controller = [[MobaAttackController alloc] initWithInputDispatcher:self.dispatcher];
    AttackButtonView *view = [[AttackButtonView alloc] initWithAttackController:controller];
    [view applyControlLayoutPresentation:[self presentationWithNormal:0.8 pressed:0.9 disabled:0.3 interaction:YES]
                  globalOpacityMultiplier:0 previewState:MobaControlOpacityPreviewStateAutomatic];
    [self prepareViewForHitTesting:view];
    XCTAssertEqual(view.alpha, 1.0);
    XCTAssertEqual(view.effectiveVisualOpacity, 0.0);
    XCTAssertEqual([self centerHitForView:view], view);
    XCTAssertTrue(controller.isInteractionEnabled);
}

- (void)testMoveZeroOpacityKeepsInteractiveContainerHittable {
    MobaMovementController *controller = [[MobaMovementController alloc]
        initWithInputDispatcher:self.dispatcher keyMapping:MobaDefaultMovementKeyMapping()
        wheelRadius:95 deadZoneRatio:MobaJoystickDefaultDeadZoneRatio
        directionHysteresisDegrees:MobaJoystickDefaultDirectionHysteresisDegrees];
    MoveJoystickView *view = [[MoveJoystickView alloc] initWithMovementController:controller];
    MobaControlLayoutPresentation *presentation = [[MobaControlLayoutPresentation alloc]
        initWithCenterX:0.5 centerY:0.5 visualSize:CGSizeMake(190, 190)
        hitAreaScale:1.2 wheelRadiusPt:@95 normalOpacity:0 pressedOpacity:0
        disabledOpacity:0 zIndex:10 interactionEnabled:YES];
    [view applyControlLayoutPresentation:presentation globalOpacityMultiplier:1
                            previewState:MobaControlOpacityPreviewStateAutomatic];
    [self prepareViewForHitTesting:view];
    XCTAssertEqual(view.alpha, 1.0);
    XCTAssertEqual(view.effectiveVisualOpacity, 0.0);
    XCTAssertEqual([self centerHitForView:view], view);
    XCTAssertTrue(controller.isInteractionEnabled);
}

- (void)testInteractionDisabledIsIndependentFromOpacity {
    MobaAttackController *controller = [[MobaAttackController alloc] initWithInputDispatcher:self.dispatcher];
    AttackButtonView *view = [[AttackButtonView alloc] initWithAttackController:controller];
    [view applyControlLayoutPresentation:[self presentationWithNormal:1 pressed:1 disabled:0.4 interaction:NO]
                  globalOpacityMultiplier:1 previewState:MobaControlOpacityPreviewStateAutomatic];
    [self prepareViewForHitTesting:view];
    XCTAssertFalse(view.userInteractionEnabled);
    XCTAssertFalse(controller.isInteractionEnabled);
    XCTAssertEqualWithAccuracy(view.alpha, 1.0, 0.000001);
    XCTAssertEqualWithAccuracy(view.effectiveVisualOpacity, 0.4, 0.000001);
    XCTAssertNil([self centerHitForView:view]);
}

- (void)testPressedOpacityZeroOnlyHidesAttackVisualSubtree {
    MobaAttackController *controller = [[MobaAttackController alloc] initWithInputDispatcher:self.dispatcher];
    AttackButtonView *view = [[AttackButtonView alloc] initWithAttackController:controller];
    [view applyControlLayoutPresentation:[self presentationWithNormal:0.8 pressed:0 disabled:0.3 interaction:YES]
                  globalOpacityMultiplier:1 previewState:MobaControlOpacityPreviewStatePressed];
    [self prepareViewForHitTesting:view];
    XCTAssertEqual(view.alpha, 1.0);
    XCTAssertEqual(view.effectiveVisualOpacity, 0.0);
    XCTAssertEqual([self centerHitForView:view], view);
    XCTAssertTrue(controller.isInteractionEnabled);
}

- (void)testAttackRendersWideVisualSizeWithoutCollapsingToDiameter {
    MobaAttackController *controller = [[MobaAttackController alloc] initWithInputDispatcher:self.dispatcher];
    AttackButtonView *view = [[AttackButtonView alloc] initWithAttackController:controller];
    MobaControlLayoutPresentation *presentation = [[MobaControlLayoutPresentation alloc]
        initWithCenterX:0.5 centerY:0.5 visualSize:CGSizeMake(140, 90)
        hitAreaScale:1.5 wheelRadiusPt:nil normalOpacity:1 pressedOpacity:1
        disabledOpacity:0.3 zIndex:1 interactionEnabled:YES];
    [view applyControlLayoutPresentation:presentation globalOpacityMultiplier:1
                            previewState:MobaControlOpacityPreviewStateAutomatic];
    [self prepareViewForHitTesting:view];
    XCTAssertTrue(CGSizeEqualToSize(view.visualSize, CGSizeMake(140, 90)));
    XCTAssertTrue(CGSizeEqualToSize(view.renderedVisualSize, CGSizeMake(140, 90)));
    XCTAssertTrue(CGSizeEqualToSize(view.intrinsicContentSize, CGSizeMake(210, 135)));
}

- (void)testAttackRendersTallVisualSizeWithoutCollapsingToDiameter {
    MobaAttackController *controller = [[MobaAttackController alloc] initWithInputDispatcher:self.dispatcher];
    AttackButtonView *view = [[AttackButtonView alloc] initWithAttackController:controller];
    MobaControlLayoutPresentation *presentation = [[MobaControlLayoutPresentation alloc]
        initWithCenterX:0.5 centerY:0.5 visualSize:CGSizeMake(90, 140)
        hitAreaScale:1.25 wheelRadiusPt:nil normalOpacity:1 pressedOpacity:1
        disabledOpacity:0.3 zIndex:1 interactionEnabled:YES];
    [view applyControlLayoutPresentation:presentation globalOpacityMultiplier:1
                            previewState:MobaControlOpacityPreviewStateAutomatic];
    [self prepareViewForHitTesting:view];
    XCTAssertTrue(CGSizeEqualToSize(view.visualSize, CGSizeMake(90, 140)));
    XCTAssertTrue(CGSizeEqualToSize(view.renderedVisualSize, CGSizeMake(90, 140)));
    XCTAssertTrue(CGSizeEqualToSize(view.intrinsicContentSize, CGSizeMake(112.5, 175)));
}

- (void)testMovementWheelRadiusUpdatesOnlyAtDisabledNeutralBoundary {
    MobaMovementController *controller = [[MobaMovementController alloc]
        initWithInputDispatcher:self.dispatcher keyMapping:MobaDefaultMovementKeyMapping()
        wheelRadius:95 deadZoneRatio:MobaJoystickDefaultDeadZoneRatio
        directionHysteresisDegrees:MobaJoystickDefaultDirectionHysteresisDegrees];
    XCTAssertFalse([controller updateWheelRadiusForCommittedProfile:120]);
    [controller setInteractionEnabled:NO];
    XCTAssertTrue([controller updateWheelRadiusForCommittedProfile:120]);
    XCTAssertEqual(controller.wheelRadius, 120);
}

- (void)testCancelZoneUsesGlobalOpacityAndEditorVisibility {
    MobaCancelZoneView *view = [[MobaCancelZoneView alloc] initWithVisualDiameter:112];
    MobaCancelZoneLayoutPresentation *presentation = [[MobaCancelZoneLayoutPresentation alloc]
        initWithCenterX:0.3 centerY:0.4 diameterPt:160 activationInsetPt:10 opacity:0.6
        visibleOnlyWhileCasting:YES];
    [view applyCancelZoneLayoutPresentation:presentation globalOpacityMultiplier:0.5
                              editorPreview:YES previewState:MobaControlOpacityPreviewStateNormal];
    XCTAssertEqual(view.visualDiameter, 160);
    XCTAssertEqualWithAccuracy(view.alpha, 1.0, 0.000001);
    XCTAssertEqualWithAccuracy(view.effectiveVisualOpacity, 0.3, 0.000001);
    XCTAssertFalse(view.hidden);
    XCTAssertFalse(view.userInteractionEnabled);
}

- (void)testGlobalOpacityNeverAffectsUnrelatedUIView {
    UIView *toolbar = [[UIView alloc] initWithFrame:CGRectZero];
    toolbar.alpha = 0.77;
    (void)MobaEffectiveControlOpacity(0.2, 0.1);
    XCTAssertEqualWithAccuracy(toolbar.alpha, 0.77, 0.000001);
}

@end
