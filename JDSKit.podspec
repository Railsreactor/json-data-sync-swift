Pod::Spec.new do |s|
  s.name         = "JDSKit"
  s.version      = "1.0.7"
  s.summary      = "JDS Kit aggregates a core functionality to sync and store data using spiked-JSON-API protocol :D"
  s.homepage     = "https://github.com/Railsreactor/json-data-sync-swift" 
  s.license      = "MIT"  
  s.author       = { "Igor Reshetnikov" => "igor.reshetnikov.91@gmail.com" }  
  s.requires_arc = true
  s.platform     = :ios
  s.ios.deployment_target = '8.0'
  s.source       = { :git => "https://github.com/Railsreactor/json-data-sync-swift.git", :tag => "1.0.7" }
  s.source_files  = "JDSKit", "JDSKit/**/*.{sh,h,m,swift}"    
  s.preserve_paths = "JDSKit/InitialModel.xcdatamodeld"
  s.resource = "JDSKit/InitialModel.xcdatamodeld"
  s.frameworks = "UIKit", "Foundation"
  s.dependency 'CocoaLumberjack/Swift', '~> 2.2.0'
  s.dependency 'PromiseKit', '~> 3.0.3'
  s.dependency 'SwiftyJSON', '~> 2.3.2'
end