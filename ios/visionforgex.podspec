Pod::Spec.new do |s|
  s.name             = 'visionforgex'
  s.version          = '1.0.0'
  s.summary          = 'VisionForgeX ads for Flutter.'
  s.homepage         = 'https://apps.visionforgex.com'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'VisionForgeX' => 'support@visionforgex.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'VisionForgeX', '~> 1.0'
  s.platform         = :ios, '13.0'
  s.swift_version    = '5.9'
end
