#import <Foundation/Foundation.h>
#import <simd/simd.h>
#import <objc/runtime.h>
@interface NSObject (WWSkyScene)
- (long long)lookupObjectIDByName:(NSString *)name;
- (id)opaqueEntityManager;
- (void)beginTransaction;
- (void)endTransaction;
@end
@interface WWSkyEntity : NSObject
- (id)init:(long long)identifier sharedEntityManager:(id)manager;
- (id)properties;
@end
@interface WWSkyProperties : NSObject
- (void)setScale:(simd_float3)value;
- (simd_float3)scale;
- (void)setIsEnabled:(BOOL)value;
@end
static void WWFitSkyToDisplay(NSObject *scene,NSObject *effect,CGSize size,BOOL replaceMeteor) {
 if(![effect respondsToSelector:@selector(lookupObjectIDByName:)] || ![scene respondsToSelector:@selector(opaqueEntityManager)])return;
 NSMutableArray *owners=[NSMutableArray new];[scene beginTransaction];
 for(NSString *name in replaceMeteor ? @[@"Star",@"ShootingStar"] : @[@"Star"]){
  long long identifier=[effect lookupObjectIDByName:name];if((uint32_t)identifier==UINT32_MAX)continue;
  WWSkyEntity *entity=[(WWSkyEntity *)[NSClassFromString(@"VFX.VFXEntityObject") alloc] init:identifier sharedEntityManager:[scene opaqueEntityManager]];WWSkyProperties *properties=[entity properties];if(!properties)continue;
  [owners addObject:entity];
  if([name isEqual:@"Star"]){
   // The native star graph tests lunar occlusion in emitter-local coordinates.
   // Scaling the emitter moves those masked particles away from the Moon and
   // lets other stars shine through its disc. Expand only the spawn cylinder.
   // This is the verified layout of WeatherV136; fail closed on another layout.
   if((uint32_t)identifier==438){
    long long shapeID=(identifier & ~0xffffffffLL) | 72;
    WWSkyEntity *shape=[(WWSkyEntity *)[NSClassFromString(@"VFX.VFXEntityObject") alloc] init:shapeID sharedEntityManager:[scene opaqueEntityManager]];
    WWSkyProperties *spawn=[shape properties];simd_float3 original=[spawn scale];
    if(fabsf(original.x-800)<0.01 && fabsf(original.y-2)<0.01 && fabsf(original.z-800)<0.01){
     CGFloat aspect=MAX(1,size.width/MAX(1,size.height));
     [spawn setScale:(simd_float3){800*1.55*MAX(1,aspect/1.6),2,800*1.55}];[owners addObject:shape];
    }
   }
  }
  else [properties setIsEnabled:NO];
 }
 [scene endTransaction];static char ownershipKey;objc_setAssociatedObject(scene,&ownershipKey,owners,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
