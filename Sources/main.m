#import "PrivateVFX.h"
#import <dlfcn.h>
#import <Metal/MTLPixelFormat.h>
#import <MetalKit/MetalKit.h>
#import <QuartzCore/CAMetalLayer.h>
@interface NSObject (WeatherAPI)
+ (BOOL)isSupported;
+ (id)makeView:(id)effect;
+ (NSDictionary *)applyEffect:(id)effect condition:(NSString *)condition elevation:(double)elevation cloudCover:(double)cover wind:(double)wind size:(CGSize)size isPM:(BOOL)isPM timeZone:(NSString *)timeZone details:(NSDictionary *)details;
+ (void)search:(NSString *)query completion:(void(^)(NSArray<NSDictionary *> *,NSString *))completion;
+ (NSDictionary *)lightingForLocation:(NSDictionary *)location;
+ (void)fetch:(NSDictionary *)location completion:(void(^)(NSDictionary *,NSString *))completion;
- (instancetype)initWithController:(id)controller;
- (void)setWallpaper:(BOOL)enabled;
- (BOOL)menuBarVisible;
- (void)setMenuBarVisible:(BOOL)visible;
- (NSInteger)loginItemStatus;
- (BOOL)launchedAtLogin;
- (void)setLaunchAtLogin:(BOOL)enabled completion:(void(^)(NSString *))completion;
@end
static NSString *conditionTitle(NSString *c) {return @{@"clear":@"Céu limpo",@"mostlyClear":@"Predominantemente limpo",@"partlyCloudy":@"Parcialmente nublado",@"mostlyCloudy":@"Muito nublado",@"cloudy":@"Nublado",@"rain":@"Chuva",@"heavyRain":@"Chuva forte",@"drizzle":@"Garoa",@"thunderstorms":@"Tempestade",@"snow":@"Neve",@"heavySnow":@"Neve intensa",@"foggy":@"Neblina",@"hail":@"Granizo",@"freezingRain":@"Chuva congelante",@"freezingDrizzle":@"Garoa congelante",@"windy":@"Vento"}[c] ?: c;}
static double cloudCover(NSString *c) {if([c isEqual:@"clear"])return 0;if([c isEqual:@"mostlyClear"])return 0.15;if([c isEqual:@"partlyCloudy"])return 0.45;return 0.95;}

@interface WeatherController : UIViewController <UITextFieldDelegate>
@property(nonatomic,strong) UIView *weatherView;
@property(nonatomic,strong) CAGradientLayer *skyGradient,*nightSkyMask;
@property(nonatomic,strong) id scene,effect,desktopBridge;
@property(nonatomic,strong) UIVisualEffectView *panel;
@property(nonatomic,strong) UILabel *cityLabel,*temperatureLabel,*conditionLabel,*statusLabel;
@property(nonatomic,strong) UIButton *sceneButton,*pauseButton,*liveButton,*settingsButton;
@property(nonatomic,strong) UISegmentedControl *timeControl;
@property(nonatomic,strong) UITextField *cityField;
@property(nonatomic,strong) NSDictionary *location,*liveWeather;
@property(nonatomic,strong) NSTimer *refreshTimer;
@property(nonatomic,copy) NSString *condition;
@property(nonatomic) BOOL live,paused,wallpaper,ready,requesting;
@property(nonatomic) NSUInteger requestGeneration;
@property(nonatomic) CGSize renderedSize;
@property(nonatomic) BOOL automaticWeather;
@property(nonatomic,strong) NSDate *nextWeatherRefresh;
@end
@implementation WeatherController
- (UILabel *)label:(NSString *)text size:(CGFloat)size weight:(UIFontWeight)weight {UILabel *l=[UILabel new];l.text=text;l.textColor=UIColor.whiteColor;l.font=[UIFont systemFontOfSize:size weight:weight];l.numberOfLines=0;return l;}
- (UIButton *)button:(NSString *)title action:(SEL)action filled:(BOOL)filled {
 UIButtonConfiguration *c=filled ? UIButtonConfiguration.filledButtonConfiguration : UIButtonConfiguration.tintedButtonConfiguration;
 c.title=title;c.baseForegroundColor=UIColor.whiteColor;c.baseBackgroundColor=filled ? [UIColor colorWithRed:0.23 green:0.48 blue:0.9 alpha:1] : [UIColor colorWithWhite:1 alpha:0.15];c.cornerStyle=UIButtonConfigurationCornerStyleMedium;
 UIButton *b=[UIButton buttonWithConfiguration:c primaryAction:nil];if(action)[b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];return b;
}
- (void)viewDidLoad {
 [super viewDidLoad];self.view.backgroundColor=[UIColor colorWithRed:0.08 green:0.16 blue:0.25 alpha:1];
 self.condition=NSProcessInfo.processInfo.environment[@"WEATHER_SCENE"] ?: @"partlyCloudy";
 self.location=[NSUserDefaults.standardUserDefaults dictionaryForKey:@"SelectedLocation"];
 NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;
 self.automaticWeather=[defaults objectForKey:@"AutomaticWeatherEnabled"]==nil || [defaults boolForKey:@"AutomaticWeatherEnabled"];
 NSDictionary *cache=[defaults dictionaryForKey:@"LastWeatherCache"];
 if([cache[@"locationID"] isEqual:[self locationIdentifier]] && self.automaticWeather)self.liveWeather=cache[@"weather"];
 [self buildControls];
 if(!dlopen("/System/iOSSupport/System/Library/PrivateFrameworks/WeatherUI.framework/WeatherUI",RTLD_NOW) || ![NSClassFromString(@"WeatherRuntime") isSupported]) {[self setStatus:@"Este renderizador precisa do WeatherUI do macOS 27. A versão instalada não é compatível."];return;}
 NSString *root=@"/System/iOSSupport/System/Library/PrivateFrameworks/WeatherUI.framework/Resources";
 id options=[NSClassFromString(@"VFXSceneLoadOptions") new];[options setValue:@YES forKey:@"loadBindingsMetadata"];
 [options setValue:[NSURL fileURLWithPath:[root stringByAppendingPathComponent:@"default.metallib"]] forKey:@"metalLibraryURL"];
 NSError *error=nil;self.scene=[[NSClassFromString(@"VFX.VFXScene") alloc] initWithContentsOf:[NSURL fileURLWithPath:[root stringByAppendingPathComponent:@"VFX/WeatherV136_Default_Background.vfx"]] options:options error:&error];
 if(!self.scene){[self setStatus:error.localizedDescription ?: @"Não foi possível carregar a cena do Tempo."];return;}
 self.effect=[self.scene addEffectWithEffectID:0];if(!self.effect){[self setStatus:@"O formato da cena do Tempo mudou."];return;}
 self.weatherView=[NSClassFromString(@"WeatherRuntime") makeView:self.effect];self.weatherView.frame=self.view.bounds;self.weatherView.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
 // VFX shaders emit linear RGB. Encode to sRGB when writing the display target.
 [self.weatherView setPixelFormat:MTLPixelFormatBGRA8Unorm_sRGB];
 self.weatherView.backgroundColor=UIColor.clearColor;self.weatherView.opaque=NO;
 if([self.weatherView isKindOfClass:MTKView.class])((MTKView *)self.weatherView).clearColor=MTLClearColorMake(0,0,0,0);
 self.skyGradient=[CAGradientLayer layer];self.skyGradient.frame=self.view.bounds;
 [self applyRenderingQuality];[self.weatherView setRendersContinuously:YES];[self.scene setIsPlaying:YES];
 [self.view insertSubview:self.weatherView atIndex:0];[self.view.layer insertSublayer:self.skyGradient atIndex:0];self.ready=YES;[self applyWeather];
 __weak typeof(self) weakSelf=self;
 self.refreshTimer=[NSTimer scheduledTimerWithTimeInterval:60 repeats:YES block:^(NSTimer *timer){[weakSelf automaticTick];}];self.refreshTimer.tolerance=5;
 [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(applyRenderingQuality) name:NSProcessInfoPowerStateDidChangeNotification object:nil];
 if(self.location){self.cityField.text=self.location[@"name"];if(self.liveWeather)[self displayCurrentWeather];if(self.automaticWeather)[self refreshWeather];}
}
- (void)buildControls {
 self.panel=[[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark]];self.panel.translatesAutoresizingMaskIntoConstraints=NO;self.panel.layer.cornerRadius=24;self.panel.clipsToBounds=YES;self.panel.layer.borderWidth=0.5;self.panel.layer.borderColor=[UIColor colorWithWhite:1 alpha:0.2].CGColor;[self.view addSubview:self.panel];
 UIStackView *stack=[UIStackView new];stack.axis=UILayoutConstraintAxisVertical;stack.spacing=12;stack.translatesAutoresizingMaskIntoConstraints=NO;[self.panel.contentView addSubview:stack];
 UILabel *eyebrow=[self label:@"TEMPO EM MOVIMENTO" size:11 weight:UIFontWeightSemibold];eyebrow.textColor=[UIColor colorWithWhite:1 alpha:0.65];[stack addArrangedSubview:eyebrow];
 self.cityLabel=[self label:@"Prévia do clima" size:25 weight:UIFontWeightSemibold];[stack addArrangedSubview:self.cityLabel];
 self.temperatureLabel=[self label:@"—°" size:56 weight:UIFontWeightThin];[stack addArrangedSubview:self.temperatureLabel];
 self.conditionLabel=[self label:conditionTitle(self.condition) size:16 weight:UIFontWeightMedium];[stack addArrangedSubview:self.conditionLabel];
 UILabel *hint=[self label:@"Céu, luz e partículas do app Tempo." size:12 weight:UIFontWeightRegular];hint.textColor=[UIColor colorWithWhite:1 alpha:0.65];[stack addArrangedSubview:hint];
 UIView *rule=[UIView new];rule.backgroundColor=[UIColor colorWithWhite:1 alpha:0.14];[rule.heightAnchor constraintEqualToConstant:0.5].active=YES;[stack addArrangedSubview:rule];
 self.sceneButton=[self button:@"Escolher clima" action:nil filled:NO];self.sceneButton.showsMenuAsPrimaryAction=YES;[stack addArrangedSubview:self.sceneButton];[self buildSceneMenu];
 self.timeControl=[[UISegmentedControl alloc] initWithItems:@[@"Dia",@"Entardecer",@"Noite"]];self.timeControl.selectedSegmentIndex=0;[self.timeControl addTarget:self action:@selector(timeChanged) forControlEvents:UIControlEventValueChanged];[stack addArrangedSubview:self.timeControl];
 self.cityField=[UITextField new];self.cityField.placeholder=@"Buscar cidade";self.cityField.borderStyle=UITextBorderStyleRoundedRect;self.cityField.backgroundColor=[UIColor colorWithWhite:1 alpha:0.08];self.cityField.textColor=UIColor.whiteColor;self.cityField.delegate=self;self.cityField.returnKeyType=UIReturnKeySearch;[self.cityField.heightAnchor constraintEqualToConstant:34].active=YES;[stack addArrangedSubview:self.cityField];
 self.liveButton=[self button:@"Usar clima da cidade" action:@selector(searchCity) filled:NO];[stack addArrangedSubview:self.liveButton];
 [stack addArrangedSubview:[self button:@"Usar como wallpaper" action:@selector(useWallpaper) filled:YES]];
 self.pauseButton=[self button:@"Pausar animação" action:@selector(togglePause) filled:NO];[stack addArrangedSubview:self.pauseButton];
 self.settingsButton=[self button:@"Preferências" action:nil filled:NO];self.settingsButton.showsMenuAsPrimaryAction=YES;[stack addArrangedSubview:self.settingsButton];
 self.statusLabel=[self label:@"" size:11 weight:UIFontWeightRegular];self.statusLabel.textColor=[UIColor colorWithWhite:1 alpha:0.6];self.statusLabel.hidden=YES;[stack addArrangedSubview:self.statusLabel];
 [NSLayoutConstraint activateConstraints:@[[self.panel.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:24],[self.panel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:24],[self.panel.widthAnchor constraintEqualToConstant:304],[stack.leadingAnchor constraintEqualToAnchor:self.panel.contentView.leadingAnchor constant:22],[stack.trailingAnchor constraintEqualToAnchor:self.panel.contentView.trailingAnchor constant:-22],[stack.topAnchor constraintEqualToAnchor:self.panel.contentView.topAnchor constant:22],[stack.bottomAnchor constraintEqualToAnchor:self.panel.contentView.bottomAnchor constant:-22]]];self.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;
}
- (void)setStatus:(NSString *)text {self.statusLabel.text=text;self.statusLabel.hidden=text.length==0;}
- (void)buildSceneMenu {
 NSMutableArray *actions=[NSMutableArray new];__weak typeof(self) weakSelf=self;
 UIAction *automatic=[UIAction actionWithTitle:@"Clima automático" image:[UIImage systemImageNamed:@"arrow.triangle.2.circlepath"] identifier:nil handler:^(UIAction *action){[weakSelf enableAutomaticWeather];}];automatic.state=self.automaticWeather ? UIMenuElementStateOn : UIMenuElementStateOff;[actions addObject:automatic];
 for(NSString *c in @[@"clear",@"mostlyClear",@"partlyCloudy",@"mostlyCloudy",@"cloudy",@"drizzle",@"rain",@"heavyRain",@"thunderstorms",@"snow",@"heavySnow",@"foggy",@"hail",@"windy"]) {[actions addObject:[UIAction actionWithTitle:conditionTitle(c) image:nil identifier:nil handler:^(UIAction *action){[weakSelf selectCondition:c];}]];}
 self.sceneButton.menu=[UIMenu menuWithTitle:@"Prévia das animações" children:actions];
}
- (void)viewDidLayoutSubviews {[super viewDidLayoutSubviews];CGSize size=self.view.bounds.size;if(self.ready && (fabs(size.width-self.renderedSize.width)>1 || fabs(size.height-self.renderedSize.height)>1))[self applyWeather];}
- (void)viewDidAppear:(BOOL)animated {
 [super viewDidAppear:animated];

 if(!self.desktopBridge){NSURL *url=[NSBundle.mainBundle.builtInPlugInsURL URLByAppendingPathComponent:@"DesktopBridge.bundle"];NSBundle *bundle=[NSBundle bundleWithURL:url];NSError *error=nil;if([bundle loadAndReturnError:&error])self.desktopBridge=[[bundle.principalClass alloc] initWithController:self];if(!self.desktopBridge)[self setStatus:@"A prévia funciona, mas o modo desktop não pôde ser carregado."];
 [self rebuildPreferences];
 if([self.desktopBridge launchedAtLogin] || [self.desktopBridge loginItemStatus]==1 || [NSProcessInfo.processInfo.arguments containsObject:@"--background"])[self useWallpaper];
 }
}
- (void)selectCondition:(NSString *)c {self.live=NO;self.automaticWeather=NO;[NSUserDefaults.standardUserDefaults setBool:NO forKey:@"AutomaticWeatherEnabled"];self.requestGeneration++;self.requesting=NO;self.condition=c;self.timeControl.enabled=YES;self.cityLabel.text=@"Prévia do clima";self.temperatureLabel.text=@"—°";[self applyWeather];[self buildSceneMenu];[self rebuildPreferences];}
- (void)timeChanged {if(!self.live)[self applyWeather];}
- (void)applyWeather {
 if(!self.ready)return;self.renderedSize=self.view.bounds.size;[CATransaction begin];[CATransaction setDisableActions:YES];self.skyGradient.frame=self.view.bounds;[CATransaction commit];double e=self.live ? [self.liveWeather[@"elevation"] doubleValue] : (self.timeControl.selectedSegmentIndex==0 ? 35 : self.timeControl.selectedSegmentIndex==1 ? 1 : -25);
 if(!self.live && NSProcessInfo.processInfo.environment[@"WEATHER_ELEVATION"])e=[NSProcessInfo.processInfo.environment[@"WEATHER_ELEVATION"] doubleValue];
 NSMutableDictionary *details=self.live ? [self.liveWeather mutableCopy] : [NSMutableDictionary new];
 if(self.location){details[@"latitude"]=self.location[@"latitude"];details[@"longitude"]=self.location[@"longitude"];}
 NSDictionary *r;
 // Stop and join VFX's simulation before changing its graph or parameters.
 // A scene transaction alone does not stop the runtime's cached pointer reads.
 [self.weatherView setRendersContinuously:NO];[self.scene stopRuntimeThread];
 [self.weatherView lock];
 @try {r=[NSClassFromString(@"WeatherRuntime") applyEffect:self.effect condition:self.condition elevation:e cloudCover:self.live ? [self.liveWeather[@"cloudCover"] doubleValue] : cloudCover(self.condition) wind:self.live ? [self.liveWeather[@"wind"] doubleValue] : 12 size:self.view.bounds.size isPM:self.live ? [self.liveWeather[@"isPM"] boolValue] : self.timeControl.selectedSegmentIndex==1 timeZone:self.liveWeather[@"timeZone"] ?: NSTimeZone.localTimeZone.name details:details];}
 @finally {[self.weatherView unlock];[self.scene startRuntimeThread];[self.weatherView setRendersContinuously:!self.paused];}
 if(r[@"error"]){[self setStatus:r[@"error"]];return;}
 // Weather's night sky recedes toward the horizon. Keep the gradient below
 // the VFX view intact while fading stars and thin cloud effects above it.
 BOOL starry=[@[@"clear",@"mostlyClear",@"partlyCloudy",@"mostlyCloudy"] containsObject:self.condition];
 CGFloat fade=starry ? MIN(1,MAX(0,-e/6.0)) : 0;
 if(fade>0) {
  if(!self.nightSkyMask)self.nightSkyMask=[CAGradientLayer layer];
  [CATransaction begin];[CATransaction setDisableActions:YES];self.nightSkyMask.frame=self.weatherView.bounds;
  self.nightSkyMask.startPoint=CGPointMake(0.5,0);self.nightSkyMask.endPoint=CGPointMake(0.5,1);
  self.nightSkyMask.locations=@[@0,@0.18,@0.40,@0.62,@0.80,@1];
  NSMutableArray *colors=[NSMutableArray new];for(NSNumber *alpha in @[@1,@0.95,@0.55,@0.14,@0,@0])[colors addObject:(id)[UIColor colorWithWhite:1 alpha:1-fade*(1-alpha.doubleValue)].CGColor];
  self.nightSkyMask.colors=colors;self.weatherView.layer.mask=self.nightSkyMask;[CATransaction commit];
 } else self.weatherView.layer.mask=nil;
 CAGradientLayer *gradient=r[@"gradientLayer"];[CATransaction begin];[CATransaction setDisableActions:YES];self.skyGradient.colors=gradient.colors;self.skyGradient.locations=gradient.locations;self.skyGradient.startPoint=gradient.startPoint;self.skyGradient.endPoint=gradient.endPoint;[CATransaction commit];
 self.conditionLabel.text=conditionTitle(self.condition);UIButtonConfiguration *config=[self.sceneButton.configuration copy];config.title=conditionTitle(self.condition);self.sceneButton.configuration=config;[self setStatus:@""];NSLog(@"Rendered condition=%@ elevation=%.2f live=%d",self.condition,e,self.live);
}
- (void)searchCity {
 NSString *query=[self.cityField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];if(query.length<2){[self setStatus:@"Digite o nome da cidade."];return;}self.liveButton.enabled=NO;[self setStatus:@"Buscando cidades…"];__weak typeof(self) weakSelf=self;
 [NSClassFromString(@"WeatherService") search:query completion:^(NSArray<NSDictionary *> *cities,NSString *error){WeatherController *self=weakSelf;if(!self)return;self.liveButton.enabled=YES;if(error || !cities.count){[self setStatus:error ?: @"Nenhuma cidade encontrada."];return;}
 UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Escolha a cidade" message:nil preferredStyle:UIAlertControllerStyleAlert];
 for(NSDictionary *city in cities){NSString *title=[NSString stringWithFormat:@"%@ · %@, %@",city[@"name"],city[@"admin1"] ?: @"",city[@"country"] ?: @""];[alert addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){self.requestGeneration++;self.requesting=NO;self.location=city;self.liveWeather=nil;[NSUserDefaults.standardUserDefaults removeObjectForKey:@"LastWeatherCache"];[NSUserDefaults.standardUserDefaults setObject:city forKey:@"SelectedLocation"];[self enableAutomaticWeather];}]];}
 [alert addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action){[self setStatus:@"Seleção cancelada."];}]];[self presentViewController:alert animated:YES completion:nil];}];
}
- (BOOL)textFieldShouldReturn:(UITextField *)field {[field resignFirstResponder];[self searchCity];return YES;}
- (NSString *)locationIdentifier {
 if(!self.location)return @"";
 return [NSString stringWithFormat:@"%.5f,%.5f",[self.location[@"latitude"] doubleValue],[self.location[@"longitude"] doubleValue]];
}
- (void)displayCurrentWeather {
 if(!self.liveWeather)return;
 NSMutableDictionary *weather=[self.liveWeather mutableCopy];
 [weather addEntriesFromDictionary:[NSClassFromString(@"WeatherService") lightingForLocation:self.location]];
 self.liveWeather=weather;
 self.live=YES;self.condition=self.liveWeather[@"condition"];self.timeControl.enabled=NO;
 double elevation=[self.liveWeather[@"elevation"] doubleValue];self.timeControl.selectedSegmentIndex=elevation>6 ? 0 : elevation> -6 ? 1 : 2;
 self.cityLabel.text=self.location[@"name"];self.temperatureLabel.text=[NSString stringWithFormat:@"%.0f°",[self.liveWeather[@"temperature"] doubleValue]];
 [self applyWeather];[self buildSceneMenu];
}
- (void)enableAutomaticWeather {
 self.automaticWeather=YES;[NSUserDefaults.standardUserDefaults setBool:YES forKey:@"AutomaticWeatherEnabled"];
 [self buildSceneMenu];[self rebuildPreferences];
 if(!self.location){[self setStatus:@"Escolha uma cidade para acompanhar o clima."];[self.cityField becomeFirstResponder];return;}
 if(self.liveWeather)[self displayCurrentWeather];[self refreshWeather];
}
- (void)automaticTick {
 if(!self.automaticWeather || !self.location)return;
 if(self.liveWeather)[self displayCurrentWeather];
 if(!self.nextWeatherRefresh || [self.nextWeatherRefresh timeIntervalSinceNow]<=0)[self refreshWeather];
}
- (void)refreshAfterWake {self.nextWeatherRefresh=nil;[self automaticTick];[self applyRenderingQuality];}
- (void)refreshWeather {
 if(!self.location || self.requesting || !self.automaticWeather)return;
 self.requesting=YES;self.nextWeatherRefresh=[NSDate dateWithTimeIntervalSinceNow:600];
 if(!self.liveWeather)[self setStatus:@"Atualizando clima…"];
 NSUInteger generation=++self.requestGeneration;NSString *locationID=[self locationIdentifier];__weak typeof(self) weakSelf=self;
 [NSClassFromString(@"WeatherService") fetch:self.location completion:^(NSDictionary *weather,NSString *error){
  WeatherController *self=weakSelf;if(!self || generation!=self.requestGeneration)return;self.requesting=NO;
  if(!weather){self.nextWeatherRefresh=[NSDate dateWithTimeIntervalSinceNow:60];[self setStatus:error ?: @"Sem conexão. Tentaremos atualizar novamente."];return;}
  self.liveWeather=weather;[NSUserDefaults.standardUserDefaults setObject:@{@"locationID":locationID,@"weather":weather} forKey:@"LastWeatherCache"];
  [self displayCurrentWeather];
 }];
}
- (void)applyRenderingQuality {
 BOOL high=[NSUserDefaults.standardUserDefaults objectForKey:@"HighQualityRendering"]==nil || [NSUserDefaults.standardUserDefaults boolForKey:@"HighQualityRendering"];
 NSInteger fps=(high && !NSProcessInfo.processInfo.lowPowerModeEnabled) ? 60 : 30;
 CGFloat scale=self.view.window.screen.scale ?: UIScreen.mainScreen.scale;
 self.weatherView.contentScaleFactor=scale;[self.weatherView setPreferredFramesPerSecond:fps];
}
- (void)rebuildPreferences {
 if(!self.desktopBridge)return;
 __weak typeof(self) weakSelf=self;
 BOOL login=[self.desktopBridge loginItemStatus]==1 || [self.desktopBridge loginItemStatus]==2;
 UIAction *start=[UIAction actionWithTitle:@"Iniciar com o Mac" image:nil identifier:nil handler:^(UIAction *action){
  [weakSelf.desktopBridge setLaunchAtLogin:!login completion:^(NSString *error){[weakSelf setStatus:error ?: @""];[weakSelf rebuildPreferences];}];
 }];start.state=login ? UIMenuElementStateOn : UIMenuElementStateOff;
 BOOL hidden=![self.desktopBridge menuBarVisible];
 UIAction *hide=[UIAction actionWithTitle:@"Ocultar da barra de menus" image:nil identifier:nil handler:^(UIAction *action){[weakSelf.desktopBridge setMenuBarVisible:hidden];[weakSelf rebuildPreferences];}];hide.state=hidden ? UIMenuElementStateOn : UIMenuElementStateOff;
 UIAction *automatic=[UIAction actionWithTitle:@"Atualizar clima automaticamente" image:nil identifier:nil handler:^(UIAction *action){
  if(weakSelf.automaticWeather){weakSelf.automaticWeather=NO;weakSelf.requestGeneration++;weakSelf.requesting=NO;[NSUserDefaults.standardUserDefaults setBool:NO forKey:@"AutomaticWeatherEnabled"];[weakSelf buildSceneMenu];[weakSelf rebuildPreferences];}else [weakSelf enableAutomaticWeather];
 }];automatic.state=self.automaticWeather ? UIMenuElementStateOn : UIMenuElementStateOff;
 NSMutableArray *qualities=[NSMutableArray new];
 BOOL high=[NSUserDefaults.standardUserDefaults objectForKey:@"HighQualityRendering"]==nil || [NSUserDefaults.standardUserDefaults boolForKey:@"HighQualityRendering"];
 for(NSNumber *value in @[@YES,@NO]){
  UIAction *quality=[UIAction actionWithTitle:value.boolValue ? @"Alta · Retina, até 60 fps" : @"Econômica · 30 fps" image:nil identifier:nil handler:^(UIAction *action){[NSUserDefaults.standardUserDefaults setBool:value.boolValue forKey:@"HighQualityRendering"];[weakSelf applyRenderingQuality];[weakSelf rebuildPreferences];}];quality.state=(value.boolValue==high) ? UIMenuElementStateOn : UIMenuElementStateOff;[qualities addObject:quality];
 }
 UIAction *refresh=[UIAction actionWithTitle:@"Atualizar agora" image:[UIImage systemImageNamed:@"arrow.clockwise"] identifier:nil handler:^(UIAction *action){[weakSelf enableAutomaticWeather];}];
 UIAction *restoreHint=[UIAction actionWithTitle:@"Reabrir controles: ⌘⇧P ou abrir o app" image:nil identifier:nil handler:^(UIAction *action){}];restoreHint.attributes=UIMenuElementAttributesDisabled;
 self.settingsButton.menu=[UIMenu menuWithTitle:@"Preferências" children:@[automatic,start,hide,[UIMenu menuWithTitle:@"Qualidade" children:qualities],refresh,restoreHint]];
}
- (void)showPreferences {[self rebuildPreferences];if(@available(macCatalyst 17.4,*))[self.settingsButton performPrimaryAction];}
- (void)useWallpaper {if(!self.ready || !self.desktopBridge)return;self.panel.hidden=YES;[self.weatherView _allowGPUBackgroundExecution];[self.desktopBridge setWallpaper:YES];self.wallpaper=YES;}
- (void)showPreview {self.panel.hidden=NO;[self.desktopBridge setWallpaper:NO];self.wallpaper=NO;}
- (void)togglePause {self.paused=!self.paused;[self.scene setPaused:self.paused];[self.weatherView setRendersContinuously:!self.paused];UIButtonConfiguration *c=[self.pauseButton.configuration copy];c.title=self.paused ? @"Continuar animação" : @"Pausar animação";self.pauseButton.configuration=c;}
- (void)dealloc {[self.refreshTimer invalidate];[NSNotificationCenter.defaultCenter removeObserver:self];}
@end
@interface WeatherSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation WeatherSceneDelegate
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {self.window=[[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];self.window.rootViewController=[WeatherController new];[self.window makeKeyAndVisible];((UIWindowScene *)scene).sizeRestrictions.minimumSize=CGSizeMake(760,720);}
@end
@interface WeatherDelegate : UIResponder <UIApplicationDelegate>
@end
@implementation WeatherDelegate
- (UISceneConfiguration *)application:(UIApplication *)app configurationForConnectingSceneSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {UISceneConfiguration *c=[[UISceneConfiguration alloc] initWithName:@"Weather" sessionRole:session.role];c.delegateClass=WeatherSceneDelegate.class;return c;}
@end
int main(int argc,char **argv) {@autoreleasepool {return UIApplicationMain(argc,argv,nil,NSStringFromClass(WeatherDelegate.class));}}
