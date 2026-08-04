//
//  MoonlightMobaInputSender.h
//  Moonlight
//

#import <Foundation/Foundation.h>
#import "MoonlightMobaInputAdapter.h"

// Thin stateless boundary around the existing moonlight-common input functions.
@interface MoonlightMobaInputSender : NSObject <MoonlightMobaInputSending>
@end
