#import "ShootingStar.h"
#import <ImageIO/ImageIO.h>
#import "MeteorAnimation.h"
@implementation WWShootingStarLayer
+ (instancetype)layerForSize:(CGSize)size {
 NSURL *url=[NSURL fileURLWithPath:@"/System/iOSSupport/System/Library/PrivateFrameworks/WeatherUI.framework/Resources/VFX/WeatherV136_Default_Background.vfx/assets/ShootingStarTexture.ktx"];
 CGImageSourceRef source=CGImageSourceCreateWithURL((__bridge CFURLRef)url,NULL);
 CGImageRef image=source ? CGImageSourceCreateImageAtIndex(source,0,NULL) : NULL;if(source)CFRelease(source);
 if(!image)return nil;
 WWShootingStarLayer *layer=[self layer];layer.texture=[UIImage imageWithCGImage:image];CGImageRelease(image);
 layer.frame=(CGRect){CGPointZero,size};layer.zPosition=100;layer.masksToBounds=YES;layer.epoch=CACurrentMediaTime();
 WWPopulateMeteorLayer(layer,layer.texture.CGImage,size,arc4random());
 return layer;
}
- (void)setPlaybackPaused:(BOOL)paused {
 if(paused==_playbackPaused)return;
 if(paused){self.pauseTime=CACurrentMediaTime();self.timeOffset=[self convertTime:self.pauseTime fromLayer:nil];self.speed=0;}
 else {CFTimeInterval held=self.timeOffset;self.speed=1;self.timeOffset=0;self.beginTime=0;self.beginTime=[self convertTime:CACurrentMediaTime() fromLayer:nil]-held;self.epoch+=CACurrentMediaTime()-self.pauseTime;}
 _playbackPaused=paused;
}
@end
