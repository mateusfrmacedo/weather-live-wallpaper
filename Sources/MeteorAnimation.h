#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#include <math.h>

// WeatherV136 ShootingStar: 11–15 s bursts, 0.48–0.52 s life,
// 220–280 world units/s, 20–28 × 0.4–0.72 size, authored size/opacity curves.
// Keep one compositor implementation for Catalyst and the native extension.
static double WWMeteorRandom(uint32_t *state) {
 *state=*state*1664525u+1013904223u;return (double)(*state)/4294967296.0;
}
static NSValue *WWMeteorPoint(CGPoint point) {
 return [NSValue valueWithBytes:&point objCType:@encode(CGPoint)];
}
static CAKeyframeAnimation *WWMeteorTrack(NSString *key,NSArray *values,NSArray *times,BOOL curved) {
 CAKeyframeAnimation *animation=[CAKeyframeAnimation animationWithKeyPath:key];
 animation.values=values;animation.keyTimes=times;
 animation.calculationMode=curved ? kCAAnimationCubic : kCAAnimationLinear;
 return animation;
}
static void WWPopulateMeteorLayer(CALayer *layer,CGImageRef texture,CGSize size,uint32_t seed) {
 for(CALayer *child in [layer.sublayers copy])[child removeFromSuperlayer];
 layer.bounds=(CGRect){CGPointZero,size};layer.masksToBounds=YES;
 enum {count=16};double starts[count],life[count],length[count],thickness[count],velocity[count];CGPoint origins[count];
 double cursor=2;
 // Use vertical projection, so ultrawide displays do not stretch the streak.
 double projection=size.height/(360.0/0.88);
 for(int i=0;i<count;i++){
  starts[i]=cursor;life[i]=0.48+0.04*WWMeteorRandom(&seed);
  length[i]=(20+8*WWMeteorRandom(&seed))*projection;
  thickness[i]=(0.4+0.32*WWMeteorRandom(&seed))*projection;
  velocity[i]=(220+60*WWMeteorRandom(&seed))*projection;
  origins[i]=CGPointMake(size.width/2+110*projection,size.height*(0.06+0.28*WWMeteorRandom(&seed)));
  cursor+=11+4*WWMeteorRandom(&seed);
 }
 double period=cursor-2;CFTimeInterval epoch=[layer convertTime:CACurrentMediaTime() fromLayer:nil];
 for(int i=0;i<count;i++){
  double start=starts[i]/period,end=(starts[i]+life[i])/period;
  CALayer *sprite=[CALayer layer];sprite.contents=(__bridge id)texture;sprite.opacity=0;
  sprite.bounds=CGRectMake(0,0,1,1);sprite.transform=CATransform3DMakeRotation(-atan2(0.12,1),0,0,1);
  [layer addSublayer:sprite];
  CGPoint from=origins[i],to=CGPointMake(from.x-velocity[i]*life[i],from.y+velocity[i]*life[i]*0.12);
  CAKeyframeAnimation *position=WWMeteorTrack(@"position",@[WWMeteorPoint(from),WWMeteorPoint(from),WWMeteorPoint(to),WWMeteorPoint(to)],@[@0,@(start),@(end),@1],NO);
  // Native opacity declines immediately. The zero-thickness first frame gives
  // the appearance its soft onset; there is no long artificial fade-in.
  CAKeyframeAnimation *alpha=WWMeteorTrack(@"opacity",@[@0,@0,@(0.24*0.971978),@(0.24*0.6777403),@0,@0],@[@0,@(start),@(start+0.000001),@(start+(end-start)*0.63438773),@(end),@1],NO);
  CAKeyframeAnimation *width=WWMeteorTrack(@"bounds.size.width",@[@(length[i]*0.13634618),@(length[i]*0.13634618),@(length[i]*0.29414064),@(length[i]*0.94886214),@(length[i]*0.6532588),@(length[i]*0.6532588)],@[@0,@(start),@(start+(end-start)*0.20899282),@(start+(end-start)*0.36603463),@(end),@1],YES);
  CAKeyframeAnimation *height=WWMeteorTrack(@"bounds.size.height",@[@0,@0,@(thickness[i]*0.8524266),@(thickness[i]*0.7545708),@(thickness[i]*0.631836),@0],@[@0,@(start),@(start+(end-start)*0.4175663),@(start+(end-start)*0.7314295),@(end),@1],YES);
  CAAnimationGroup *group=[CAAnimationGroup animation];group.animations=@[position,alpha,width,height];group.duration=period;group.repeatCount=HUGE_VALF;group.beginTime=epoch;
  [sprite addAnimation:group forKey:@"meteor"];
 }
}
