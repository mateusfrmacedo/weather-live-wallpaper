#import "ShootingStar.h"
#import <ImageIO/ImageIO.h>
@implementation WWShootingStarLayer
+ (instancetype)layerForSize:(CGSize)size {
 NSURL *url=[NSURL fileURLWithPath:@"/System/iOSSupport/System/Library/PrivateFrameworks/WeatherUI.framework/Resources/VFX/WeatherV136_Default_Background.vfx/assets/ShootingStarTexture.ktx"];
 CGImageSourceRef source=CGImageSourceCreateWithURL((__bridge CFURLRef)url,NULL);
 CGImageRef image=source ? CGImageSourceCreateImageAtIndex(source,0,NULL) : NULL;if(source)CFRelease(source);
 if(!image)return nil;
 WWShootingStarLayer *layer=[self layer];layer.texture=[UIImage imageWithCGImage:image];CGImageRelease(image);
 layer.frame=(CGRect){CGPointZero,size};layer.zPosition=100;layer.masksToBounds=YES;layer.epoch=CACurrentMediaTime();
 CALayer *sprite=[CALayer layer];sprite.contents=(__bridge id)layer.texture.CGImage;
 CGFloat length=MIN(180,MAX(90,size.width*0.12));sprite.bounds=CGRectMake(0,0,length,2);sprite.opacity=0;
 [layer addSublayer:sprite];
 // One analytic segment; the compositor interpolates at the display cadence.
 // Keep the wraparound jump outside the visible interval.
 WWMeteorSample first=WWMeteorAt(size,1),last=WWMeteorAt(size,2.1);
 sprite.transform=CATransform3DMakeRotation(first.angle,0,0,1);
 CAKeyframeAnimation *position=[CAKeyframeAnimation animationWithKeyPath:@"position"];
 position.values=@[[NSValue valueWithCGPoint:first.center],[NSValue valueWithCGPoint:first.center],[NSValue valueWithCGPoint:last.center],[NSValue valueWithCGPoint:last.center]];
 position.keyTimes=@[@0,@(1.0/13),@(2.1/13),@1];position.calculationMode=kCAAnimationLinear;
 CAKeyframeAnimation *opacity=[CAKeyframeAnimation animationWithKeyPath:@"opacity"];
 opacity.values=@[@0,@0,@0.24,@0.24,@0,@0];opacity.keyTimes=@[@0,@(1.0/13),@(1.132/13),@(1.902/13),@(2.1/13),@1];
 CAAnimationGroup *group=[CAAnimationGroup animation];group.animations=@[position,opacity];group.duration=13;group.repeatCount=HUGE_VALF;group.beginTime=layer.epoch;[sprite addAnimation:group forKey:@"nativeMeteorTexture"];
 return layer;
}
- (void)setPlaybackPaused:(BOOL)paused {
 if(paused==_playbackPaused)return;
 if(paused){self.pauseTime=CACurrentMediaTime();self.timeOffset=[self convertTime:self.pauseTime fromLayer:nil];self.speed=0;}
 else {CFTimeInterval held=self.timeOffset;self.speed=1;self.timeOffset=0;self.beginTime=0;self.beginTime=[self convertTime:CACurrentMediaTime() fromLayer:nil]-held;self.epoch+=CACurrentMediaTime()-self.pauseTime;}
 _playbackPaused=paused;
}
- (void)drawCurrentFrameInContext:(CGContextRef)context {
 CFTimeInterval time=self.playbackPaused ? self.pauseTime : CACurrentMediaTime();WWMeteorSample sample=WWMeteorAt(self.bounds.size,time-self.epoch);
 if(sample.opacity<=0)return;
 CGFloat length=MIN(180,MAX(90,self.bounds.size.width*0.12));
 CGContextSaveGState(context);CGContextTranslateCTM(context,sample.center.x,sample.center.y);CGContextRotateCTM(context,sample.angle);CGContextSetAlpha(context,sample.opacity);
 [self.texture drawInRect:CGRectMake(-length/2,-1,length,2)];CGContextRestoreGState(context);
}
@end
