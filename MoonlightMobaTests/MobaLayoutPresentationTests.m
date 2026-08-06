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
    XCTAssertEqualWithAccuracy(view.alpha, 0.4, 0.000001);
    XCTAssertEqual(view.visualSize.width, 120);
    XCTAssertEqual(view.hitAreaScale, 1.5);
    XCTAssertEqual(view.layer.zPosition, 33);
}

- (void)testPressedAndDisabledPreviewAreVisualOnly {
    MobaAttackController *controller = [[MobaAttackController alloc] initWithInputDispatcher:self.dispatcher];
    AttackButtonView *view = [[AttackButtonView alloc] initWithAttackController:controller];
    MobaControlLayoutPresentation *presentation = [self presentationWithNormal:0.8 pressed:0.6 disabled:0.2 interaction:YES];
    [view applyControlLayoutPresentation:presentation globalOpacityMultiplier:0.5
                            previewState:MobaControlOpacityPreviewStatePressed];
    XCTAssertEqualWithAccuracy(view.alpha, 0.3, 0.000001);
    XCTAssertFalse(view.isPressed);
    [view applyControlLayoutPresentation:presentation globalOpacityMultiplier:0.5
                            previewState:MobaControlOpacityPreviewStateDisabled];
    XCTAssertEqualWithAccuracy(view.alpha, 0.1, 0.000001);
    XCTAssertFalse(view.isPressed);
}

- (void)testZeroOpacityDoesNotDisableBattleHitTesting {
    MobaAttackController *controller = [[MobaAttackController alloc] initWithInputDispatcher:self.dispatcher];
    AttackButtonView *view = [[AttackButtonView alloc] initWithAttackController:controller];
    [view applyControlLayoutPresentation:[self presentationWithNormal:0 pressed:0 disabled:0 interaction:YES]
                  globalOpacityMultiplier:1 previewState:MobaControlOpacityPreviewStateAutomatic];
    XCTAssertEqual(view.alpha, 0.0);
    XCTAssertTrue(view.userInteractionEnabled);
    XCTAssertTrue(controller.isInteractionEnabled);
}

- (void)testInteractionDisabledIsIndependentFromOpacity {
    MobaAttackController *controller = [[MobaAttackController alloc] initWithInputDispatcher:self.dispatcher];
    AttackButtonView *view = [[AttackButtonView alloc] initWithAttackController:controller];
    [view applyControlLayoutPresentation:[self presentationWithNormal:1 pressed:1 disabled:0.4 interaction:NO]
                  globalOpacityMultiplier:1 previewState:MobaControlOpacityPreviewStateAutomatic];
    XCTAssertFalse(view.userInteractionEnabled);
    XCTAssertFalse(controller.isInteractionEnabled);
    XCTAssertEqualWithAccuracy(view.alpha, 0.4, 0.000001);
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
    XCTAssertEqualWithAccuracy(view.alpha, 0.3, 0.000001);
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
