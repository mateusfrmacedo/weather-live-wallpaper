#import "SceneExporter.h"
#import "../ShootingStar.h"
#import <AVFoundation/AVFoundation.h>
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import <objc/runtime.h>
#include <unistd.h>

@interface NSObject (WWRenderFrame)
- (void)renderWithCompletion:(void(^)(void))completion;
@end

// Instrument only this offscreen renderer's layer; no global swizzles or screen recording.
@interface WWCaptureLayer : CAMetalLayer @end
@implementation WWCaptureLayer
- (id<CAMetalDrawable>)nextDrawable {
 id<CAMetalDrawable> drawable=[super nextDrawable];
 @synchronized(self){objc_setAssociatedObject(self,@selector(nextDrawable),drawable,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
 return drawable;
}
@end

static CAMetalLayer *WWMetalLayer(CALayer *layer) {
 for(CALayer *child in layer.sublayers){CAMetalLayer *found=WWMetalLayer(child);if(found)return found;}
 if([layer isKindOfClass:CAMetalLayer.class])return (id)layer;
 return nil;
}
static NSError *WWExportError(NSString *message) {return [NSError errorWithDomain:@"WeatherSceneExport" code:1 userInfo:@{NSLocalizedDescriptionKey:message}];}

@interface WWSceneExporter ()
@property(nonatomic) BOOL busy;
@property(nonatomic,strong) UIView *view;
@property(nonatomic,strong) CAGradientLayer *gradient;
@property(nonatomic,strong) CAMetalLayer *metalLayer;
@property(nonatomic,strong) id<MTLCommandQueue> queue;
@property(nonatomic,strong) AVAssetWriter *writer;
@property(nonatomic,strong) AVAssetWriterInput *input;
@property(nonatomic,strong) AVAssetWriterInputPixelBufferAdaptor *adaptor;
@property(nonatomic,strong) NSTimer *timer;
@property(nonatomic,strong) NSURL *directory;
@property(nonatomic,strong) NSDictionary *metadata;
@property(nonatomic,copy) void(^completion)(NSError *);
@property(nonatomic) NSInteger frames,attempts;
@property(nonatomic) CFTimeInterval firstFrameTime;
@property(nonatomic) CGSize outputSize;
@end
@implementation WWSceneExporter
- (void)exportView:(UIView *)view gradient:(CAGradientLayer *)gradient metadata:(NSDictionary *)metadata completion:(void(^)(NSError *))completion {
 NSAssert(NSThread.isMainThread,@"Scene export must start on the main thread");
 if(self.busy){completion(WWExportError(@"Já existe uma cena sendo preparada."));return;}
 self.busy=YES;self.view=view;self.gradient=gradient;self.metadata=metadata;self.completion=completion;self.frames=0;self.attempts=0;self.firstFrameTime=0;
 self.metalLayer=WWMetalLayer(view.layer);
 if(!self.metalLayer || self.metalLayer.class!=CAMetalLayer.class){[self finish:WWExportError(@"O formato da camada Metal mudou.")];return;}
 self.metalLayer.framebufferOnly=NO;object_setClass(self.metalLayer,WWCaptureLayer.class);
 id legacy=[view valueForKey:@"_legacyView"];self.queue=[legacy valueForKey:@"commandQueue"];
 if(!self.queue){[self finish:WWExportError(@"A fila Metal do Tempo não está disponível.")];return;}
 NSString *root=[NSString stringWithFormat:@"/Users/Shared/WeatherWallpaper/%u",getuid()];
 NSError *error=nil;
 // A stable entitlement path works for every user's UID. Scene folders stay private.
 NSString *shared=@"/Users/Shared/WeatherWallpaper";
 BOOL isDirectory=NO;
 if([NSFileManager.defaultManager fileExistsAtPath:shared isDirectory:&isDirectory]){
  if(!isDirectory){[self finish:WWExportError(@"O diretório compartilhado está ocupado por um arquivo.")];return;}
 }else if(![NSFileManager.defaultManager createDirectoryAtPath:shared withIntermediateDirectories:NO attributes:@{NSFilePosixPermissions:@01777} error:&error]){[self finish:error];return;}
 if(![NSFileManager.defaultManager createDirectoryAtPath:root withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:&error]){[self finish:error];return;}
 self.directory=[NSURL fileURLWithPath:[root stringByAppendingPathComponent:NSUUID.UUID.UUIDString] isDirectory:YES];
 if(![NSFileManager.defaultManager createDirectoryAtURL:self.directory withIntermediateDirectories:NO attributes:@{NSFilePosixPermissions:@0700} error:&error]){[self finish:error];return;}
 // Match real drawable pixels, not logical Cocoa points. A Retina display
 // must not upscale a half-resolution recording back onto its physical pixels.
 CGSize pixels=self.metalLayer.drawableSize;
 if(pixels.width<2 || pixels.height<2){CGFloat backing=view.window.screen.scale ?: UIScreen.mainScreen.scale;pixels=CGSizeMake(view.bounds.size.width*backing,view.bounds.size.height*backing);}
 CGFloat scale=MIN(1,5120/MAX(pixels.width,pixels.height));
 self.outputSize=CGSizeMake(floor(pixels.width*scale/2)*2,floor(pixels.height*scale/2)*2);
 if(self.outputSize.width<2 || self.outputSize.height<2){[self finish:WWExportError(@"A cena ainda não tem tamanho válido.")];return;}
 self.writer=[[AVAssetWriter alloc] initWithURL:[self.directory URLByAppendingPathComponent:@"sky.mov"] fileType:AVFileTypeQuickTimeMovie error:&error];
 if(!self.writer){[self finish:error];return;}
 NSDictionary *settings=@{AVVideoCodecKey:AVVideoCodecTypeHEVC,AVVideoWidthKey:@(self.outputSize.width),AVVideoHeightKey:@(self.outputSize.height),AVVideoCompressionPropertiesKey:@{AVVideoAverageBitRateKey:@(MAX(16000000,self.outputSize.width*self.outputSize.height*5)),AVVideoExpectedSourceFrameRateKey:@24,AVVideoMaxKeyFrameIntervalKey:@24},AVVideoColorPropertiesKey:@{AVVideoColorPrimariesKey:AVVideoColorPrimaries_ITU_R_709_2,AVVideoTransferFunctionKey:AVVideoTransferFunction_ITU_R_709_2,AVVideoYCbCrMatrixKey:AVVideoYCbCrMatrix_ITU_R_709_2}};
 self.input=[AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:settings];self.input.expectsMediaDataInRealTime=YES;
 self.adaptor=[AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:self.input sourcePixelBufferAttributes:@{(id)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_32BGRA),(id)kCVPixelBufferWidthKey:@(self.outputSize.width),(id)kCVPixelBufferHeightKey:@(self.outputSize.height),(id)kCVPixelBufferCGImageCompatibilityKey:@YES,(id)kCVPixelBufferCGBitmapContextCompatibilityKey:@YES}];
 if(![self.writer canAddInput:self.input]){[self finish:WWExportError(@"O codificador de vídeo não está disponível.")];return;}
 [self.writer addInput:self.input];
 if(![self.writer startWriting]){[self finish:self.writer.error];return;}
 [self.writer startSessionAtSourceTime:kCMTimeZero];
 __weak typeof(self) weakSelf=self;
 // Let cloud/precipitation emitters populate before recording.
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC),dispatch_get_main_queue(),^{
  if(!weakSelf.busy)return;
  weakSelf.timer=[NSTimer timerWithTimeInterval:1.0/24 repeats:YES block:^(NSTimer *timer){[weakSelf captureFrame];}];
  [NSRunLoop.mainRunLoop addTimer:weakSelf.timer forMode:NSRunLoopCommonModes];
 });
}
- (void)captureFrame {
 @autoreleasepool {
 if(++self.attempts>24*90){[self finish:WWExportError(@"A geração do vídeo excedeu 90 segundos.")];return;}
 if(!self.input.readyForMoreMediaData)return;
 id legacy=[self.view valueForKey:@"_legacyView"];
 [legacy renderWithCompletion:^{}];
 CAMetalLayer *active=WWMetalLayer(self.view.layer);
 if(active && active!=self.metalLayer && active.class==CAMetalLayer.class){
  @synchronized(self.metalLayer){objc_setAssociatedObject(self.metalLayer,@selector(nextDrawable),nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
  if(self.metalLayer.class==WWCaptureLayer.class)object_setClass(self.metalLayer,CAMetalLayer.class);
  self.metalLayer=active;active.framebufferOnly=NO;object_setClass(active,WWCaptureLayer.class);
 }
 id<CAMetalDrawable> drawable;
 @synchronized(self.metalLayer){drawable=objc_getAssociatedObject(self.metalLayer,@selector(nextDrawable));}
 id<MTLTexture> texture=drawable.texture;if(!texture)return;
 if(self.frames==0 && self.attempts==1)NSLog(@"Native export points %.0fx%.0f, drawable %lux%lu, output %.0fx%.0f HEVC",self.view.bounds.size.width,self.view.bounds.size.height,(unsigned long)texture.width,(unsigned long)texture.height,self.outputSize.width,self.outputSize.height);
 NSUInteger row=((texture.width*4+255)/256)*256;
 id<MTLBuffer> buffer=[texture.device newBufferWithLength:row*texture.height options:MTLResourceStorageModeShared];
 id<MTLCommandBuffer> command=[self.queue commandBuffer];id<MTLBlitCommandEncoder> blit=[command blitCommandEncoder];
 [blit copyFromTexture:texture sourceSlice:0 sourceLevel:0 sourceOrigin:MTLOriginMake(0,0,0) sourceSize:MTLSizeMake(texture.width,texture.height,1) toBuffer:buffer destinationOffset:0 destinationBytesPerRow:row destinationBytesPerImage:row*texture.height];
 [blit endEncoding];[command commit];[command waitUntilCompleted];
 if(command.status==MTLCommandBufferStatusError){[self finish:command.error];return;}
 CGColorSpaceRef space=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
 CGContextRef source=CGBitmapContextCreate(buffer.contents,texture.width,texture.height,8,row,space,kCGImageAlphaPremultipliedFirst|kCGBitmapByteOrder32Little);
 CGImageRef image=source ? CGBitmapContextCreateImage(source) : nil;
 if(!image){if(source)CGContextRelease(source);CGColorSpaceRelease(space);[self finish:WWExportError(@"Não foi possível ler o quadro Metal.")];return;}
 UIGraphicsImageRendererFormat *format=[UIGraphicsImageRendererFormat defaultFormat];format.scale=1;format.opaque=YES;format.preferredRange=UIGraphicsImageRendererFormatRangeStandard;
 UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc] initWithSize:self.outputSize format:format];
 UIImage *frame=[renderer imageWithActions:^(UIGraphicsImageRendererContext *context){
  CGContextScaleCTM(context.CGContext,self.outputSize.width/self.view.bounds.size.width,self.outputSize.height/self.view.bounds.size.height);
  [self.gradient renderInContext:context.CGContext];
  if(self.view.layer.mask){
   UIGraphicsImageRendererFormat *mf=[UIGraphicsImageRendererFormat defaultFormat];mf.scale=1;
   UIImage *mask=[[[UIGraphicsImageRenderer alloc] initWithSize:self.view.bounds.size format:mf] imageWithActions:^(UIGraphicsImageRendererContext *mc){[self.view.layer.mask renderInContext:mc.CGContext];}];
   // Quartz masks use image coordinates; UIKit's context has its Y axis flipped.
   CGContextTranslateCTM(context.CGContext,0,self.view.bounds.size.height);CGContextScaleCTM(context.CGContext,1,-1);
   CGContextClipToMask(context.CGContext,self.view.bounds,mask.CGImage);
   CGContextTranslateCTM(context.CGContext,0,self.view.bounds.size.height);CGContextScaleCTM(context.CGContext,1,-1);
  }
  [[UIImage imageWithCGImage:image] drawInRect:self.view.bounds];
  [WWShootingStarForView(self.view) drawCurrentFrameInContext:context.CGContext];
 }];
 CGImageRelease(image);CGContextRelease(source);
 if(self.frames==0 && ![UIImagePNGRepresentation(frame) writeToURL:[self.directory URLByAppendingPathComponent:@"poster.png"] atomically:YES]){CGColorSpaceRelease(space);[self finish:WWExportError(@"Não foi possível salvar a imagem estática.")];return;}
 CVPixelBufferRef pixel=nil;CVReturn result=CVPixelBufferPoolCreatePixelBuffer(nil,self.adaptor.pixelBufferPool,&pixel);
 if(result!=kCVReturnSuccess){CGColorSpaceRelease(space);[self finish:WWExportError(@"Não foi possível alocar o quadro do vídeo.")];return;}
 CVPixelBufferLockBaseAddress(pixel,0);
 CGContextRef target=CGBitmapContextCreate(CVPixelBufferGetBaseAddress(pixel),self.outputSize.width,self.outputSize.height,8,CVPixelBufferGetBytesPerRow(pixel),space,kCGImageAlphaPremultipliedFirst|kCGBitmapByteOrder32Little);
 if(target)CGContextDrawImage(target,CGRectMake(0,0,self.outputSize.width,self.outputSize.height),frame.CGImage);
 if(target)CGContextRelease(target);CGColorSpaceRelease(space);CVPixelBufferUnlockBaseAddress(pixel,0);
 // Preserve animation speed when a Retina frame takes longer than one tick.
 CFTimeInterval capturedAt=CACurrentMediaTime();
 if(self.frames==0)self.firstFrameTime=capturedAt;
 CMTime presentation=CMTimeMakeWithSeconds(capturedAt-self.firstFrameTime,60000);
 BOOL appended=target && [self.adaptor appendPixelBuffer:pixel withPresentationTime:presentation];CVPixelBufferRelease(pixel);
 if(!appended){[self finish:self.writer.error ?: WWExportError(@"O codificador rejeitou um quadro.")];return;}
 ++self.frames;
 if(CMTimeGetSeconds(presentation)<16)return;
 [self.timer invalidate];self.timer=nil;[self.input markAsFinished];[self.writer endSessionAtSourceTime:CMTimeAdd(presentation,CMTimeMake(1,24))];
 [self.writer finishWritingWithCompletionHandler:^{dispatch_async(dispatch_get_main_queue(),^{
  if(self.writer.status!=AVAssetWriterStatusCompleted){[self finish:self.writer.error ?: WWExportError(@"O vídeo não foi finalizado.")];return;}
  NSMutableDictionary *manifest=[self.metadata mutableCopy];manifest[@"version"]=@1;manifest[@"generation"]=self.directory.lastPathComponent;manifest[@"pixelWidth"]=@(self.outputSize.width);manifest[@"pixelHeight"]=@(self.outputSize.height);manifest[@"codec"]=@"hevc";manifest[@"publishedAt"]=@(NSDate.date.timeIntervalSince1970);
  NSURL *url=[[self.directory URLByDeletingLastPathComponent] URLByAppendingPathComponent:@"current.json"];
  NSError *error=nil;NSData *data=[NSJSONSerialization dataWithJSONObject:manifest options:0 error:&error];
  if(data && ![data writeToURL:url options:NSDataWritingAtomic error:&error])data=nil;
  if(data){NSLog(@"Published native weather scene %@ (%ld frames)",manifest[@"generation"],(long)self.frames);[self cleanOldScenes];}
  [self finish:error];
 });}];
 }
}
- (void)cleanOldScenes {
 // Keep a full hour so existing lock/saver instances can finish their old loop.
 NSURL *root=[self.directory URLByDeletingLastPathComponent];
 for(NSURL *url in [NSFileManager.defaultManager contentsOfDirectoryAtURL:root includingPropertiesForKeys:@[NSURLCreationDateKey] options:NSDirectoryEnumerationSkipsHiddenFiles error:nil]){
  if([url isEqual:self.directory] || ![[NSUUID alloc] initWithUUIDString:url.lastPathComponent])continue;
  NSDate *created=nil;[url getResourceValue:&created forKey:NSURLCreationDateKey error:nil];
  if(created && -created.timeIntervalSinceNow>3600)[NSFileManager.defaultManager removeItemAtURL:url error:nil];
 }
}
- (void)finish:(NSError *)error {
 [self.timer invalidate];self.timer=nil;
 if(error){[self.writer cancelWriting];if(self.directory)[NSFileManager.defaultManager removeItemAtURL:self.directory error:nil];}
 @synchronized(self.metalLayer){objc_setAssociatedObject(self.metalLayer,@selector(nextDrawable),nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
 if(self.metalLayer.class==WWCaptureLayer.class)object_setClass(self.metalLayer,CAMetalLayer.class);
 void(^completion)(NSError *)=self.completion;self.completion=nil;self.busy=NO;
 self.writer=nil;self.input=nil;self.adaptor=nil;self.view=nil;self.gradient=nil;self.metalLayer=nil;self.queue=nil;self.directory=nil;
 if(completion)completion(error);
}
@end
