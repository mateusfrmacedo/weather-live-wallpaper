#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>
#import <CoreGraphics/CoreGraphics.h>
#include <math.h>

// Derive a private cache from the installed system assets. Squaring lunar alpha
// removes the broad translucent halo while keeping opaque crater pixels intact.
// No Apple assets are bundled with the app or changed in the system directory.
static NSURL *WWSubtleMoonScene(NSURL *original) {
 static NSURL *result;static dispatch_once_t once;
 dispatch_once(&once,^{
  result=original;NSFileManager *fm=NSFileManager.defaultManager;
  NSDate *modified=nil;[[original URLByAppendingPathComponent:@"scene.vfxbin"] getResourceValue:&modified forKey:NSURLContentModificationDateKey error:nil];
  NSURL *cache=[[fm URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask].firstObject URLByAppendingPathComponent:@"WeatherWallpaper" isDirectory:YES];
  NSString *version=[NSString stringWithFormat:@"MoonAlpha2-%@-%.0f",NSProcessInfo.processInfo.operatingSystemVersionString,modified.timeIntervalSince1970];
  NSURL *parent=[cache URLByAppendingPathComponent:version isDirectory:YES];
  NSURL *ready=[parent URLByAppendingPathComponent:original.lastPathComponent isDirectory:YES];
  if([fm fileExistsAtPath:ready.path]){result=ready;return;}
  NSError *error=nil;
  if(![fm createDirectoryAtURL:parent withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:&error])return;
  NSURL *staging=[parent URLByAppendingPathComponent:NSUUID.UUID.UUIDString isDirectory:YES];
  if(![fm copyItemAtURL:original toURL:staging error:&error])return;
  NSURL *assets=[staging URLByAppendingPathComponent:@"assets" isDirectory:YES];
  NSInteger phases=0;BOOL valid=YES;
  for(NSURL *url in [fm contentsOfDirectoryAtURL:assets includingPropertiesForKeys:nil options:0 error:&error]){
   if(![url.lastPathComponent hasPrefix:@"moonPhase"] || ![url.pathExtension isEqual:@"png"])continue;
   CGImageSourceRef source=CGImageSourceCreateWithURL((__bridge CFURLRef)url,NULL);
   CGImageRef image=source ? CGImageSourceCreateImageAtIndex(source,0,NULL) : NULL;
   if(source)CFRelease(source);
   if(!image){valid=NO;break;}
   size_t w=CGImageGetWidth(image),h=CGImageGetHeight(image);
   CGColorSpaceRef space=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
   CGContextRef context=CGBitmapContextCreate(NULL,w,h,8,w*4,space,kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);
   CGColorSpaceRelease(space);
   if(!context){CGImageRelease(image);valid=NO;break;}
   CGContextDrawImage(context,CGRectMake(0,0,w,h),image);CGImageRelease(image);
   uint8_t *pixels=CGBitmapContextGetData(context);
   for(size_t p=0;p<w*h;p++){
    uint8_t *v=pixels+p*4;float alpha=v[3]/255.f;
    // RGB is premultiplied: scale all four channels to preserve its color.
    for(int c=0;c<4;c++)v[c]=(uint8_t)lroundf(v[c]*alpha);
   }
   image=CGBitmapContextCreateImage(context);CGContextRelease(context);
   CGImageDestinationRef destination=CGImageDestinationCreateWithURL((__bridge CFURLRef)url,CFSTR("public.png"),1,NULL);
   if(destination){CGImageDestinationAddImage(destination,image,NULL);valid=CGImageDestinationFinalize(destination);CFRelease(destination);}else valid=NO;
   CGImageRelease(image);
   if(!valid)break;
   phases++;
  }
  if(valid && phases>0 && [fm moveItemAtURL:staging toURL:ready error:&error])result=ready;
  else {if([fm fileExistsAtPath:ready.path])result=ready;[fm removeItemAtURL:staging error:nil];NSLog(@"Moon texture cache: %@",error ?: @"Could not prepare lunar phases");}
 });
 return result;
}
