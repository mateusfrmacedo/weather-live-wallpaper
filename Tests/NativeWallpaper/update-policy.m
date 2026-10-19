#import "../../Sources/NativeWallpaper/UpdatePolicy.h"
int main(void){@autoreleasepool{
 NSDictionary *base=@{@"condition":@"clear",@"locationID":@"city-a",@"manualTime":@(-1),@"elevation":@35,@"cloudCover":@0.1,@"wind":@10,@"temperature":@24};
 NSCAssert(WWNeedsNewScene(nil,base,0),@"First scene must be published");
 NSMutableDictionary *next=[base mutableCopy];next[@"temperature"]=@29;
 NSCAssert(!WWNeedsNewScene(base,next,600),@"Temperature must not restart the scene");
 next[@"condition"]=@"rain";NSCAssert(WWNeedsNewScene(base,next,1),@"Condition changes must be immediate");
 next=[base mutableCopy];next[@"locationID"]=@"city-b";NSCAssert(WWNeedsNewScene(base,next,1),@"City change must be immediate");
 next=[base mutableCopy];next[@"elevation"]=@39;
 NSCAssert(!WWNeedsNewScene(base,next,299),@"Avoid minute-by-minute exports");
 NSCAssert(WWNeedsNewScene(base,next,300),@"Update a visibly changed sky");
 NSMutableDictionary *sunset=[base mutableCopy];sunset[@"elevation"]=@1;
 next=[sunset mutableCopy];next[@"elevation"]=@0;
 NSCAssert(WWNeedsNewScene(sunset,next,300),@"Twilight must update more often");
 NSCAssert(!WWNeedsNewScene(base,base,1799) && WWNeedsNewScene(base,base,1800),@"Bound stale celestial positions");
 NSMutableDictionary *night=[base mutableCopy];night[@"elevation"]=@(-20);
 NSCAssert(!WWNeedsNewScene(night,night,299) && WWNeedsNewScene(night,night,300),@"Moon position must refresh every five minutes at night");
 next=[base mutableCopy];next[@"cloudCover"]=@0.7;NSCAssert(WWNeedsNewScene(base,next,600),@"Cloud coverage update");
 next=[base mutableCopy];next[@"renderWidth"]=@1512;next[@"renderHeight"]=@982;next[@"renderScale"]=@2;NSCAssert(WWNeedsNewScene(base,next,1),@"Display pixel changes must re-export immediately");
 NSLog(@"PASS: weather change policy");return 0;
}}
