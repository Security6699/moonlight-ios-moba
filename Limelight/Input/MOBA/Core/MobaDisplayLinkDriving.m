//
//  MobaDisplayLinkDriving.m
//  Moonlight
//

#import "MobaDisplayLinkDriving.h"

const MobaCursorUpdateRate MobaCursorUpdateRateDefault = MobaCursorUpdateRate60Hz;

BOOL MobaCursorUpdateRateIsValid(MobaCursorUpdateRate updateRate) {
    return updateRate == MobaCursorUpdateRate30Hz ||
        updateRate == MobaCursorUpdateRate60Hz ||
        updateRate == MobaCursorUpdateRate120Hz;
}
