#import <Foundation/Foundation.h>
#include <math.h>

// Compare with the last successfully published scene, not the last API response.
static BOOL WWNeedsNewScene(NSDictionary *previous, NSDictionary *next, NSTimeInterval age) {
 if(!previous)return YES;
 for(NSString *key in @[@"condition",@"locationID",@"manualTime"])
  if(![previous[key] isEqual:next[key]])return YES;
 double elevation=[next[@"elevation"] doubleValue];
 double threshold=fabs(elevation)<8 ? 0.75 : 3;
 if(age>=300 && fabs(elevation-[previous[@"elevation"] doubleValue])>=threshold)return YES;
 if(age>=300 && fabs([next[@"cloudCover"] doubleValue]-[previous[@"cloudCover"] doubleValue])>=0.15)return YES;
 if(age>=300 && fabs([next[@"wind"] doubleValue]-[previous[@"wind"] doubleValue])>=10)return YES;
 // Refresh celestial positions even when elevation is almost unchanged.
 return age>=1800;
}
