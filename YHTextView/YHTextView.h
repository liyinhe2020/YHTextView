//
//  YHTextView.h
//  YHTextView
//
//  Created by  李银河 on 2022/5/18.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol YHTextViewDelegate <UITextViewDelegate>
@optional
- (void)textViewWordCountDidChange:(UITextView *)textView;
@end

@protocol YHTextViewFormat <NSObject>

- (BOOL)formatText:(nullable NSMutableAttributedString *)text selectedRange:(nullable NSRangePointer)selectedRange;

@end

@interface YHTextView : UITextView
//扩展的UITextView代理
@property (nullable, nonatomic, weak) id<YHTextViewDelegate> delegate;

//占位文本
@property (nullable, nonatomic, copy) IBInspectable NSString *placeholder;
//占位文本颜色
@property (null_resettable, nonatomic, strong) IBInspectable UIColor *placeholderColor;
//占位富文本
@property (nullable, nonatomic, copy) NSAttributedString *attributedPlaceholder;

//文本格式化
@property (nullable, nonatomic, strong) id<YHTextViewFormat> textFormat;
//最大输入数
@property (nonatomic) NSUInteger limitWords;
//字间距
@property (nonatomic) CGFloat wordsKern;
@property (nonatomic) CGFloat lineSpacing;
@property (nonatomic) CGFloat paragraphSpacing;
@property (nonatomic) NSTextAlignment alignment;
@property (nonatomic) CGFloat firstLineHeadIndent;
@property (nonatomic) CGFloat headIndent;
@property (nonatomic) CGFloat tailIndent;
@property (nonatomic) NSLineBreakMode lineBreakMode;
@property (nonatomic) CGFloat minimumLineHeight;
@property (nonatomic) CGFloat maximumLineHeight;
@property (nonatomic) NSWritingDirection baseWritingDirection;
@property (nonatomic) CGFloat lineHeightMultiple;
@property (nonatomic) CGFloat paragraphSpacingBefore;
@property (nonatomic) float hyphenationFactor;

@end

NS_ASSUME_NONNULL_END
