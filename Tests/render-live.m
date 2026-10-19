// Run the real Catalyst view while weather updates race with VFX's simulation.
#define main WeatherApplicationMain
#import "../Sources/main.m"
#undef main

@interface RenderTestController : WeatherController
@property(nonatomic) NSInteger testUpdates;
@property(nonatomic,strong) NSTimer *testTimer;
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
 if(index%40==10)[self useWallpaper];
 if(index%40==20)[self showPreview];
 self.live=YES;self.condition=conditions[(index/5)%conditions.count];
 self.location=@{@"name":@"Render test",@"latitude":@(-20.18222),@"longitude":@(-49.35139)};
 self.liveWeather=@{@"condition":self.condition,@"elevation":@((index%3)==0 ? 35 : (index%3)==1 ? 1 : -25),@"cloudCover":@0.45,@"wind":@12,@"isPM":@(index%2),@"timeZone":@"America/Sao_Paulo",@"date":@(1792360800+(index%24)*3600)};
 if(index%20==0)self.view.bounds=CGRectMake(0,0,index%40 ? 1200 : 900,index%40 ? 700 : 850);
 [self applyWeather];
 if(index%50==0){[self togglePause];[self togglePause];NSLog(@"Live render updates: %ld",(long)index);}
 if(self.testUpdates>=200){
  [self.testTimer invalidate];self.condition=@"rain";NSMutableDictionary *weather=[self.liveWeather mutableCopy];weather[@"elevation"]=@35;weather[@"cloudCover"]=@0.95;self.liveWeather=weather;[self applyWeather];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,3*NSEC_PER_SEC),dispatch_get_main_queue(),^{
   NSInteger particles=[self.scene particleCount];NSLog(@"Live renderer playing=%d particles=%ld",[self.scene isPlaying],(long)particles);
   if(![self.scene isPlaying] || particles<=0){NSLog(@"FAIL: renderer stopped producing particles");exit(1);}
   NSLog(@"PASS: 200 updates with active Metal rendering, lunar data, resizing, pause/resume and desktop mode.");exit(0);
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
