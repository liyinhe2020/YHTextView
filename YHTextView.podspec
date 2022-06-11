#
#  Be sure to run `pod spec lint YHTextView.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see https://guides.cocoapods.org/syntax/podspec.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|
  s.name             = 'YHTextView'
  s.version          = '0.1.0'
  s.summary          = 'UITextView的拓展，支持限制字数、占位符、富文本输入等功能'

  s.homepage         = 'https://github.com/liyinhe2020/YHTextView'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'liyinhee' => 'objc.li@outlook.com' }
  s.source           = { :git => 'https://github.com/liyinhe2020/YHTextView.git', :tag => s.version.to_s }

  s.ios.deployment_target = '10.0'
  
  s.static_framework = true

  s.source_files = 'YHTextView/**/*.{h,m}'
  s.public_header_files = 'YHTextView/**/*.{h}'
  
  s.framework = 'UIKit'
end
