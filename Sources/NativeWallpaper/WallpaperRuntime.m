#import "WallpaperPrivate.h"
#import <IOSurface/IOSurface.h>

id WWRemoteContext(unsigned int identifier) {
 Class cls=NSClassFromString(@"WallpaperRemoteContextXPC");
 Ivar ivar=cls ? class_getInstanceVariable(cls,"box") : NULL;
 if(!ivar || class_getInstanceSize(cls)<ivar_getOffset(ivar)+sizeof(identifier))return nil;
 id object=class_createInstance(cls,0);
 memcpy((char *)(__bridge void *)object+ivar_getOffset(ivar),&identifier,sizeof(identifier));
 return object;
}

// WallpaperSnapshotXPC requires NSXPCCoder's exact class on this OS. Preserve the
// real coder class even if a private framework raises. Adapted from Aerial (MIT).
void WWPrepareSnapshotEncoding(void) {
 static dispatch_once_t once;
 dispatch_once(&once,^{
  Class cls=NSClassFromString(@"WallpaperSnapshotXPC"),coderClass=NSClassFromString(@"NSXPCCoder");
  Method method=cls ? class_getInstanceMethod(cls,@selector(encodeWithCoder:)) : NULL;
  if(!method || !coderClass)return;
  IMP original=method_getImplementation(method);
  IMP replacement=imp_implementationWithBlock(^(id object,NSCoder *coder){
   Class actual=object_getClass(coder);
   @try {object_setClass(coder,coderClass);((void(*)(id,SEL,id))original)(object,@selector(encodeWithCoder:),coder);}
   @finally {object_setClass(coder,actual);}
  });
  method_setImplementation(method,replacement);
 });
}

id WWCreateSnapshot(CGImageRef image) {
 if(!image)return nil;
 Class cls=NSClassFromString(@"WallpaperSnapshotXPC");
 Ivar ivar=cls ? class_getInstanceVariable(cls,"rawValue") : NULL;
 if(!ivar || class_getInstanceSize(cls)<ivar_getOffset(ivar)+sizeof(void *))return nil;
 size_t width=CGImageGetWidth(image),height=CGImageGetHeight(image);
 IOSurfaceRef surface=IOSurfaceCreate((__bridge CFDictionaryRef)@{(id)kIOSurfaceWidth:@(width),(id)kIOSurfaceHeight:@(height),(id)kIOSurfaceBytesPerElement:@4,(id)kIOSurfaceBytesPerRow:@(width*4),(id)kIOSurfacePixelFormat:@(0x42475241)});
 if(!surface)return nil;
 IOSurfaceLock(surface,0,NULL);
 CGColorSpaceRef space=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
 CGContextRef context=CGBitmapContextCreate(IOSurfaceGetBaseAddress(surface),width,height,8,IOSurfaceGetBytesPerRow(surface),space,kCGBitmapByteOrder32Little|kCGImageAlphaPremultipliedFirst);
 if(context)CGContextDrawImage(context,CGRectMake(0,0,width,height),image);
 if(context)CGContextRelease(context);CGColorSpaceRelease(space);IOSurfaceUnlock(surface,0,NULL);
 if(!context){CFRelease(surface);return nil;}
 id object=class_createInstance(cls,0);
 // Transfer the +1 IOSurface reference into the Swift struct's strong field.
 memcpy((char *)(__bridge void *)object+ivar_getOffset(ivar),&surface,sizeof(surface));
 return object;
}
