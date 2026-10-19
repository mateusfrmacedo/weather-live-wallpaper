// A separate application/identity: the existing live-wallpaper app is unchanged.
#define main OriginalWeatherApplicationMain
#import "../main.m"
#undef main
#import "SceneExporter.h"
#import "UpdatePolicy.h"

@interface NSObject (NativePrototypeBridge)
- (void)openNativeWallpaperSettings;
- (void)hideNativeRenderWindow;
- (void)setLiveDesktopEnabled:(BOOL)enabled;
@end

@interface NativeWeatherController : WeatherController
@property(nonatomic,strong) WWSceneExporter *exporter;
@property(nonatomic,strong) NSDictionary *publishedScene;
@property(nonatomic,strong) NSDate *publishedDate;
@property(nonatomic) BOOL exportPending,appeared,preparingExport,userPaused;
@end
@implementation NativeWeatherController
- (void)viewDidLoad {
 // Seed settings once; subsequent edits belong only to this prototype.
 NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;
 if(![defaults boolForKey:@"NativePrototypeSeeded"]){
  NSDictionary *original=[defaults persistentDomainForName:@"local.mateus.WeatherWallpaper"];
  for(NSString *key in @[@"SelectedLocation",@"LastWeatherCache",@"AutomaticWeatherEnabled",@"ManualWeatherCondition",@"ManualWeatherTime"])
   if(original[key])[defaults setObject:original[key] forKey:key];
  [defaults setBool:YES forKey:@"NativePrototypeSeeded"];
 }
 self.exporter=[WWSceneExporter new];[super viewDidLoad];
}
- (void)viewDidAppear:(BOOL)animated {
 [super viewDidAppear:animated];self.appeared=YES;
 self.panel.hidden=YES;[self.desktopBridge settingsMessage:@"Preparando animação…"];
 if(NSProcessInfo.processInfo.environment[@"WEATHER_NATIVE_TEST_HIDDEN"])[self.desktopBridge hideNativeRenderWindow];
 if(!NSProcessInfo.processInfo.environment[@"WEATHER_NATIVE_TEST_ONCE"])[self.desktopBridge showPreferences];
 [self applyWeather];[self restorePlaybackMode];
}
- (BOOL)continuousWallpaperEnabled {return [NSUserDefaults.standardUserDefaults boolForKey:@"ContinuousDesktopEnabled"];}
- (NSDictionary *)settingsState {
 NSMutableDictionary *state=[[super settingsState] mutableCopy];state[@"continuous"]=@(self.continuousWallpaperEnabled);state[@"preparing"]=@(self.exporter.busy || self.preparingExport);return state;
}
- (void)restorePlaybackMode {
 BOOL continuous=self.continuousWallpaperEnabled;
 self.wallpaper=continuous;[self.desktopBridge setLiveDesktopEnabled:continuous];
 if(!self.exporter.busy && !self.preparingExport){
  self.paused=!continuous || self.userPaused;[self.scene setPaused:self.paused];[self.scene setIsPlaying:!self.paused];[self.weatherView setRendersContinuously:!self.paused];[WWShootingStarForView(self.weatherView) setPlaybackPaused:self.paused];
  if(continuous)[self applyRenderingQuality];
 }
 [self rebuildPreferences];
}
- (void)setContinuousWallpaperEnabled:(BOOL)enabled {
 [NSUserDefaults.standardUserDefaults setBool:enabled forKey:@"ContinuousDesktopEnabled"];self.userPaused=NO;
 [self restorePlaybackMode];
 [self.desktopBridge settingsMessage:nil];
}
- (NSDictionary *)sceneMetadata {
 double elevation=self.live ? [self.liveWeather[@"elevation"] doubleValue] : (self.timeControl.selectedSegmentIndex==0 ? 35 : self.timeControl.selectedSegmentIndex==1 ? 1 : -25);
 return @{@"condition":self.condition ?: @"partlyCloudy",@"locationID":[self locationIdentifier],@"manualTime":self.live ? @(-1) : @(self.timeControl.selectedSegmentIndex),@"elevation":@(elevation),@"cloudCover":self.live ? self.liveWeather[@"cloudCover"] ?: @0 : @(cloudCover(self.condition)),@"wind":self.live ? self.liveWeather[@"wind"] ?: @12 : @12};
}
- (void)applyWeather {
 if(!self.appeared)return;
 if(self.exporter.busy || self.preparingExport){self.exportPending=YES;return;}
 NSDictionary *metadata=[self sceneMetadata];
 if(!WWNeedsNewScene(self.publishedScene,metadata,self.publishedDate ? -self.publishedDate.timeIntervalSinceNow : INFINITY)){if(self.continuousWallpaperEnabled)[super applyWeather];return;}
 self.paused=NO;[super applyWeather];
 if(!self.weatherView || !self.scene)return;
 // Bound the recording resolution independently of a Retina display.
 [self.weatherView setPreferredFramesPerSecond:24];[self.weatherView _allowGPUBackgroundExecution];
 self.panel.hidden=YES;self.exportPending=NO;
 __weak typeof(self) weakSelf=self;
 self.preparingExport=YES;[self rebuildPreferences];
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC),dispatch_get_main_queue(),^{
 NativeWeatherController *self=weakSelf;if(!self)return;self.preparingExport=NO;
 [self.exporter exportView:self.weatherView gradient:self.skyGradient metadata:metadata completion:^(NSError *error){
  NativeWeatherController *self=weakSelf;if(!self)return;
  if(error){NSLog(@"Native scene export failed: %@",error);[self.desktopBridge settingsMessage:error.localizedDescription];}
  else {self.publishedScene=metadata;self.publishedDate=NSDate.date;[self.desktopBridge settingsMessage:nil];}
  [self restorePlaybackMode];
  if(NSProcessInfo.processInfo.environment[@"WEATHER_NATIVE_TEST_ONCE"]){NSLog(@"%@ native scene export",error ? @"FAIL:" : @"PASS:");exit(error ? 1 : 0);}
  if(self.exportPending){self.exportPending=NO;[self applyWeather];}
 }];
 });
}
- (void)useWallpaper {if(!self.appeared)return;if(self.continuousWallpaperEnabled)[self restorePlaybackMode];else [self.desktopBridge openNativeWallpaperSettings];}
- (void)togglePause {if(self.continuousWallpaperEnabled && !self.exporter.busy && !self.preparingExport){[super togglePause];self.userPaused=self.paused;[self.scene setIsPlaying:!self.paused];}}
- (void)showPreview {[self.desktopBridge showPreferences];}
@end

@interface NativeWeatherSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation NativeWeatherSceneDelegate
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
 self.window=[[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];self.window.rootViewController=[NativeWeatherController new];[self.window makeKeyAndVisible];
}
@end
@interface NativeWeatherDelegate : UIResponder <UIApplicationDelegate> @end
@implementation NativeWeatherDelegate
- (UISceneConfiguration *)application:(UIApplication *)app configurationForConnectingSceneSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
 UISceneConfiguration *configuration=[[UISceneConfiguration alloc] initWithName:@"Native Weather" sessionRole:session.role];configuration.delegateClass=NativeWeatherSceneDelegate.class;return configuration;
}
@end

#ifndef WW_NATIVE_NO_MAIN
int main(int argc,char **argv){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(NativeWeatherDelegate.class));}}

#endif
