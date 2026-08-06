//
//  MobaAimPreviewView.m
//  Moonlight
//

#import "MobaAimPreviewView.h"

@implementation MobaAimPreviewView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.userInteractionEnabled = NO;
        self.opaque = NO;
    }
    return self;
}

- (void)setVideoRect:(CGRect)videoRect { _videoRect = videoRect; [self setNeedsDisplay]; }
- (void)setPreviewResult:(MobaAimPreviewResult)previewResult valid:(BOOL)valid {
    _previewResult = previewResult;
    _hasPreviewResult = valid;
    [self setNeedsDisplay];
}

- (CGPoint)viewPointForGamePoint:(CGPoint)point {
    CGPoint mapped = CGPointZero;
    MobaAimPreviewMapGamePointToVideoRect(point, _videoRect, &mapped);
    return mapped;
}

- (void)drawEllipseWithRadii:(MobaAimRadii)radii color:(UIColor *)color context:(CGContextRef)context {
    CGPoint anchor = [self viewPointForGamePoint:_previewResult.anchor];
    CGPoint left = [self viewPointForGamePoint:CGPointMake(_previewResult.anchor.x - radii.leftPx,
                                                           _previewResult.anchor.y)];
    CGPoint right = [self viewPointForGamePoint:CGPointMake(_previewResult.anchor.x + radii.rightPx,
                                                            _previewResult.anchor.y)];
    CGPoint up = [self viewPointForGamePoint:CGPointMake(_previewResult.anchor.x,
                                                         _previewResult.anchor.y - radii.upPx)];
    CGPoint down = [self viewPointForGamePoint:CGPointMake(_previewResult.anchor.x,
                                                           _previewResult.anchor.y + radii.downPx)];
    CGRect ellipse = CGRectMake(left.x, up.y, right.x - left.x, down.y - up.y);
    CGContextSetStrokeColorWithColor(context, color.CGColor);
    CGContextStrokeEllipseInRect(context, ellipse);
    (void)anchor;
}

- (void)drawRect:(CGRect)rect {
    (void)rect;
    if (!_hasPreviewResult || CGRectIsEmpty(_videoRect)) return;
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    CGContextSetLineWidth(context, 2.0);
    [self drawEllipseWithRadii:_previewResult.maximumRadii
                         color:[UIColor colorWithRed:0.20 green:0.75 blue:1.0 alpha:0.75]
                       context:context];
    if (_previewResult.pointCast) {
        [self drawEllipseWithRadii:_previewResult.minimumRadii
                             color:[UIColor colorWithWhite:1.0 alpha:0.45]
                           context:context];
    }
    CGPoint anchor = [self viewPointForGamePoint:_previewResult.anchor];
    CGPoint defaultTarget = [self viewPointForGamePoint:_previewResult.defaultTarget];
    CGPoint target = [self viewPointForGamePoint:_previewResult.target];
    CGContextSetStrokeColorWithColor(context, [UIColor colorWithWhite:1.0 alpha:0.65].CGColor);
    CGContextMoveToPoint(context, anchor.x, anchor.y);
    CGContextAddLineToPoint(context, defaultTarget.x, defaultTarget.y);
    CGContextStrokePath(context);
    CGContextSetStrokeColorWithColor(context, UIColor.systemYellowColor.CGColor);
    CGContextMoveToPoint(context, anchor.x, anchor.y);
    CGContextAddLineToPoint(context, target.x, target.y);
    CGContextStrokePath(context);
    CGContextSetFillColorWithColor(context, UIColor.systemGreenColor.CGColor);
    CGContextFillEllipseInRect(context, CGRectMake(anchor.x - 5, anchor.y - 5, 10, 10));
    CGContextSetFillColorWithColor(context, UIColor.systemYellowColor.CGColor);
    CGContextFillEllipseInRect(context, CGRectMake(target.x - 5, target.y - 5, 10, 10));
    CGContextRestoreGState(context);
}
@end
