#import <AppKit/AppKit.h>
int main(int argc, char **argv) {
 @autoreleasepool {
  if (argc != 3) return 1;
  NSImage *source=[[NSImage alloc] initWithContentsOfFile:[NSString stringWithUTF8String:argv[1]]];
  if(!source)return 2;
  NSString *directory=[NSString stringWithUTF8String:argv[2]];
  [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
  for(NSNumber *dimension in @[@16,@32,@128,@256,@512])for(int scale=1;scale<=2;scale++) {
   NSInteger size=dimension.integerValue*scale;
   NSBitmapImageRep *bitmap=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:size pixelsHigh:size bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
   [NSGraphicsContext saveGraphicsState];
   [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap]];
   NSAffineTransform *flip=[NSAffineTransform transform];[flip translateXBy:size yBy:0];[flip scaleXBy:-1 yBy:1];[flip concat];
   [source drawInRect:NSMakeRect(0,0,size,size) fromRect:NSZeroRect operation:NSCompositingOperationCopy fraction:1 respectFlipped:NO hints:@{NSImageHintInterpolation:@(NSImageInterpolationHigh)}];
   [NSGraphicsContext restoreGraphicsState];
   NSString *name=[NSString stringWithFormat:@"icon_%@x%@%@.png",dimension,dimension,scale==2 ? @"@2x" : @""];
   [[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:[directory stringByAppendingPathComponent:name] atomically:YES];
  }
 }
}
