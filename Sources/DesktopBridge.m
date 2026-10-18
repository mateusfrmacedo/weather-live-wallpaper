#import <AppKit/AppKit.h>
#import <ServiceManagement/ServiceManagement.h>
#import <Carbon/Carbon.h>

@protocol WeatherControls <NSObject>
- (void)showPreview;
- (void)showPreferences;
- (void)useWallpaper;
- (void)togglePause;
- (void)refreshAfterWake;
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
@property(nonatomic) BOOL launchedAtLogin;
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
  for(NSArray *entry in @[@[@"Abrir controles",@"showPreview"],@[@"Preferências…",@"showPreferences"],@[@"Usar como wallpaper",@"useWallpaper"],@[@"Pausar / continuar",@"togglePause"],@[@"Sair",@"quit"]]) {
   NSMenuItem *item=[[NSMenuItem alloc] initWithTitle:entry[0] action:NSSelectorFromString(entry[1]) keyEquivalent:@""];item.target=self;[menu addItem:item];
  }
  self.status.menu=menu;
  NSMenuItem *controls=[[NSMenuItem alloc] initWithTitle:@"Abrir controles do wallpaper" action:@selector(showPreview) keyEquivalent:@"p"];
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
- (void)handleReopen:(NSAppleEventDescriptor *)event reply:(NSAppleEventDescriptor *)reply {[self showPreview];}
- (void)showPreview {[self.controller showPreview];}
- (void)showPreferences {[self.controller showPreview];[self.controller showPreferences];}
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
