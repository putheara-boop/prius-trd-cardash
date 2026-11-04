#import <UIKit/UIKit.h>
@class TRDSettingAction;
typedef void (^TRDSettingHandler)(TRDSettingAction *);
@interface TRDSettingAction:NSObject
@property NSString *title;
@property NSInteger style;
@property(copy) TRDSettingHandler handler;
+(instancetype)actionWithTitle:(NSString *)title style:(NSInteger)style handler:(TRDSettingHandler)handler;
@end
@implementation TRDSettingAction
+(instancetype)actionWithTitle:(NSString *)title style:(NSInteger)style handler:(TRDSettingHandler)handler{TRDSettingAction *a=[self new];a.title=title;a.style=style;a.handler=handler;return a;}
@end
@interface TRDSettingsMenu:UIView
@property NSString *title,*message;
@property NSMutableArray *actions;
@property UIView *panel,*miniPlayer;
@property UILabel *heading,*detail;
@property UIScrollView *scroll;
@property UIButton *backdrop,*closeButton;
@property NSMutableArray *buttons;
@property(copy) void(^onDismiss)(void);
+(instancetype)alertControllerWithTitle:(NSString *)title message:(NSString *)message preferredStyle:(NSInteger)style;
-(void)addAction:(TRDSettingAction *)action;
-(void)dismiss;
@end
@implementation TRDSettingsMenu
+(instancetype)alertControllerWithTitle:(NSString *)title message:(NSString *)message preferredStyle:(NSInteger)style{TRDSettingsMenu *m=[self new];m.title=title;m.message=message;return m;}
-(instancetype)init{if((self=[super init])){self.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;self.actions=[NSMutableArray array];self.buttons=[NSMutableArray array];self.backgroundColor=[UIColor clearColor];self.backdrop=[UIButton buttonWithType:UIButtonTypeCustom];self.backdrop.backgroundColor=[UIColor colorWithWhite:0 alpha:.76];self.backdrop.accessibilityLabel=@"Close settings";[self.backdrop addTarget:self action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];[self addSubview:self.backdrop];self.panel=[UIView new];self.panel.backgroundColor=[UIColor colorWithWhite:.045 alpha:1];self.panel.layer.cornerRadius=12;self.panel.layer.borderWidth=1;self.panel.layer.borderColor=[TRDAccent() colorWithAlphaComponent:.6].CGColor;[self addSubview:self.panel];self.heading=[UILabel new];self.heading.font=[UIFont boldSystemFontOfSize:24];self.heading.textColor=TRDAccent();[self.panel addSubview:self.heading];self.detail=[UILabel new];self.detail.font=[UIFont systemFontOfSize:14];self.detail.textColor=[UIColor lightGrayColor];self.detail.numberOfLines=3;[self.panel addSubview:self.detail];self.scroll=[UIScrollView new];self.scroll.indicatorStyle=UIScrollViewIndicatorStyleWhite;self.scroll.alwaysBounceVertical=NO;[self.panel addSubview:self.scroll];self.closeButton=[UIButton buttonWithType:UIButtonTypeCustom];[self.closeButton setTitle:@"CLOSE" forState:0];self.closeButton.titleLabel.font=[UIFont boldSystemFontOfSize:17];self.closeButton.backgroundColor=[UIColor colorWithWhite:.11 alpha:1];self.closeButton.layer.cornerRadius=7;self.closeButton.accessibilityLabel=@"Close settings";[self.closeButton addTarget:self action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];[self.panel addSubview:self.closeButton];}return self;}
-(void)addAction:(TRDSettingAction *)a{if(a.style==UIAlertActionStyleCancel)return;[self.actions addObject:a];UIButton *b=[UIButton buttonWithType:UIButtonTypeCustom];b.tag=self.buttons.count;b.backgroundColor=[UIColor colorWithWhite:.085 alpha:1];b.layer.cornerRadius=7;b.layer.borderWidth=1;b.layer.borderColor=[UIColor colorWithWhite:.19 alpha:1].CGColor;[b setTitle:a.title forState:0];b.titleLabel.numberOfLines=2;b.titleLabel.font=[UIFont boldSystemFontOfSize:19];b.contentHorizontalAlignment=UIControlContentHorizontalAlignmentLeft;b.contentEdgeInsets=UIEdgeInsetsMake(8,18,8,18);b.accessibilityLabel=a.title;[b addTarget:self action:@selector(choose:) forControlEvents:UIControlEventTouchUpInside];[self.scroll addSubview:b];[self.buttons addObject:b];}
-(void)layoutSubviews{[super layoutSubviews];self.backdrop.frame=self.bounds;CGFloat w=MIN(700,self.bounds.size.width-48),h=MIN(self.bounds.size.height-72,284+self.buttons.count*72);self.panel.frame=CGRectMake((self.bounds.size.width-w)/2,(self.bounds.size.height-h)/2,w,h);self.heading.text=self.title;self.detail.text=self.message;self.heading.frame=CGRectMake(24,20,w-48,34);self.detail.frame=CGRectMake(24,60,w-48,48);self.scroll.frame=CGRectMake(24,120,w-48,h-280);self.scroll.contentSize=CGSizeMake(w-48,self.buttons.count*72);for(NSUInteger i=0;i<self.buttons.count;i++){UIButton *b=self.buttons[i];b.frame=CGRectMake(0,i*72,w-48,62);}self.miniPlayer.frame=CGRectMake(24,h-148,w-48,72);self.closeButton.frame=CGRectMake(24,h-64,w-48,44);}
-(void)choose:(UIButton *)sender{if(sender.tag<0||sender.tag>=self.actions.count)return;TRDSettingAction *a=self.actions[sender.tag];TRDSettingHandler handler=a.handler;[self dismiss];if(handler)dispatch_async(dispatch_get_main_queue(),^{handler(a);});}
-(void)dismiss{void(^done)(void)=self.onDismiss;self.onDismiss=nil;[self removeFromSuperview];if(done)done();}
@end
