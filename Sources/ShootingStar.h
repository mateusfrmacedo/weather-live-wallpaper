#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@interface WWShootingStarLayer : CALayer
@property(nonatomic,strong) UIImage *texture;
@property(nonatomic) CFTimeInterval epoch,pauseTime;
@property(nonatomic) BOOL playbackPaused;
+ (instancetype)layerForSize:(CGSize)size;
- (void)setPlaybackPaused:(BOOL)paused;
@end
static inline WWShootingStarLayer *WWShootingStarForView(UIView *view) {
 for(CALayer *layer in view.layer.sublayers)if([layer isKindOfClass:WWShootingStarLayer.class])return (id)layer;
 return nil;
}
