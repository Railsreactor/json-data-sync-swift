Pod::Spec.new do |s|
  s.name         = "JDSKit"
  s.version      = "0.2.1"
  s.summary      = "JDS Kit aggregates a core functionality to sync and store data using spiked-JSON-API protocol :D"
  s.homepage     = "https://github.com/Railsreactor/json-data-sync-swift" 
  s.license      = "MIT"  
  s.author       = { "Igor Reshetnikov" => "igor.reshetnikov.91@gmail.com" }  
  s.requires_arc = true
  s.platform     = :ios
  s.ios.deployment_target = '8.0'
  s.source       = { :git => "https://github.com/Railsreactor/json-data-sync-swift.git", :tag => "0.2.1" }
  s.source_files  = "JDSKit/**/*.{m,swift}"    
  s.preserve_paths = "JDSKit/InitialModel.xcdatamodeld"
  s.xcconfig = { "CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES" => "YES" }
  s.resource = "JDSKit/InitialModel.xcdatamodeld"
  s.frameworks = "UIKit", "Foundation"
  s.dependency 'CocoaLumberjack/Swift', '~> 2.2.0'
  s.dependency 'PromiseKit', '~> 3.0.3'
  s.dependency 'SwiftyJSON', '~> 2.3.2'
end