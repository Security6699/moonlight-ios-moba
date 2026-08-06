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

- (CGPoint)gamePointFromValue:(NSValue *)value {
    CGPoint point = CGPointZero;
    [value getValue:&point size:sizeof(point)];
    return point;
}

- (void)drawBoundaryPoints:(NSArray<NSValue *> *)gamePoints
                     color:(UIColor *)color
                   context:(CGContextRef)context {
    if (gamePoints.count == 0) return;
    CGContextSetStrokeColorWithColor(context, color.CGColor);
    CGPoint first = [self viewPointForGamePoint:[self gamePointFromValue:gamePoints.firstObject]];
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, first.x, first.y);
    for (NSUInteger index = 1; index < gamePoints.count; index++) {
        CGPoint point = [self viewPointForGamePoint:[self gamePointFromValue:gamePoints[index]]];
        CGContextAddLineToPoint(context, point.x, point.y);
    }
    if (gamePoints.count > 1) CGContextClosePath(context);
    CGContextStrokePath(context);
}

- (void)drawRect:(CGRect)rect {
    (void)rect;
    if (!_hasPreviewResult || CGRectIsEmpty(_videoRect)) return;
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    CGContextClipToRect(context, _videoRect);
    CGContextSetLineWidth(context, 2.0);
    [self drawBoundaryPoints:MobaAimPreviewMaximumBoundaryPoints(_previewResult, 96)
                       color:[UIColor colorWithRed:0.20 green:0.75 blue:1.0 alpha:0.75]
                     context:context];
    [self drawBoundaryPoints:MobaAimPreviewMinimumBoundaryPoints(_previewResult, 96)
                       color:[UIColor colorWithWhite:1.0 alpha:0.45]
                     context:context];
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
