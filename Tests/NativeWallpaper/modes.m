#define WW_NATIVE_NO_MAIN 1
#import "../../Sources/NativeWallpaper/PrototypeHost.m"
// Keep playback tests isolated from the user's published wallpaper movie.
@interface ModeTestExporter : WWSceneExporter @end
@implementation ModeTestExporter
- (void)exportView:(UIView *)view gradient:(CAGradientLayer *)gradient metadata:(NSDictionary *)metadata completion:(void(^)(NSError *))completion {completion(nil);}
@end
static void require(BOOL result,NSString *message){if(!result){NSLog(@"FAIL: %@",message);exit(1);}}
@interface ModeTestController : NativeWeatherController @end
@implementation ModeTestController
- (void)viewDidLoad {[super viewDidLoad];self.exporter=[ModeTestExporter new];}
- (void)viewDidAppear:(BOOL)animated {
 [super viewDidAppear:animated];
 [self setContinuousWallpaperEnabled:YES];[self setContinuousWallpaperEnabled:NO];[self setContinuousWallpaperEnabled:YES];
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,4*NSEC_PER_SEC),dispatch_get_main_queue(),^{
  require(!self.preparingExport,@"export preparation finished");
  for(NSNumber *choice in @[@YES,@NO,@YES,@NO]){
   BOOL continuous=choice.boolValue;[self setContinuousWallpaperEnabled:continuous];
   require(self.continuousWallpaperEnabled==continuous && [NSUserDefaults.standardUserDefaults boolForKey:@"ContinuousDesktopEnabled"]==continuous,@"mode persisted");
   require(self.wallpaper==continuous && [[self.desktopBridge valueForKey:@"wallpaper"] boolValue]==continuous,@"desktop window mode");
   require(self.paused!=continuous && [self.scene isPlaying]==continuous,@"renderer starts and stops");
   require([[[self.desktopBridge valueForKey:@"qualityCard"] valueForKey:@"hidden"] boolValue]!=continuous,@"quality visibility");
   if(continuous){
    self.publishedScene=[self sceneMetadata];self.publishedDate=NSDate.date;
    UIView *runningView=self.weatherView;id runningScene=self.scene;
    WWShootingStarLayer *runningMeteor=WWShootingStarForView(runningView);
    [self applyWeather];[self applyWeather];
    require(self.weatherView==runningView && self.scene==runningScene && WWShootingStarForView(self.weatherView)==runningMeteor,@"unchanged weather refresh preserves the running simulation and meteor clock");
    [self togglePause];require(![self.scene isPlaying],@"pause animation");[self togglePause];require([self.scene isPlaying],@"resume animation");}
   else require(![[[self.desktopBridge valueForKey:@"window"] valueForKey:@"visible"] boolValue],@"economic render window hidden");
  }
  require([[[self.desktopBridge valueForKey:@"settingsWindow"] valueForKey:@"visible"] boolValue],@"settings remain visible");
  NSLog(@"PASS: mode changes during preparation, persisted selection, live renderer, pause/resume and static desktop");exit(0);
 });
}
@end
@interface ModeTestScene : NativeWeatherSceneDelegate @end
@implementation ModeTestScene
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {self.window=[[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];self.window.rootViewController=[ModeTestController new];[self.window makeKeyAndVisible];}
@end
@interface ModeTestDelegate : NativeWeatherDelegate @end
@implementation ModeTestDelegate
- (UISceneConfiguration *)application:(UIApplication *)app configurationForConnectingSceneSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {UISceneConfiguration *c=[[UISceneConfiguration alloc] initWithName:@"Modes" sessionRole:session.role];c.delegateClass=ModeTestScene.class;return c;}
@end
int main(int argc,char **argv){@autoreleasepool{dispatch_after(dispatch_time(DISPATCH_TIME_NOW,30*NSEC_PER_SEC),dispatch_get_main_queue(),^{NSLog(@"FAIL: mode test timeout");exit(1);});return UIApplicationMain(argc,argv,nil,NSStringFromClass(ModeTestDelegate.class));}}
