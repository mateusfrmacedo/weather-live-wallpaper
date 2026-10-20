#import <AppKit/AppKit.h>
#import <ServiceManagement/ServiceManagement.h>
#import <Carbon/Carbon.h>

@protocol WeatherControls <NSObject>
- (void)showPreview;
- (void)showPreferences;
- (void)useWallpaper;
- (void)togglePause;
- (void)refreshAfterWake;
- (void)displayGeometryChanged;
- (NSDictionary *)settingsState;
- (void)setAutomaticWeatherEnabled:(BOOL)enabled;
- (void)setHighQualityRendering:(BOOL)enabled;
- (void)refreshWeatherNow;
- (void)searchCities:(NSString *)query completion:(void(^)(NSArray<NSDictionary *> *,NSString *))completion;
- (void)selectCity:(NSDictionary *)city;
- (void)selectCondition:(NSString *)condition;
- (void)setPreviewTime:(NSInteger)time;
@end

@interface DesktopBridge : NSObject
@property(nonatomic,strong) NSStatusItem *status;
@property(nonatomic,weak) id<WeatherControls> controller;
@property(nonatomic,weak) NSWindow *window;
@property(nonatomic) BOOL wallpaper;
@property(nonatomic) NSRect previewFrame;
@property(nonatomic) NSWindowStyleMask previewStyle;
@property(nonatomic) EventHotKeyRef hotKey;
@property(nonatomic) EventHandlerRef hotKeyHandler;
@property(nonatomic) BOOL launchedAtLogin,changingLogin;
@property(nonatomic,strong) NSPanel *settingsWindow;
@property(nonatomic,strong) NSTextField *settingsCity,*settingsSummary,*settingsStatus;
@property(nonatomic,strong) NSSearchField *settingsSearch;
@property(nonatomic,strong) NSButton *searchButton,*pauseControl;
@property(nonatomic,strong) NSSwitch *loginControl,*menuControl,*dockControl;
@property(nonatomic,strong) NSPopUpButton *qualityControl,*cityResults,*weatherControl,*timeControl;
@property(nonatomic) NSUInteger searchGeneration;
@property(nonatomic,copy) NSString *settingsMessageText;
@property(nonatomic,strong) NSView *qualityCard;
- (void)setWallpaper:(BOOL)enabled;
- (void)showPreview;
@end

@interface WeatherSettingsDocument : NSView @end
@implementation WeatherSettingsDocument
- (BOOL)isFlipped {return YES;}
@end

static OSStatus restoreControls(EventHandlerCallRef next, EventRef event, void *context) {
 DesktopBridge *bridge=(__bridge DesktopBridge *)context;
 [bridge showPreview];
 return noErr;
}

@implementation DesktopBridge
- (instancetype)initWithController:(id)controller {
 if((self=[super init])) {
  self.controller=controller;
  [NSApplication.sharedApplication setActivationPolicy:[NSUserDefaults.standardUserDefaults boolForKey:@"ShowDockIcon"] ? NSApplicationActivationPolicyRegular : NSApplicationActivationPolicyAccessory];
  NSAppleEventDescriptor *event=NSAppleEventManager.sharedAppleEventManager.currentAppleEvent;
  self.launchedAtLogin=[event paramDescriptorForKeyword:keyAELaunchedAsLogInItem]!=nil;
  [NSAppleEventManager.sharedAppleEventManager setEventHandler:self andSelector:@selector(handleReopen:reply:) forEventClass:kCoreEventClass andEventID:kAEReopenApplication];
  EventTypeSpec type={kEventClassKeyboard,kEventHotKeyPressed};
  EventHandlerRef handler=NULL;
  OSStatus installed=InstallApplicationEventHandler(restoreControls,1,&type,(__bridge void*)self,&handler);
  self.hotKeyHandler=handler;
  EventHotKeyRef hotKey=NULL;
  if(installed==noErr)RegisterEventHotKey(kVK_ANSI_P,cmdKey|shiftKey,(EventHotKeyID){'WWal',1},GetApplicationEventTarget(),0,&hotKey);
  self.hotKey=hotKey;
  self.status=[NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
  NSImage *icon=[NSImage imageWithSystemSymbolName:@"cloud.sun" accessibilityDescription:@"Weather Wallpaper"];
  icon=[icon imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:16 weight:NSFontWeightRegular]];
  icon.template=YES;icon.size=NSMakeSize(20,18);self.status.button.image=icon;self.status.button.toolTip=@"Weather Wallpaper";
  self.status.visible=![NSUserDefaults.standardUserDefaults boolForKey:@"HideMenuBarIcon"];
  NSMenu *menu=[[NSMenu alloc] initWithTitle:@"Weather Wallpaper"];
  [menu addItem:[[NSMenuItem alloc] initWithTitle:@"Weather Wallpaper" action:nil keyEquivalent:@""]];
  [menu addItem:NSMenuItem.separatorItem];
  for(NSArray *entry in @[@[@"Configurações…",@"showPreferences"],@[@"Usar como wallpaper",@"useWallpaper"],@[@"Pausar / continuar",@"togglePause"],@[@"Sair",@"quit"]]) {
   NSMenuItem *item=[[NSMenuItem alloc] initWithTitle:entry[0] action:NSSelectorFromString(entry[1]) keyEquivalent:@""];item.target=self;[menu addItem:item];
  }
  self.status.menu=menu;
  NSMenuItem *controls=[[NSMenuItem alloc] initWithTitle:@"Configurações do wallpaper…" action:@selector(showPreferences) keyEquivalent:@"p"];
  controls.keyEquivalentModifierMask=NSEventModifierFlagCommand|NSEventModifierFlagShift;controls.target=self;
  NSMenu *fileMenu=[NSApplication.sharedApplication.mainMenu itemAtIndex:1].submenu;[fileMenu insertItem:controls atIndex:0];
  for(NSWindow *window in NSApplication.sharedApplication.windows) {
   if([NSStringFromClass(window.class) containsString:@"UINS"] && window.contentView){self.window=window;break;}
  }
  if(!self.window)for(NSWindow *window in NSApplication.sharedApplication.windows)if(window.contentView && window.canBecomeMainWindow){self.window=window;break;}
  if(self.window) {
   NSRect screen=self.window.screen.visibleFrame;
   [self.window setContentSize:NSMakeSize(MIN(1180,screen.size.width*0.88),MIN(760,screen.size.height*0.85))];
   [self.window center];self.window.title=@"Weather Wallpaper";self.window.titlebarAppearsTransparent=YES;self.window.styleMask|=NSWindowStyleMaskFullSizeContentView;
  }
  [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(screenChanged:) name:NSApplicationDidChangeScreenParametersNotification object:nil];
  [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(screenChanged:) name:NSWindowDidChangeScreenNotification object:self.window];
  [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(screenChanged:) name:NSWindowDidChangeBackingPropertiesNotification object:self.window];
  [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self selector:@selector(woke:) name:NSWorkspaceDidWakeNotification object:nil];
 }
 return self;
}
- (double)renderBackingScale {return (self.window.screen ?: NSScreen.mainScreen).backingScaleFactor;}
- (BOOL)menuBarVisible {return self.status.visible;}
- (void)setMenuBarVisible:(BOOL)visible {
 self.status.visible=visible;[NSUserDefaults.standardUserDefaults setBool:!visible forKey:@"HideMenuBarIcon"];
}
- (BOOL)dockVisible {return NSApplication.sharedApplication.activationPolicy==NSApplicationActivationPolicyRegular;}
- (void)setDockVisible:(BOOL)visible {
 [NSUserDefaults.standardUserDefaults setBool:visible forKey:@"ShowDockIcon"];
 [NSApplication.sharedApplication setActivationPolicy:visible ? NSApplicationActivationPolicyRegular : NSApplicationActivationPolicyAccessory];
 if(self.settingsWindow.visible){[NSApplication.sharedApplication activateIgnoringOtherApps:YES];[self.settingsWindow makeKeyAndOrderFront:nil];}
}
- (NSInteger)loginItemStatus {return SMAppService.mainAppService.status;}
- (void)setLaunchAtLogin:(BOOL)enabled completion:(void(^)(NSString *))completion {
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
  NSError *error=nil;SMAppService *service=SMAppService.mainAppService;
  if(enabled && service.status!=SMAppServiceStatusEnabled)[service registerAndReturnError:&error];
  if(!enabled && service.status!=SMAppServiceStatusNotRegistered)[service unregisterAndReturnError:&error];
  NSString *message=error.localizedDescription;
  if(enabled && service.status==SMAppServiceStatusRequiresApproval)message=@"Autorize o Weather Wallpaper em Ajustes do Sistema → Geral → Itens de Início.";
  dispatch_async(dispatch_get_main_queue(),^{completion(message);});
 });
}
- (void)setWallpaper:(BOOL)enabled {
 NSWindow *window=self.window;if(!window || enabled==_wallpaper)return;
 if(enabled) {
  self.previewFrame=window.frame;self.previewStyle=window.styleMask;
  window.styleMask=NSWindowStyleMaskBorderless;window.level=CGWindowLevelForKey(kCGDesktopIconWindowLevelKey)-1;
  window.collectionBehavior=NSWindowCollectionBehaviorCanJoinAllSpaces|NSWindowCollectionBehaviorStationary|NSWindowCollectionBehaviorIgnoresCycle|NSWindowCollectionBehaviorFullScreenAuxiliary;
  window.ignoresMouseEvents=YES;window.hasShadow=NO;
  [window setFrame:(window.screen ?: NSScreen.mainScreen).frame display:YES];[window orderBack:nil];
 } else {
  window.level=NSNormalWindowLevel;window.ignoresMouseEvents=NO;window.hasShadow=YES;
  window.collectionBehavior=NSWindowCollectionBehaviorDefault;window.styleMask=self.previewStyle;
  [window setFrame:self.previewFrame display:YES];[NSApplication.sharedApplication activateIgnoringOtherApps:YES];[window makeKeyAndOrderFront:nil];
 }
 _wallpaper=enabled;
}
- (void)screenChanged:(NSNotification *)note {
 if(self.wallpaper)[self.window setFrame:(self.window.screen ?: NSScreen.mainScreen).frame display:YES];
 // Let AppKit/Catalyst finish backing-scale and bounds changes first.
 [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(refreshDisplayGeometry) object:nil];
 [self performSelector:@selector(refreshDisplayGeometry) withObject:nil afterDelay:0.25];
}
- (void)refreshDisplayGeometry {[self.controller displayGeometryChanged];}
- (void)woke:(NSNotification *)note {[self.controller refreshAfterWake];}
- (void)handleReopen:(NSAppleEventDescriptor *)event reply:(NSAppleEventDescriptor *)reply {[self showPreferences];}
- (void)showPreview {if(self.wallpaper)[self showPreferences];else [self.controller showPreview];}
- (void)showPreferences {
 if(!self.settingsWindow)[self buildSettingsWindow];
 [self refreshSettings];
 [NSApplication.sharedApplication activateIgnoringOtherApps:YES];
 [self.settingsWindow makeKeyAndOrderFront:nil];
 [self.settingsWindow makeFirstResponder:nil];
}
- (NSTextField *)settingsLabel:(NSString *)text size:(CGFloat)size weight:(NSFontWeight)weight {
 NSTextField *label=[NSTextField wrappingLabelWithString:text];label.font=[NSFont systemFontOfSize:size weight:weight];return label;
}
- (NSStackView *)settingsRow:(NSString *)title control:(NSView *)control {
 NSTextField *label=[self settingsLabel:title size:15 weight:NSFontWeightRegular];
 NSView *space=[NSView new];[space setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
 NSStackView *row=[NSStackView stackViewWithViews:@[label,space,control]];row.orientation=NSUserInterfaceLayoutOrientationHorizontal;row.alignment=NSLayoutAttributeCenterY;
 [control setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
 [row.heightAnchor constraintGreaterThanOrEqualToConstant:30].active=YES;return row;
}
- (NSSwitch *)settingsSwitch:(NSString *)label action:(SEL)action {
 NSSwitch *control=[NSSwitch new];control.target=self;control.action=action;control.accessibilityLabel=label;return control;
}
- (NSView *)playbackSettingsView {return nil;}
- (void)styleSettingsButton:(NSButton *)button {
 button.controlSize=NSControlSizeRegular;button.font=[NSFont systemFontOfSize:15];
 if(@available(macOS 26.0,*))button.bezelStyle=NSBezelStyleGlass;
 else button.bezelStyle=NSBezelStylePush;
}
- (NSView *)settingsSection:(NSString *)title content:(NSView *)content {
 NSTextField *label=[self settingsLabel:title size:15 weight:NSFontWeightSemibold];
 NSStackView *section=[NSStackView stackViewWithViews:@[label,content]];
 section.orientation=NSUserInterfaceLayoutOrientationVertical;section.alignment=NSLayoutAttributeLeading;section.spacing=6;
 [content.widthAnchor constraintEqualToAnchor:section.widthAnchor].active=YES;return section;
}
- (NSView *)settingsCard:(NSArray<NSView *> *)views {
 NSBox *card=[NSBox new];card.boxType=NSBoxCustom;card.titlePosition=NSNoTitle;card.cornerRadius=12;card.borderWidth=0.5;
 card.borderColor=[NSColor.separatorColor colorWithAlphaComponent:0.25];card.fillColor=NSColor.controlBackgroundColor;
 NSMutableArray<NSView *> *rows=[NSMutableArray new];
 for(NSView *view in views){
  if(rows.count){NSBox *divider=[NSBox new];divider.boxType=NSBoxSeparator;[divider bind:NSHiddenBinding toObject:view withKeyPath:@"hidden" options:nil];[rows addObject:divider];}
  [rows addObject:view];
 }
 NSStackView *stack=[NSStackView stackViewWithViews:rows];stack.orientation=NSUserInterfaceLayoutOrientationVertical;stack.alignment=NSLayoutAttributeLeading;stack.spacing=6;stack.translatesAutoresizingMaskIntoConstraints=NO;
 [card addSubview:stack];[NSLayoutConstraint activateConstraints:@[[stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14],[stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-14],[stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:8],[stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-8]]];
 for(NSView *view in rows)[view.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active=YES;
 return card;
}
- (void)buildSettingsWindow {
 CGFloat available=NSScreen.mainScreen.visibleFrame.size.height;
 NSPanel *window=[[NSPanel alloc] initWithContentRect:NSMakeRect(0,0,580,MIN(720,available-70)) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable|NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:NO];
 window.title=@"Configurações";window.titlebarAppearsTransparent=YES;
 window.releasedWhenClosed=NO;window.hidesOnDeactivate=NO;window.movableByWindowBackground=YES;
 window.contentMinSize=NSMakeSize(540,480);window.backgroundColor=NSColor.windowBackgroundColor;
 window.collectionBehavior=NSWindowCollectionBehaviorMoveToActiveSpace|NSWindowCollectionBehaviorFullScreenAuxiliary;
 NSScrollView *scroll=[NSScrollView new];scroll.hasVerticalScroller=YES;scroll.autohidesScrollers=YES;scroll.drawsBackground=NO;scroll.borderType=NSNoBorder;
 window.contentView=scroll;
 WeatherSettingsDocument *document=[WeatherSettingsDocument new];document.translatesAutoresizingMaskIntoConstraints=NO;scroll.documentView=document;
 [NSLayoutConstraint activateConstraints:@[[document.leadingAnchor constraintEqualToAnchor:scroll.contentView.leadingAnchor],[document.trailingAnchor constraintEqualToAnchor:scroll.contentView.trailingAnchor],[document.topAnchor constraintEqualToAnchor:scroll.contentView.topAnchor],[document.widthAnchor constraintEqualToAnchor:scroll.contentView.widthAnchor]]];
 NSStackView *stack=[NSStackView new];stack.orientation=NSUserInterfaceLayoutOrientationVertical;stack.alignment=NSLayoutAttributeLeading;stack.spacing=12;stack.translatesAutoresizingMaskIntoConstraints=NO;[document addSubview:stack];
 [NSLayoutConstraint activateConstraints:@[[stack.leadingAnchor constraintEqualToAnchor:document.leadingAnchor constant:20],[stack.trailingAnchor constraintEqualToAnchor:document.trailingAnchor constant:-20],[stack.topAnchor constraintEqualToAnchor:document.topAnchor constant:16],[stack.bottomAnchor constraintEqualToAnchor:document.bottomAnchor constant:-16]]];
 void(^add)(NSView *)=^(NSView *view){[stack addArrangedSubview:view];[view.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active=YES;};
 self.settingsCity=[self settingsLabel:@"" size:20 weight:NSFontWeightSemibold];
 self.settingsSummary=[self settingsLabel:@"" size:14 weight:NSFontWeightRegular];self.settingsSummary.textColor=NSColor.secondaryLabelColor;
 NSStackView *location=[NSStackView stackViewWithViews:@[self.settingsCity,self.settingsSummary]];location.orientation=NSUserInterfaceLayoutOrientationVertical;location.alignment=NSLayoutAttributeLeading;location.spacing=4;
 self.settingsSearch=[NSSearchField new];self.settingsSearch.placeholderString=@"Buscar outra cidade";self.settingsSearch.accessibilityLabel=@"Buscar cidade";self.settingsSearch.target=self;self.settingsSearch.action=@selector(searchSettingsCity:);self.settingsSearch.sendsSearchStringImmediately=NO;self.settingsSearch.sendsWholeSearchString=YES;
 self.searchButton=[NSButton buttonWithTitle:@"Buscar" target:self action:@selector(searchSettingsCity:)];self.searchButton.bezelStyle=NSBezelStyleRounded;
 NSStackView *search=[NSStackView stackViewWithViews:@[self.settingsSearch,self.searchButton]];search.spacing=10;[self.settingsSearch.heightAnchor constraintGreaterThanOrEqualToConstant:30].active=YES;
 self.cityResults=[[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];self.cityResults.target=self;self.cityResults.action=@selector(selectSettingsCity:);self.cityResults.hidden=YES;self.cityResults.accessibilityLabel=@"Resultados da busca";
 self.weatherControl=[[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];self.weatherControl.target=self;self.weatherControl.action=@selector(weatherChanged:);self.weatherControl.accessibilityLabel=@"Clima";
 NSArray *weather=@[@[@"Automático da cidade",@"automatic"],@[@"Céu limpo",@"clear"],@[@"Predominantemente limpo",@"mostlyClear"],@[@"Parcialmente nublado",@"partlyCloudy"],@[@"Muito nublado",@"mostlyCloudy"],@[@"Nublado",@"cloudy"],@[@"Garoa",@"drizzle"],@[@"Chuva",@"rain"],@[@"Chuva forte",@"heavyRain"],@[@"Tempestade",@"thunderstorms"],@[@"Neve",@"snow"],@[@"Neve intensa",@"heavySnow"],@[@"Neblina",@"foggy"],@[@"Granizo",@"hail"],@[@"Chuva congelante",@"freezingRain"],@[@"Garoa congelante",@"freezingDrizzle"],@[@"Vento",@"windy"]];
 for(NSArray *entry in weather){[self.weatherControl addItemWithTitle:entry[0]];self.weatherControl.lastItem.representedObject=entry[1];}
 self.timeControl=[[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];[self.timeControl addItemsWithTitles:@[@"Dia",@"Entardecer",@"Noite"]];self.timeControl.target=self;self.timeControl.action=@selector(timeChanged:);self.timeControl.accessibilityLabel=@"Período do clima manual";
 self.qualityControl=[[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];[self.qualityControl addItemsWithTitles:@[@"Alta · 60 fps",@"Econômica · 30 fps"]];self.qualityControl.target=self;self.qualityControl.action=@selector(qualityChanged:);self.qualityControl.accessibilityLabel=@"Qualidade da animação";
 for(NSPopUpButton *control in @[self.weatherControl,self.timeControl,self.qualityControl])[control.widthAnchor constraintEqualToConstant:260].active=YES;
 add([self settingsSection:@"Clima e localização" content:[self settingsCard:@[location,search,self.cityResults,[self settingsRow:@"Clima" control:self.weatherControl],[self settingsRow:@"Período" control:self.timeControl]]]]);
 NSView *playback=[self playbackSettingsView];
 if(playback)add(playback);
 self.qualityCard=[self settingsCard:@[[self settingsRow:@"Qualidade" control:self.qualityControl]]];add(self.qualityCard);
 self.loginControl=[self settingsSwitch:@"Iniciar com o Mac" action:@selector(loginChanged:)];
 self.menuControl=[self settingsSwitch:@"Ícone na barra de menus" action:@selector(menuChanged:)];
 self.dockControl=[self settingsSwitch:@"Ícone no Dock" action:@selector(dockChanged:)];
 add([self settingsSection:@"Geral" content:[self settingsCard:@[[self settingsRow:@"Iniciar com o Mac" control:self.loginControl],[self settingsRow:@"Ícone na barra de menus" control:self.menuControl],[self settingsRow:@"Ícone no Dock" control:self.dockControl]]]]);
 self.pauseControl=[NSButton buttonWithTitle:@"Pausar animação" target:self action:@selector(pauseFromSettings:)];self.pauseControl.bezelStyle=NSBezelStyleRounded;
 NSButton *refresh=[NSButton buttonWithTitle:@"Atualizar clima" target:self action:@selector(refreshFromSettings:)];refresh.bezelStyle=NSBezelStyleRounded;
 NSStackView *buttons=[NSStackView stackViewWithViews:@[refresh,self.pauseControl]];buttons.spacing=12;add(buttons);
 self.settingsStatus=[self settingsLabel:self.settingsMessageText ?: @"" size:14 weight:NSFontWeightRegular];self.settingsStatus.textColor=NSColor.secondaryLabelColor;self.settingsStatus.hidden=self.settingsMessageText.length==0;add(self.settingsStatus);
 NSTextField *hint=[self settingsLabel:@"⌘⇧P abre estas configurações a qualquer momento" size:13 weight:NSFontWeightRegular];hint.textColor=NSColor.secondaryLabelColor;add(hint);
 for(NSControl *control in @[self.settingsSearch,self.searchButton,self.cityResults,self.weatherControl,self.timeControl,self.qualityControl,self.pauseControl,refresh]){control.font=[NSFont systemFontOfSize:15];control.controlSize=NSControlSizeRegular;}
 for(NSButton *button in @[self.searchButton,self.pauseControl,refresh])[self styleSettingsButton:button];
 self.settingsWindow=window;[window center];[window setFrameAutosaveName:@"WeatherWallpaperCompactSettings"];
}
- (void)refreshSettings {
 if(!self.settingsWindow)return;
 NSDictionary *state=[self.controller settingsState];
 self.settingsCity.stringValue=state[@"city"] ?: @"Escolha uma cidade";self.settingsSummary.stringValue=state[@"summary"] ?: @"";
 NSString *condition=[state[@"automatic"] boolValue] ? @"automatic" : state[@"condition"];
 for(NSMenuItem *item in self.weatherControl.itemArray)if([item.representedObject isEqual:condition]){[self.weatherControl selectItem:item];break;}
 self.timeControl.enabled=![state[@"automatic"] boolValue];[self.timeControl selectItemAtIndex:[state[@"previewTime"] integerValue]];
 self.dockControl.state=self.dockVisible ? NSControlStateValueOn : NSControlStateValueOff;
 [self.qualityControl selectItemAtIndex:[state[@"highQuality"] boolValue] ? 0 : 1];
 NSInteger login=[self loginItemStatus];self.loginControl.state=(login==SMAppServiceStatusEnabled || login==SMAppServiceStatusRequiresApproval) ? NSControlStateValueOn : NSControlStateValueOff;self.loginControl.enabled=!self.changingLogin;
 self.menuControl.state=self.menuBarVisible ? NSControlStateValueOn : NSControlStateValueOff;
 self.pauseControl.title=[state[@"paused"] boolValue] ? @"Continuar animação" : @"Pausar animação";
}
- (void)settingsMessage:(NSString *)message {self.settingsMessageText=message;self.settingsStatus.stringValue=message ?: @"";self.settingsStatus.hidden=message.length==0;}
- (void)weatherChanged:(NSPopUpButton *)sender {
 NSString *condition=sender.selectedItem.representedObject;
 if([condition isEqual:@"automatic"])[self.controller setAutomaticWeatherEnabled:YES];else [self.controller selectCondition:condition];
 [self refreshSettings];
}
- (void)timeChanged:(NSPopUpButton *)sender {[self.controller setPreviewTime:sender.indexOfSelectedItem];[self refreshSettings];}
- (void)dockChanged:(NSSwitch *)sender {[self setDockVisible:sender.state==NSControlStateValueOn];[self refreshSettings];}
- (void)qualityChanged:(NSPopUpButton *)sender {[self.controller setHighQualityRendering:sender.indexOfSelectedItem==0];[self refreshSettings];}
- (void)menuChanged:(NSSwitch *)sender {[self setMenuBarVisible:sender.state==NSControlStateValueOn];}
- (void)loginChanged:(NSSwitch *)sender {
 self.changingLogin=YES;sender.enabled=NO;__weak typeof(self) weakSelf=self;
 [self setLaunchAtLogin:sender.state==NSControlStateValueOn completion:^(NSString *error){weakSelf.changingLogin=NO;[weakSelf settingsMessage:error];[weakSelf refreshSettings];}];
}
- (void)pauseFromSettings:(id)sender {[self.controller togglePause];[self refreshSettings];}
- (void)refreshFromSettings:(id)sender {[self.controller refreshWeatherNow];[self settingsMessage:nil];[self refreshSettings];}
- (void)searchSettingsCity:(id)sender {
 NSString *query=[self.settingsSearch.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
 if(query.length<2){[self settingsMessage:@"Digite o nome da cidade."];return;}
 NSUInteger generation=++self.searchGeneration;self.searchButton.enabled=NO;self.cityResults.hidden=YES;[self settingsMessage:@"Buscando…"];__weak typeof(self) weakSelf=self;
 [self.controller searchCities:query completion:^(NSArray<NSDictionary *> *cities,NSString *error){
  if(!weakSelf || generation!=weakSelf.searchGeneration)return;
  weakSelf.searchButton.enabled=YES;[weakSelf.cityResults removeAllItems];
  if(error || !cities.count){[weakSelf settingsMessage:error ?: @"Nenhuma cidade encontrada."];return;}
  [weakSelf.cityResults addItemWithTitle:@"Selecione a cidade…"];
  for(NSDictionary *city in cities){[weakSelf.cityResults addItemWithTitle:[NSString stringWithFormat:@"%@ · %@, %@",city[@"name"],city[@"admin1"] ?: @"",city[@"country"] ?: @""]];weakSelf.cityResults.lastItem.representedObject=city;}
  weakSelf.cityResults.hidden=NO;[weakSelf settingsMessage:nil];
 }];
}
- (void)selectSettingsCity:(NSPopUpButton *)sender {
 NSDictionary *city=sender.selectedItem.representedObject;if(!city)return;
 [self.controller selectCity:city];self.cityResults.hidden=YES;self.settingsSearch.stringValue=@"";[self refreshSettings];
}
- (void)useWallpaper {[self.controller useWallpaper];}
- (void)togglePause {[self.controller togglePause];}
- (void)quit {[NSApplication.sharedApplication terminate:nil];}
- (void)dealloc {
 [NSNotificationCenter.defaultCenter removeObserver:self];[NSWorkspace.sharedWorkspace.notificationCenter removeObserver:self];
 if(self.hotKey)UnregisterEventHotKey(self.hotKey);if(self.hotKeyHandler)RemoveEventHandler(self.hotKeyHandler);
 [NSAppleEventManager.sharedAppleEventManager removeEventHandlerForEventClass:kCoreEventClass andEventID:kAEReopenApplication];
 if(self.status)[NSStatusBar.systemStatusBar removeStatusItem:self.status];
}
@end
