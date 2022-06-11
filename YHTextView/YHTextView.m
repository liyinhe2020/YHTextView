//
//  YHTextView.m
//  YHTextView
//
//  Created by  李银河 on 2022/5/18.
//

#import "YHTextView.h"


@interface _YHLimitWordsTextFormat : NSObject<YHTextViewFormat>
@property (nonatomic, assign) NSUInteger limitWords;

@end

@implementation _YHLimitWordsTextFormat

- (BOOL)formatText:(NSMutableAttributedString *)text selectedRange:(NSRangePointer)selectedRange {
    if (_limitWords == 0) return NO;
    NSInteger textCount = text.length;
    
    if (textCount > _limitWords) {
        NSRange oldSelected = *selectedRange;
        
        NSInteger deleteWords = textCount - _limitWords;
        NSRange tmpRange = NSMakeRange(oldSelected.location-deleteWords, deleteWords);
        if (tmpRange.location == NSNotFound) return NO;
        tmpRange = [text.string rangeOfComposedCharacterSequencesForRange:tmpRange];
        [text deleteCharactersInRange:tmpRange];
        
        oldSelected.location -= tmpRange.length;
        *selectedRange = oldSelected;
    }
    
    return YES;
}

@end

@interface YHTextView()
//占位符Label
@property (nonatomic, strong) UILabel *placeholderLabel;
@property (nonatomic, assign) BOOL placeholderNeedUpdate;

- (void)_updateIfNeeded;

//字数限制
@property (nonatomic, strong) _YHLimitWordsTextFormat *limitWordsFormat;
@property (nonatomic, assign) BOOL textFormatNeedUpdate;
@property (nonatomic, assign) BOOL delegateFlag_wordsCount;

@property (nonatomic, strong, readwrite) NSMutableParagraphStyle *paragraphStyle;
@end

static NSMutableSet *textViewSet = nil;

static void YHRunLoopCallBack(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info) {
    if (textViewSet.count == 0) return;
    NSSet *currentSet = textViewSet;
    textViewSet = [NSMutableSet new];
    [currentSet enumerateObjectsUsingBlock:^(YHTextView *textView, BOOL *stop) {
        [textView _updateIfNeeded];
    }];
}

static void YHTextViewSetup() {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        textViewSet = [NSMutableSet new];
        CFRunLoopRef runloop = CFRunLoopGetMain();
        CFRunLoopObserverRef observer;
        
        observer = CFRunLoopObserverCreate(CFAllocatorGetDefault(),
                                           kCFRunLoopBeforeWaiting | kCFRunLoopExit,
                                           true,      // repeat
                                           0xFFFFFF,  // after CATransaction(2000000)
                                           YHRunLoopCallBack, NULL);
        CFRunLoopAddObserver(runloop, observer, kCFRunLoopCommonModes);
        CFRelease(observer);
    });
}


@implementation YHTextView
@synthesize delegate = _delegate;

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    
    self.font = [UIFont systemFontOfSize:17];
    self.textColor = [UIColor blackColor];
    
    self.textContainerInset = UIEdgeInsetsZero;
    self.textContainer.lineFragmentPadding = 0;
    
    [self _initPlaceholderLabel];
    [self _configurationEnvironment];
    return self;
}

- (void)setText:(NSString *)text {
    [super setText:text];
    
    [self _showPlaceholderIfNeeded];
}

- (void)setAttributedText:(NSAttributedString *)attributedText {
    [super setAttributedText:attributedText];
    
    [self _showPlaceholderIfNeeded];
}

- (void)setFont:(UIFont *)font {
    if (self.font == font || [self.font isEqual:font]) return;
    
    [super setFont:font];
    _placeholderLabel.font = font;
    [self _setNeedsUpdatePlaceholder];
    [self _setNeedsUpdateTextFormat];
}

- (void)setTextColor:(UIColor *)textColor {
    if (self.textColor == textColor) return;
    if (self.textColor && textColor) {
        if (CFGetTypeID(self.textColor.CGColor) == CFGetTypeID(textColor.CGColor) &&
            CFGetTypeID(self.textColor.CGColor) == CGColorGetTypeID()) {
            if ([self.textColor isEqual:textColor]) {
                return;
            }
        }
    }
    
    [super setTextColor:textColor];
    [self _setNeedsUpdateTextFormat];
}

- (void)setFrame:(CGRect)frame {
    CGSize oldSize = self.bounds.size;
    [super setFrame:frame];
    CGSize newSize = self.bounds.size;
    
    if (!CGSizeEqualToSize(oldSize, newSize)) {
        [self _setNeedsUpdatePlaceholder];
    }
}

- (void)setBounds:(CGRect)bounds {
    CGSize oldSize = self.bounds.size;
    [super setBounds:bounds];
    CGSize newSize = self.bounds.size;
    
    if (!CGSizeEqualToSize(oldSize, newSize)) {
        [self _setNeedsUpdatePlaceholder];
    }
}

- (void)setDelegate:(id<YHTextViewDelegate>)delegate {
    if (_delegate == delegate) return;
    _delegate = delegate;
    _delegateFlag_wordsCount = [delegate respondsToSelector:@selector(textViewWordCountDidChange:)];
}

- (UIEditingInteractionConfiguration)editingInteractionConfiguration {
    return UIEditingInteractionConfigurationNone;
}

- (void)_updateIfNeeded {
    [self _updatePlaceholderIfNeeded];
    [self _updateTextFormatIfNeeded];
    
}
#pragma mark - placeholder

- (void)_initPlaceholderLabel {
    if (@available(iOS 13.0, *)) {
        _placeholderColor = [UIColor placeholderTextColor];
    } else {
        _placeholderColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.1 alpha:0.22];
    }
    
    _placeholderLabel = [[UILabel alloc]initWithFrame:CGRectZero];
    _placeholderLabel.font = self.font;
    _placeholderLabel.textColor = _placeholderColor;
    _placeholderLabel.numberOfLines = 0;
    [self addSubview:_placeholderLabel];
}

- (void)_showPlaceholderIfNeeded {
    _placeholderLabel.hidden = self.attributedText.length > 0 || self.text.length > 0;
}

- (UIEdgeInsets)_placeholderInsets {
    UIEdgeInsets tmpEdge = self.textContainerInset;
    tmpEdge.left += self.textContainer.lineFragmentPadding;
    tmpEdge.right += self.textContainer.lineFragmentPadding;
    
    return tmpEdge;
}

- (CGRect)_placeholderExpectedFrame {
    if (!_placeholder || _placeholder.length == 0) {
        return CGRectZero;
    }
    UIEdgeInsets tmpEdge = [self _placeholderInsets];
    CGFloat maxWidth = self.frame.size.width - tmpEdge.left - tmpEdge.right;
    CGFloat maxHeight = self.frame.size.height - tmpEdge.top - tmpEdge.bottom;
    CGSize expectedSize = [_placeholderLabel sizeThatFits:CGSizeMake(maxWidth, maxHeight)];
    
    return CGRectMake(tmpEdge.left, tmpEdge.top, expectedSize.width, expectedSize.height);
}

- (void)_setNeedsUpdatePlaceholder {
    _placeholderNeedUpdate = YES;
    
    YHTextViewSetup();
    [textViewSet addObject:self];
}

- (void)_updatePlaceholderIfNeeded {
    if (_placeholderNeedUpdate) {
        _placeholderNeedUpdate = NO;
        _placeholderLabel.frame = [self _placeholderExpectedFrame];
    }
}

- (void)setPlaceholder:(NSString *)placeholder {
    if (_placeholder == placeholder || [_placeholder isEqualToString:placeholder]) return;
    _placeholder = placeholder.copy;
    _placeholderLabel.text = _placeholder;
    
    [self _setNeedsUpdatePlaceholder];
}

- (void)setPlaceholderColor:(UIColor *)placeholderColor {
    if (!placeholderColor) {
        if (@available(iOS 13.0, *)) {
            placeholderColor = [UIColor placeholderTextColor];
        } else {
            placeholderColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.1 alpha:0.22];
        }
    }
    if (_placeholderColor == placeholderColor || [_placeholderColor isEqual:placeholderColor]) return;
    _placeholderColor = placeholderColor;
    _placeholderLabel.textColor = _placeholderColor;
}

- (void)setAttributedPlaceholder:(NSAttributedString *)attributedPlaceholder {
    if (_attributedPlaceholder == attributedPlaceholder) return;
    _attributedPlaceholder = attributedPlaceholder.copy;
    _placeholderLabel.attributedText = _attributedPlaceholder;
    
    [self _setNeedsUpdatePlaceholder];
}

#pragma mark formatted text

- (void)_setNeedsUpdateTextFormat {
    _textFormatNeedUpdate = YES;
    
    YHTextViewSetup();
    [textViewSet addObject:self];
}

- (void)_updateTextFormatIfNeeded {
    if (_textFormatNeedUpdate) {
        _textFormatNeedUpdate = NO;
        [self _formattedText];
    }
}

- (void)_formattedText {
    if (!self.text) return;
    if (self.markedTextRange && [self positionFromPosition:self.beginningOfDocument offset:0]) return;
    
    NSMutableAttributedString *tmpText = self.attributedText.mutableCopy;
    NSRange tmpRange = self.selectedRange;
    
    NSMutableDictionary *params = [NSMutableDictionary new];
    params[NSForegroundColorAttributeName] = self.textColor;
    params[NSFontAttributeName] = self.font;
    params[NSParagraphStyleAttributeName] = self.paragraphStyle;
    params[NSKernAttributeName] = @(self.wordsKern);
    [tmpText setAttributes:params range:NSMakeRange(0, tmpText.length)];
    
    if (_textFormat) [_textFormat formatText:tmpText selectedRange:&tmpRange];
    if (_limitWordsFormat) [_limitWordsFormat formatText:tmpText selectedRange:&tmpRange];
    
    self.attributedText = tmpText;
    self.selectedRange = tmpRange;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.isFirstResponder) {
            [self scrollRangeToVisible:self.selectedRange];
        }
        if (self.delegateFlag_wordsCount) {
            [self.delegate textViewWordCountDidChange:self];
        }
    });
}

- (void)setTextFormat:(id<YHTextViewFormat>)textFormat {
    if (_textFormat == textFormat || [_textFormat isEqual:textFormat]) return;
    _textFormat = textFormat;
    
    [self _setNeedsUpdateTextFormat];
}

- (_YHLimitWordsTextFormat *)limitWordsFormat {
    if (!_limitWordsFormat) {
        _limitWordsFormat = [[_YHLimitWordsTextFormat alloc]init];
    }
    return _limitWordsFormat;
}

- (void)setLimitWords:(NSUInteger)limitWords {
    if (_limitWords == limitWords) return;
    _limitWords = limitWords;
    
    self.limitWordsFormat.limitWords = _limitWords;
    [self _updateTextFormatIfNeeded];
}

#pragma mark NSParagraphStyleAttribute

#define UpdateParagraphStyle(_attr_) \
if (self.paragraphStyle. _attr_ == _attr_) return; \
self.paragraphStyle. _attr_ == _attr_; \
[self _updateTextFormatIfNeeded];

- (void)setWordsKern:(CGFloat)wordsKern {
    if (_wordsKern == wordsKern) return;
    _wordsKern = wordsKern;
    
    [self _updateTextFormatIfNeeded];
}

- (void)setLineSpacing:(CGFloat)lineSpacing {
    UpdateParagraphStyle(lineSpacing);
}

- (void)setParagraphSpacing:(CGFloat)paragraphSpacing {
    UpdateParagraphStyle(paragraphSpacing);
}

- (void)setAlignment:(NSTextAlignment)alignment {
    UpdateParagraphStyle(alignment);
}

- (void)setFirstLineHeadIndent:(CGFloat)firstLineHeadIndent {
    UpdateParagraphStyle(firstLineHeadIndent);
}

- (void)setHeadIndent:(CGFloat)headIndent {
    UpdateParagraphStyle(headIndent);
}

- (void)setTailIndent:(CGFloat)tailIndent {
    UpdateParagraphStyle(tailIndent);
}

- (void)setLineBreakMode:(NSLineBreakMode)lineBreakMode {
    UpdateParagraphStyle(lineBreakMode);
}

- (void)setMinimumLineHeight:(CGFloat)minimumLineHeight {
    UpdateParagraphStyle(minimumLineHeight);
}

- (void)setMaximumLineHeight:(CGFloat)maximumLineHeight {
    UpdateParagraphStyle(maximumLineHeight);
}

- (void)setBaseWritingDirection:(NSWritingDirection)baseWritingDirection {
    UpdateParagraphStyle(baseWritingDirection);
}

- (void)setLineHeightMultiple:(CGFloat)lineHeightMultiple {
    UpdateParagraphStyle(lineHeightMultiple);
}

- (void)setParagraphSpacingBefore:(CGFloat)paragraphSpacingBefore {
    UpdateParagraphStyle(paragraphSpacingBefore);
}

- (void)setHyphenationFactor:(float)hyphenationFactor {
    UpdateParagraphStyle(hyphenationFactor);
}

- (NSMutableParagraphStyle *)paragraphStyle {
    if (!_paragraphStyle) {
        _paragraphStyle = [NSMutableParagraphStyle new];
    }
    return _paragraphStyle;
}

#pragma mark observer

- (void)_configurationEnvironment {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_textViewTextDidChange:) name:UITextViewTextDidChangeNotification object:nil];
    
    [self.gestureRecognizers enumerateObjectsUsingBlock:^(__kindof UIGestureRecognizer * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *name = obj.description;
        if ([name containsString:@"action=_handleGestureRecognizer:"] &&
            [name containsString:@"target=<_UILongPressTimeoutClickInteractionDriver"]) {
            obj.enabled = NO;
        }
        if ([name containsString:@"action=_dragInitiationGestureStateChanged:"]) {
            obj.enabled = NO;
        }
    }];
}

- (void)_textViewTextDidChange:(YHTextView *)textView {
    [self _setNeedsUpdateTextFormat];
    [self _updateTextFormatIfNeeded];
    [self _showPlaceholderIfNeeded];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

