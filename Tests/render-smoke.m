#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <QuartzCore/QuartzCore.h>
#import <dlfcn.h>
@interface NSObject (WeatherSmoke)
+ (BOOL)isSupported;
+ (NSDictionary *)applyEffect:(id)effect condition:(NSString *)condition elevation:(double)elevation cloudCover:(double)cover wind:(double)wind size:(CGSize)size isPM:(BOOL)isPM timeZone:(NSString *)timeZone;
+ (NSDictionary *)applyEffect:(id)effect condition:(NSString *)condition elevation:(double)elevation cloudCover:(double)cover wind:(double)wind size:(CGSize)size isPM:(BOOL)isPM timeZone:(NSString *)timeZone details:(NSDictionary *)details;
- (id)initWithContentsOf:(NSURL *)url options:(id)options error:(NSError **)error;
- (id)addEffectWithEffectID:(int)identifier;
- (id)parameterOf:(NSString *)object named:(NSString *)name;
@end
int main(void) {@autoreleasepool {
 if(!dlopen("/System/iOSSupport/System/Library/PrivateFrameworks/WeatherUI.framework/WeatherUI",RTLD_NOW))return 1;
 if(![NSClassFromString(@"WeatherRuntime") isSupported])return 2;
 NSString *root=@"/System/iOSSupport/System/Library/PrivateFrameworks/WeatherUI.framework/Resources";
 id options=[NSClassFromString(@"VFXSceneLoadOptions") new];
 [options setValue:@YES forKey:@"loadBindingsMetadata"];
 [options setValue:[NSURL fileURLWithPath:[root stringByAppendingPathComponent:@"default.metallib"]] forKey:@"metalLibraryURL"];
 NSError *error=nil;
 id scene=[[NSClassFromString(@"VFX.VFXScene") alloc] initWithContentsOf:[NSURL fileURLWithPath:[root stringByAppendingPathComponent:@"VFX/WeatherV136_Default_Background.vfx"]] options:options error:&error];
 if(!scene){NSLog(@"%@",error);return 3;}
 id effect=[scene addEffectWithEffectID:0];
 int count=0;
 // Repeated, pooled updates catch ownership mistakes across the Swift/ObjC boundary.
 for(int pass=0;pass<3;pass++)for(NSString *condition in @[@"clear",@"mostlyClear",@"partlyCloudy",@"cloudy",@"drizzle",@"rain",@"heavyRain",@"thunderstorms",@"snow",@"heavySnow",@"foggy",@"hail",@"windy",@"freezingRain",@"freezingDrizzle"])for(NSNumber *elevation in @[@35,@1,@(-25)]) {@autoreleasepool {
  NSDictionary *result=[NSClassFromString(@"WeatherRuntime") applyEffect:effect condition:condition elevation:elevation.doubleValue cloudCover:[condition isEqual:@"clear"] ? 0 : 0.8 wind:12 size:CGSizeMake(1920,1080) isPM:YES timeZone:@"America/Sao_Paulo"];
  if(result[@"error"] || ![effect parameterOf:@"MAIN" named:@"gradientTop"]){NSLog(@"FAILED %@ %@ %@",condition,elevation,result);return 4;}
  CAGradientLayer *gradient=result[@"gradientLayer"];
  if(gradient.colors.count!=3 || gradient.locations.count!=3){NSLog(@"FAILED gradient stops %@ %@",condition,elevation);return 6;}
  for(id color in gradient.colors){CGColorRef c=(__bridge CGColorRef)color;const CGFloat *v=CGColorGetComponents(c);for(size_t k=0;k<CGColorGetNumberOfComponents(c);k++)if(!isfinite(v[k]))return 7;}
  count++;
 }}
 for(NSString *altitude in @[@"low",@"mid",@"high"]) {@autoreleasepool {
  NSDictionary *details=@{@"cloudLow":[altitude isEqual:@"low"] ? @0.7 : @0.1,@"cloudMid":[altitude isEqual:@"mid"] ? @0.7 : @0.1,@"cloudHigh":[altitude isEqual:@"high"] ? @0.7 : @0.1,@"sunrise":@1792313082,@"sunset":@1792358454,@"isDaylight":@NO};
  NSDictionary *result=[NSClassFromString(@"WeatherRuntime") applyEffect:effect condition:@"partlyCloudy" elevation:-2 cloudCover:0.7 wind:9 size:CGSizeMake(1000,1100) isPM:YES timeZone:@"America/Sao_Paulo" details:details];
  if(result[@"error"] || ![result[@"cloudKind"] isEqual:altitude]){NSLog(@"FAILED cloud altitude %@ %@",altitude,result);return 5;}
  count++;
 }}
 // Identical automatic refreshes must not multiply the star reduction again.
 NSDictionary *baseline=nil;
 for(int update=0;update<3;update++) {@autoreleasepool {
  NSDictionary *result=[NSClassFromString(@"WeatherRuntime") applyEffect:effect condition:@"clear" elevation:-25 cloudCover:0 wind:12 size:CGSizeMake(1512,982) isPM:YES timeZone:@"America/Sao_Paulo"];
  if(result[@"error"] || !result[@"starCount"] || !result[@"starOpacity"])return 8;
  if(baseline)for(NSString *key in @[@"starCount",@"brightStarCount",@"starOpacity"])if(![baseline[key] isEqual:result[key]]){NSLog(@"FAILED repeated star update %@",key);return 9;}
  baseline=result;count++;
 }}
 NSDictionary *moon=[NSClassFromString(@"WeatherRuntime") applyEffect:effect condition:@"clear" elevation:-12 cloudCover:0 wind:8 size:CGSizeMake(1512,982) isPM:YES timeZone:@"America/Sao_Paulo" details:@{@"latitude":@(-20.18222),@"longitude":@(-49.35139),@"date":@1792360800}];
 NSLog(@"Celestial moon=%@ image=%@ sun=%@",moon[@"moonData"],moon[@"moonImage"],moon[@"sunPosition"]);
 if(moon[@"error"] || [moon[@"moonData"] isEqual:@"nil"] || [moon[@"moonData"] isEqual:@"unavailable"])return 10;
 count++;
 NSDictionary *sun=[NSClassFromString(@"WeatherRuntime") applyEffect:effect condition:@"clear" elevation:35 cloudCover:0 wind:8 size:CGSizeMake(1512,982) isPM:YES timeZone:@"America/Sao_Paulo"];
 if(sun[@"error"] || [sun[@"sunAlpha"] floatValue]<=0 || !sun[@"sunPosition"])return 11;
 count++;
 printf("PASS: %d original WeatherUI configurations, including low/mid/high clouds and sunset inputs.\n",count);
 return 0;
}}
