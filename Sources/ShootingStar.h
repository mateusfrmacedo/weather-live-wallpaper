#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

typedef struct {CGPoint center;CGFloat opacity,angle;} WWMeteorSample;
static inline WWMeteorSample WWMeteorAt(CGSize size,double elapsed) {
 double phase=fmod(MAX(0,elapsed),13.0),progress=(phase-1.0)/1.1;
 CGFloat length=MIN(180,MAX(90,size.width*0.12));
 CGFloat p=MIN(1,MAX(0,progress));
 CGPoint center=CGPointMake(size.width+length/2-(size.width+length)*p,size.height*(0.20+0.22*p));
 CGFloat opacity=progress>0 && progress<1 ? 0.24*MIN(1,MIN(progress/0.12,(1-progress)/0.18)) : 0;
 return (WWMeteorSample){center,opacity,-atan2(size.height*0.22,size.width+length)};
}
@interface WWShootingStarLayer : CALayer
@property(nonatomic,strong) UIImage *texture;
@property(nonatomic) CFTimeInterval epoch,pauseTime;
@property(nonatomic) BOOL playbackPaused;
+ (instancetype)layerForSize:(CGSize)size;
- (void)drawCurrentFrameInContext:(CGContextRef)context;
- (void)setPlaybackPaused:(BOOL)paused;
@end
static inline WWShootingStarLayer *WWShootingStarForView(UIView *view) {
 for(CALayer *layer in view.layer.sublayers)if([layer isKindOfClass:WWShootingStarLayer.class])return (id)layer;
 return nil;
}
