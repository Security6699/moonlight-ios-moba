//
//  MobaCursorDiagnosticPanel.m
//  Moonlight
//

#import "MobaCursorDiagnosticPanel.h"
#import "../Core/MobaCursorDiagnostics.h"

@implementation MobaCursorDiagnosticPanel {
    MobaCursorDiagnostics *_diagnostics;
}

- (instancetype)initWithDiagnostics:(MobaCursorDiagnostics *)diagnostics {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        NSParameterAssert(diagnostics != nil);
        _diagnostics = diagnostics;
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.65];
        self.layer.cornerRadius = 8.0;

        UIStackView *rows = [[UIStackView alloc] init];
        rows.axis = UILayoutConstraintAxisVertical;
        rows.spacing = 4.0;
        rows.translatesAutoresizingMaskIntoConstraints = NO;

        for (NSUInteger rowIndex = 0; rowIndex < 3; rowIndex++) {
            UIStackView *row = [[UIStackView alloc] init];
            row.axis = UILayoutConstraintAxisHorizontal;
            row.spacing = 4.0;
            row.distribution = UIStackViewDistributionFillEqually;

            for (NSUInteger columnIndex = 0; columnIndex < 3; columnIndex++) {
                NSUInteger pointIndex = rowIndex * 3 + columnIndex;
                CGPoint point;
                MobaCursorDiagnosticPointAtIndex(pointIndex, &point);
                UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
                button.tag = pointIndex;
                button.titleLabel.font = [UIFont monospacedDigitSystemFontOfSize:10.0
                                                                          weight:UIFontWeightSemibold];
                [button setTitle:[NSString stringWithFormat:@"%.0f,%.0f", point.x, point.y]
                        forState:UIControlStateNormal];
                [button addTarget:self
                           action:@selector(diagnosticButtonPressed:)
                 forControlEvents:UIControlEventTouchUpInside];
                [row addArrangedSubview:button];
            }
            [rows addArrangedSubview:row];
        }

        [self addSubview:rows];
        [NSLayoutConstraint activateConstraints:@[
            [rows.topAnchor constraintEqualToAnchor:self.topAnchor constant:6.0],
            [rows.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:6.0],
            [rows.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-6.0],
            [rows.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-6.0],
            [rows.widthAnchor constraintEqualToConstant:300.0],
        ]];
    }
    return self;
}

- (void)diagnosticButtonPressed:(UIButton *)sender {
    [_diagnostics sendPointAtIndex:(NSUInteger)sender.tag];
}

@end
