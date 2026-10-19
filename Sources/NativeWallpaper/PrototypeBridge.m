#import "../DesktopBridge.m"
@interface NSObject (PlaybackMode)
- (void)setContinuousWallpaperEnabled:(BOOL)enabled;
@end
@interface NativeDesktopBridge : DesktopBridge
@property(nonatomic,strong) NSButton *continuousChoice,*lockedChoice;
@end
@implementation NativeDesktopBridge
- (NSView *)modeOption:(BOOL)continuous {
 NSButton *choice=[NSButton radioButtonWithTitle:continuous ? @"Sempre animado" : @"Ao bloquear" target:self action:@selector(playbackChanged:)];choice.tag=continuous;choice.font=[NSFont systemFontOfSize:15];choice.controlSize=NSControlSizeRegular;
 NSTextField *description=[self settingsLabel:continuous ? @"Animação em tempo real na área de trabalho." : @"Animação no bloqueio e na proteção de tela. Economiza energia durante o uso do Mac." size:13 weight:NSFontWeightRegular];description.textColor=NSColor.secondaryLabelColor;
 NSStackView *option=[NSStackView stackViewWithViews:@[choice,description]];option.orientation=NSUserInterfaceLayoutOrientationVertical;option.alignment=NSLayoutAttributeLeading;option.spacing=3;
 [description.widthAnchor constraintEqualToAnchor:option.widthAnchor].active=YES;
 if(continuous)self.continuousChoice=choice;else self.lockedChoice=choice;
 return option;
}
- (NSView *)playbackSettingsView {
 NSView *options=[self settingsCard:@[[self modeOption:YES],[self modeOption:NO]]];
 NSButton *configure=[NSButton buttonWithTitle:@"Ajustes de Papel de Parede…" target:self action:@selector(openNativeWallpaperSettings)];[self styleSettingsButton:configure];
 NSStackView *content=[NSStackView stackViewWithViews:@[options,configure]];content.orientation=NSUserInterfaceLayoutOrientationVertical;content.alignment=NSLayoutAttributeTrailing;content.spacing=8;[options.widthAnchor constraintEqualToAnchor:content.widthAnchor].active=YES;
 return [self settingsSection:@"Animação" content:content];
}
- (void)buildSettingsWindow {[super buildSettingsWindow];self.settingsWindow.title=@"Weather Wallpaper";}
- (void)refreshSettings {
 [super refreshSettings];if(!self.settingsWindow)return;
 NSDictionary *state=[self.controller settingsState];BOOL continuous=[state[@"continuous"] boolValue];
 self.continuousChoice.state=continuous;self.lockedChoice.state=!continuous;
 self.qualityCard.hidden=!continuous;self.pauseControl.hidden=!continuous;self.pauseControl.enabled=![state[@"preparing"] boolValue];
}
- (void)playbackChanged:(NSButton *)sender {[(id)self.controller setContinuousWallpaperEnabled:sender.tag==1];[self refreshSettings];}
- (void)setLiveDesktopEnabled:(BOOL)enabled {[self setWallpaper:enabled];if(!enabled)[self hideNativeRenderWindow];}
- (void)openNativeWallpaperSettings {[NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.Wallpaper-Settings.extension"]];}
- (void)hideNativeRenderWindow {[self.window orderOut:nil];}
@end
