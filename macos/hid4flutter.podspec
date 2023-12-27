#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint hid4flutter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'hid4flutter'
  s.version          = '0.1.1'
  s.summary          = 'A flutter plugin for HID.'
  s.description      = <<-DESC
A flutter plugin for communicating with HID devices (Human Interface Device).
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.dependency 'hidapi', '0.14.0'

  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
