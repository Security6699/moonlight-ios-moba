//
//  MobaCursorDiagnosticPanel.h
//  Moonlight
//

#import <UIKit/UIKit.h>
#import "../Core/MobaOverlayLifecycle.h"

@class MobaCursorDiagnostics;

@interface MobaCursorDiagnosticPanel : UIView <MobaLocalInteractionResetParticipant>

- (instancetype)initWithDiagnostics:(MobaCursorDiagnostics *)diagnostics NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

@end
