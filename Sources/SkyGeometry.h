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
- (void)setIsEnabled:(BOOL)value;
@end
static void WWFitSkyToDisplay(NSObject *scene,NSObject *effect,CGSize size,BOOL replaceMeteor) {
 if(![effect respondsToSelector:@selector(lookupObjectIDByName:)] || ![scene respondsToSelector:@selector(opaqueEntityManager)])return;
 NSMutableArray *owners=[NSMutableArray new];[scene beginTransaction];
 for(NSString *name in replaceMeteor ? @[@"Star",@"ShootingStar"] : @[@"Star"]){
  long long identifier=[effect lookupObjectIDByName:name];if((uint32_t)identifier==UINT32_MAX)continue;
  WWSkyEntity *entity=[(WWSkyEntity *)[NSClassFromString(@"VFX.VFXEntityObject") alloc] init:identifier sharedEntityManager:[scene opaqueEntityManager]];WWSkyProperties *properties=[entity properties];if(!properties)continue;
  [owners addObject:entity];
  if([name isEqual:@"Star"]){CGFloat aspect=MAX(1,size.width/MAX(1,size.height));[properties setScale:(simd_float3){MAX(1,aspect/1.6),1,1}];}
  else [properties setIsEnabled:NO];
 }
 [scene endTransaction];static char ownershipKey;objc_setAssociatedObject(scene,&ownershipKey,owners,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
