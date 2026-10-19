#import <AppKit/AppKit.h>
#import <ServiceManagement/ServiceManagement.h>
#import <Carbon/Carbon.h>

@protocol WeatherControls <NSObject>
- (void)showPreview;
- (void)showPreferences;
- (void)useWallpaper;
- (void)togglePause;
- (void)refreshAfterWake;
- (NSDictionary *)settingsState;
- (void)setAutomaticWeatherEnabled:(BOOL)enabled;
- (void)setHighQualityRendering:(BOOL)enabled;
- (void)refreshWeatherNow;
- (void)searchCities:(NSString *)query completion:(void(^)(NSArray<NSDictionary *> *,NSString *))completion;
- (void)selectCity:(NSDictionary *)city;
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
@property(nonatomic,strong) NSSwitch *automaticControl,*loginControl,*menuControl;
@property(nonatomic,strong) NSPopUpButton *qualityControl,*cityResults;
@property(nonatomic) NSUInteger searchGeneration;
- (void)setWallpaper:(BOOL)enabled;
- (void)showPreview;
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
  [NSApplication.sharedApplication setActivationPolicy:NSApplicationActivationPolicyAccessory];
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
  [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self selector:@selector(woke:) name:NSWorkspaceDidWakeNotification object:nil];
 }
 return self;
}
- (BOOL)menuBarVisible {return self.status.visible;}
- (void)setMenuBarVisible:(BOOL)visible {
 self.status.visible=visible;[NSUserDefaults.standardUserDefaults setBool:!visible forKey:@"HideMenuBarIcon"];
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
- (void)screenChanged:(NSNotification *)note {if(self.wallpaper)[self.window setFrame:(self.window.screen ?: NSScreen.mainScreen).frame display:YES];}
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
 NSTextField *label=[self settingsLabel:title size:13 weight:NSFontWeightRegular];
 NSView *space=[NSView new];[space setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
 NSStackView *row=[NSStackView stackViewWithViews:@[label,space,control]];row.orientation=NSUserInterfaceLayoutOrientationHorizontal;row.alignment=NSLayoutAttributeCenterY;
 [control setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
 [row.heightAnchor constraintGreaterThanOrEqualToConstant:28].active=YES;return row;
}
- (NSSwitch *)settingsSwitch:(NSString *)label action:(SEL)action {
 NSSwitch *control=[NSSwitch new];control.target=self;control.action=action;control.accessibilityLabel=label;return control;
}
- (void)buildSettingsWindow {
 NSPanel *window=[[NSPanel alloc] initWithContentRect:NSMakeRect(0,0,420,480) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskFullSizeContentView backing:NSBackingStoreBuffered defer:NO];
 window.title=@"Configurações";window.titlebarAppearsTransparent=YES;window.titleVisibility=NSWindowTitleHidden;
 window.releasedWhenClosed=NO;window.hidesOnDeactivate=NO;window.opaque=NO;window.backgroundColor=NSColor.clearColor;window.movableByWindowBackground=YES;
 window.collectionBehavior=NSWindowCollectionBehaviorMoveToActiveSpace|NSWindowCollectionBehaviorFullScreenAuxiliary;
 window.appearance=[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
 NSView *content=[NSView new];
 if(@available(macOS 26.0,*)) {
  NSGlassEffectView *glass=[NSGlassEffectView new];glass.style=NSGlassEffectViewStyleRegular;glass.cornerRadius=24;glass.contentView=content;
  if(@available(macOS 27.0,*))glass.effectIsInteractive=YES;
  window.contentView=glass;
 } else {
  NSVisualEffectView *glass=[NSVisualEffectView new];glass.material=NSVisualEffectMaterialHUDWindow;glass.blendingMode=NSVisualEffectBlendingModeBehindWindow;glass.state=NSVisualEffectStateActive;[glass addSubview:content];window.contentView=glass;
  content.translatesAutoresizingMaskIntoConstraints=NO;[NSLayoutConstraint activateConstraints:@[[content.leadingAnchor constraintEqualToAnchor:glass.leadingAnchor],[content.trailingAnchor constraintEqualToAnchor:glass.trailingAnchor],[content.topAnchor constraintEqualToAnchor:glass.topAnchor],[content.bottomAnchor constraintEqualToAnchor:glass.bottomAnchor]]];
 }
 NSStackView *stack=[NSStackView new];stack.orientation=NSUserInterfaceLayoutOrientationVertical;stack.alignment=NSLayoutAttributeLeading;stack.spacing=12;stack.translatesAutoresizingMaskIntoConstraints=NO;[content addSubview:stack];
 [NSLayoutConstraint activateConstraints:@[[stack.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:28],[stack.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-28],[stack.topAnchor constraintEqualToAnchor:content.topAnchor constant:52],[stack.bottomAnchor constraintLessThanOrEqualToAnchor:content.bottomAnchor constant:-24]]];
 [stack addArrangedSubview:[self settingsLabel:@"Configurações" size:24 weight:NSFontWeightSemibold]];
 self.settingsCity=[self settingsLabel:@"" size:15 weight:NSFontWeightMedium];[stack addArrangedSubview:self.settingsCity];
 self.settingsSummary=[self settingsLabel:@"" size:12 weight:NSFontWeightRegular];self.settingsSummary.textColor=NSColor.secondaryLabelColor;[stack addArrangedSubview:self.settingsSummary];
 self.settingsSearch=[NSSearchField new];self.settingsSearch.placeholderString=@"Buscar cidade";self.settingsSearch.target=self;self.settingsSearch.action=@selector(searchSettingsCity:);self.settingsSearch.sendsSearchStringImmediately=NO;self.settingsSearch.sendsWholeSearchString=YES;
 self.searchButton=[NSButton buttonWithTitle:@"Buscar" target:self action:@selector(searchSettingsCity:)];self.searchButton.bezelStyle=NSBezelStyleRounded;
 NSStackView *search=[NSStackView stackViewWithViews:@[self.settingsSearch,self.searchButton]];search.spacing=8;[stack addArrangedSubview:search];[search.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active=YES;
 self.cityResults=[[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];self.cityResults.target=self;self.cityResults.action=@selector(selectSettingsCity:);self.cityResults.hidden=YES;self.cityResults.accessibilityLabel=@"Resultados da busca";[stack addArrangedSubview:self.cityResults];
 self.automaticControl=[self settingsSwitch:@"Atualizar clima automaticamente" action:@selector(automaticChanged:)];
 self.qualityControl=[[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];[self.qualityControl addItemsWithTitles:@[@"Alta · 60 fps",@"Econômica · 30 fps"]];self.qualityControl.target=self;self.qualityControl.action=@selector(qualityChanged:);self.qualityControl.accessibilityLabel=@"Qualidade da animação";
 self.loginControl=[self settingsSwitch:@"Iniciar com o Mac" action:@selector(loginChanged:)];
 self.menuControl=[self settingsSwitch:@"Ícone na barra de menus" action:@selector(menuChanged:)];
 for(NSView *row in @[[self settingsRow:@"Clima automático" control:self.automaticControl],[self settingsRow:@"Qualidade" control:self.qualityControl],[self settingsRow:@"Iniciar com o Mac" control:self.loginControl],[self settingsRow:@"Ícone na barra de menus" control:self.menuControl]]){[stack addArrangedSubview:row];[row.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active=YES;}
 self.pauseControl=[NSButton buttonWithTitle:@"Pausar animação" target:self action:@selector(pauseFromSettings:)];self.pauseControl.bezelStyle=NSBezelStyleRounded;
 NSButton *refresh=[NSButton buttonWithTitle:@"Atualizar agora" target:self action:@selector(refreshFromSettings:)];refresh.bezelStyle=NSBezelStyleRounded;
 NSStackView *buttons=[NSStackView stackViewWithViews:@[self.pauseControl,refresh]];buttons.spacing=8;[stack addArrangedSubview:buttons];
 self.settingsStatus=[self settingsLabel:@"" size:11 weight:NSFontWeightRegular];self.settingsStatus.textColor=NSColor.secondaryLabelColor;self.settingsStatus.hidden=YES;[stack addArrangedSubview:self.settingsStatus];
 NSTextField *hint=[self settingsLabel:@"⌘⇧P para reabrir os controles" size:11 weight:NSFontWeightRegular];hint.textColor=NSColor.tertiaryLabelColor;[stack addArrangedSubview:hint];
 self.settingsWindow=window;[window center];
}
- (void)refreshSettings {
 if(!self.settingsWindow)return;
 NSDictionary *state=[self.controller settingsState];
 self.settingsCity.stringValue=state[@"city"] ?: @"Escolha uma cidade";self.settingsSummary.stringValue=state[@"summary"] ?: @"";
 self.automaticControl.state=[state[@"automatic"] boolValue] ? NSControlStateValueOn : NSControlStateValueOff;
 [self.qualityControl selectItemAtIndex:[state[@"highQuality"] boolValue] ? 0 : 1];
 NSInteger login=[self loginItemStatus];self.loginControl.state=(login==SMAppServiceStatusEnabled || login==SMAppServiceStatusRequiresApproval) ? NSControlStateValueOn : NSControlStateValueOff;self.loginControl.enabled=!self.changingLogin;
 self.menuControl.state=self.menuBarVisible ? NSControlStateValueOn : NSControlStateValueOff;
 self.pauseControl.title=[state[@"paused"] boolValue] ? @"Continuar animação" : @"Pausar animação";
}
- (void)settingsMessage:(NSString *)message {self.settingsStatus.stringValue=message ?: @"";self.settingsStatus.hidden=message.length==0;}
- (void)automaticChanged:(NSSwitch *)sender {[self.controller setAutomaticWeatherEnabled:sender.state==NSControlStateValueOn];[self refreshSettings];}
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
