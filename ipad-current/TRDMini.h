@interface TRDMini:UIView
@property UILabel *title,*artist;
@property UIButton *prev,*play,*next,*open;
@property DashIcon *icon,*prevIcon,*nextIcon;
@end
@implementation TRDMini
-(id)init{if((self=[super init])){
 self.backgroundColor=[UIColor colorWithWhite:.07 alpha:1];
 self.layer.cornerRadius=8;
 self.layer.borderWidth=1;
 self.layer.borderColor=[UIColor colorWithWhite:.2 alpha:1].CGColor;
 self.title=[UILabel new];self.title.font=[UIFont boldSystemFontOfSize:17];self.title.textColor=[UIColor whiteColor];[self addSubview:self.title];
 self.artist=[UILabel new];self.artist.font=[UIFont systemFontOfSize:12];self.artist.textColor=[UIColor lightGrayColor];[self addSubview:self.artist];
 self.prev=[UIButton buttonWithType:UIButtonTypeCustom];self.prev.accessibilityLabel=@"Previous";
 self.prevIcon=[DashIcon new];self.prevIcon.backgroundColor=[UIColor clearColor];self.prevIcon.userInteractionEnabled=NO;self.prevIcon.kind=7;
 [self.prev addSubview:self.prevIcon];[self addSubview:self.prev];
 self.play=[UIButton buttonWithType:UIButtonTypeCustom];self.play.accessibilityLabel=@"Play or pause";
 self.icon=[DashIcon new];self.icon.backgroundColor=[UIColor clearColor];self.icon.userInteractionEnabled=NO;self.icon.kind=8;
 [self.play addSubview:self.icon];[self addSubview:self.play];
 self.next=[UIButton buttonWithType:UIButtonTypeCustom];self.next.accessibilityLabel=@"Next";
 self.nextIcon=[DashIcon new];self.nextIcon.backgroundColor=[UIColor clearColor];self.nextIcon.userInteractionEnabled=NO;self.nextIcon.kind=9;
 [self.next addSubview:self.nextIcon];[self addSubview:self.next];
 self.open=[UIButton buttonWithType:UIButtonTypeCustom];[self.open setTitle:@"MUSIC ›" forState:0];self.open.titleLabel.font=[UIFont boldSystemFontOfSize:13];[self.open setTitleColor:TRDAccent() forState:0];[self addSubview:self.open];
}return self;}
-(void)layoutSubviews{
 CGFloat w=self.bounds.size.width;
 self.title.frame=CGRectMake(16,11,MAX(20,w-260),24);
 self.artist.frame=CGRectMake(16,37,MAX(20,w-260),18);
 self.prev.frame=CGRectMake(w-240,5,44,62);
 self.prevIcon.frame=CGRectMake(7,16,30,30);
 self.play.frame=CGRectMake(w-192,5,52,62);
 self.icon.frame=CGRectMake(7,12,38,38);
 self.next.frame=CGRectMake(w-136,5,44,62);
 self.nextIcon.frame=CGRectMake(7,16,30,30);
 self.open.frame=CGRectMake(w-88,5,80,62);
}
@end
