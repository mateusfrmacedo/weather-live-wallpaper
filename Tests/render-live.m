// Run the real Catalyst view while weather updates race with VFX's simulation.
#define main WeatherApplicationMain
#import "../Sources/main.m"
#undef main

@interface NSObject (NativeSettingsTestAPI)
- (void)selectItem:(id)item;
- (void)weatherChanged:(id)sender;
- (void)dockChanged:(id)sender;
- (void)close;
@end

@interface RenderTestController : WeatherController
@property(nonatomic) NSInteger testUpdates;
@property(nonatomic,strong) NSTimer *testTimer;
@property(nonatomic,strong) id firstSettingsWindow;
@end
@implementation RenderTestController
- (void)viewDidAppear:(BOOL)animated {
 [super viewDidAppear:animated];
 if(!self.ready || !self.weatherView){NSLog(@"FAIL: renderer initialization: %@",self.statusLabel.text);exit(1);}
 if(self.testTimer)return;
 __weak typeof(self) weakSelf=self;
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC),dispatch_get_main_queue(),^{
  weakSelf.testTimer=[NSTimer scheduledTimerWithTimeInterval:0.08 repeats:YES block:^(NSTimer *timer){[weakSelf testUpdate];}];
 });
}
- (void)testUpdate {
 NSArray *conditions=@[@"clear",@"mostlyClear",@"partlyCloudy",@"mostlyCloudy",@"cloudy",@"rain",@"heavyRain",@"thunderstorms",@"snow",@"foggy"];
 NSInteger index=self.testUpdates++;
 if(index==0){
  for(NSValue *value in @[[NSValue valueWithCGSize:CGSizeMake(1512,982)],[NSValue valueWithCGSize:CGSizeMake(5120,1440)]]){
   CGSize size=value.CGSizeValue;WWShootingStarLayer *meteor=[WWShootingStarLayer layerForSize:size];
   CALayer *sprite=meteor.sublayers.firstObject;
   CAAnimationGroup *group=(id)[sprite animationForKey:@"meteor"];
   CAKeyframeAnimation *position=(id)group.animations.firstObject;
   double life=([position.keyTimes[2] doubleValue]-[position.keyTimes[1] doubleValue])*group.duration;
   if(!meteor.texture.CGImage || meteor.sublayers.count!=16 || life<0.48 || life>0.52){NSLog(@"FAIL: native meteor lifetime or texture");exit(1);}
   [meteor setPlaybackPaused:YES];if(!meteor.playbackPaused){NSLog(@"FAIL: shooting star pause");exit(1);}[meteor setPlaybackPaused:NO];
  }
 }
 if(index%40==10){
  [self useWallpaper];id scene=self.scene,view=self.weatherView;
  id desktop=[self.desktopBridge valueForKey:@"window"];
  NSValue *frame=[desktop valueForKey:@"frame"];NSNumber *level=[desktop valueForKey:@"level"];
  [self showPreferences];id settings=[self.desktopBridge valueForKey:@"settingsWindow"];
  if(!self.wallpaper || ![[self.desktopBridge valueForKey:@"wallpaper"] boolValue] || settings==desktop || ![[settings valueForKey:@"visible"] boolValue] || self.scene!=scene || self.weatherView!=view || ![frame isEqual:[desktop valueForKey:@"frame"]] || ![level isEqual:[desktop valueForKey:@"level"]]){NSLog(@"FAIL: preferences moved or replaced the wallpaper");exit(1);}
  if(self.firstSettingsWindow && self.firstSettingsWindow!=settings){NSLog(@"FAIL: duplicate settings window");exit(1);}
  self.firstSettingsWindow=settings;
  id weather=[self.desktopBridge valueForKey:@"weatherControl"];
  for(NSString *condition in @[@"clear",@"rain",@"snow",@"thunderstorms",@"freezingRain",@"freezingDrizzle",@"windy"]){
   for(id item in [weather valueForKey:@"itemArray"])if([[item valueForKey:@"representedObject"] isEqual:condition]){[weather selectItem:item];break;}
   [self.desktopBridge weatherChanged:weather];
   if(self.live || self.automaticWeather || ![self.condition isEqual:condition] || !self.wallpaper){NSLog(@"FAIL: manual weather selection %@",condition);exit(1);}
  }
  [self setPreviewTime:2];if(self.timeControl.selectedSegmentIndex!=2){NSLog(@"FAIL: manual time selection");exit(1);}
  id dock=[self.desktopBridge valueForKey:@"dockControl"];
  for(NSNumber *visible in @[@YES,@NO]){
   [dock setValue:visible forKey:@"state"];[self.desktopBridge dockChanged:dock];
   if([[self.desktopBridge valueForKey:@"dockVisible"] boolValue]!=visible.boolValue || ![frame isEqual:[desktop valueForKey:@"frame"]] || ![level isEqual:[desktop valueForKey:@"level"]]){NSLog(@"FAIL: Dock visibility changed wallpaper");exit(1);}
  }
  [settings close];
  if(!self.wallpaper || ![[self.desktopBridge valueForKey:@"wallpaper"] boolValue]){NSLog(@"FAIL: closing preferences stopped the wallpaper");exit(1);}
 }
 if(index%40==20)[self showPreview];
 self.live=YES;self.condition=conditions[(index/5)%conditions.count];
 self.location=@{@"name":@"Render test",@"latitude":@(-20.18222),@"longitude":@(-49.35139)};
 self.liveWeather=@{@"condition":self.condition,@"elevation":@((index%3)==0 ? 35 : (index%3)==1 ? 1 : -25),@"cloudCover":@0.45,@"wind":@12,@"isPM":@(index%2),@"timeZone":@"America/Sao_Paulo",@"date":@(1792360800+(index%24)*3600)};
 if(index%20==0)self.view.bounds=CGRectMake(0,0,index%40 ? 1200 : 900,index%40 ? 700 : 850);
 [self applyWeather];
 if([@[@"clear",@"mostlyClear"] containsObject:self.condition] && [self.liveWeather[@"elevation"] doubleValue]<-10){
  CAGradientLayer *fade=self.nightSkyMask;
  if(!fade || self.weatherView.layer.mask!=fade || !CGRectEqualToRect(fade.frame,self.weatherView.bounds) || CGColorGetAlpha((__bridge CGColorRef)fade.colors.firstObject)<0.99 || CGColorGetAlpha((__bridge CGColorRef)fade.colors.lastObject)<=0 || CGColorGetAlpha((__bridge CGColorRef)fade.colors.lastObject)>0.2){NSLog(@"FAIL: night horizon fade or corner coverage");exit(1);}
 }else if([self.condition isEqual:@"rain"] && self.nightSkyMask){NSLog(@"FAIL: night fade affected precipitation");exit(1);}
 if(self.view.layer.sublayers.firstObject!=self.skyGradient){NSLog(@"FAIL: gradient covers the renderer");exit(1);}
 if(index%50==0){[self togglePause];[self togglePause];NSLog(@"Live render updates: %ld",(long)index);}
 if(self.testUpdates>=200){
  [self.testTimer invalidate];self.condition=@"rain";NSMutableDictionary *weather=[self.liveWeather mutableCopy];weather[@"elevation"]=@35;weather[@"cloudCover"]=@0.95;self.liveWeather=weather;[self applyWeather];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,3*NSEC_PER_SEC),dispatch_get_main_queue(),^{
   NSInteger particles=[self.scene particleCount];NSLog(@"Live renderer playing=%d particles=%ld",[self.scene isPlaying],(long)particles);
   if(![self.scene isPlaying] || particles<=0){NSLog(@"FAIL: renderer stopped producing particles");exit(1);}
   NSLog(@"PASS: 200 updates with active Metal rendering, lunar data, resizing, pause/resume, desktop mode and independent settings.");exit(0);
  });
 }
}
@end
@interface RenderTestSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation RenderTestSceneDelegate
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
 self.window=[[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];self.window.rootViewController=[RenderTestController new];[self.window makeKeyAndVisible];
}
@end
@interface RenderTestDelegate : UIResponder <UIApplicationDelegate>
@end
@implementation RenderTestDelegate
- (UISceneConfiguration *)application:(UIApplication *)app configurationForConnectingSceneSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
 UISceneConfiguration *c=[[UISceneConfiguration alloc] initWithName:@"Render test" sessionRole:session.role];c.delegateClass=RenderTestSceneDelegate.class;return c;
}
@end
int main(int argc,char **argv){@autoreleasepool{dispatch_after(dispatch_time(DISPATCH_TIME_NOW,90*NSEC_PER_SEC),dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{NSLog(@"FAIL: live renderer timed out");exit(1);});return UIApplicationMain(argc,argv,nil,NSStringFromClass(RenderTestDelegate.class));}}
