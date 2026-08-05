//
//  MobaCancelZoneGeometry.h
//  Moonlight
//

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    CGPoint center;
    CGFloat visualDiameter;
    CGFloat activationInset;
} MobaCancelZoneGeometry;

NS_INLINE MobaCancelZoneGeometry MobaCancelZoneGeometryMake(CGPoint center,
                                                            CGFloat visualDiameter,
                                                            CGFloat activationInset) {
    MobaCancelZoneGeometry geometry;
    geometry.center = center;
    geometry.visualDiameter = visualDiameter;
    geometry.activationInset = activationInset;
    return geometry;
}

FOUNDATION_EXPORT BOOL MobaCancelZoneGeometryIsValid(MobaCancelZoneGeometry geometry);

// Uses a circular radial hit test. Boundary points are inside. On invalid
// geometry or point, returns NO and leaves inside unchanged.
FOUNDATION_EXPORT BOOL MobaCancelZoneContainsPoint(MobaCancelZoneGeometry geometry,
                                                   CGPoint point,
                                                   BOOL * _Nullable inside);

NS_ASSUME_NONNULL_END
