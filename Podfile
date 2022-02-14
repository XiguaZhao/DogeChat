# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'
use_modular_headers!
  use_frameworks!

def commonDefinesPod
  pod 'DogeChatCommonDefines', :path => '/Users/zhaoxiguang/Library/Mobile Documents/com~apple~CloudDocs/Documents/Developer/DogeChatCommonDefines'
end

def shared_pods
  pod 'DogeChatUniversal', :path => '/Users/zhaoxiguang/Library/Mobile Documents/com~apple~CloudDocs/Documents/Developer/DogeChatUniversal'
  commonDefinesPod
end

target 'DogeChat' do
  # Comment the next line if you don't want to use dynamic frameworks
shared_pods
pod 'DACircularProgress'
pod 'MJRefresh'
pod 'AFNetworking'
pod 'SwiftyJSON', :git => 'https://github.com/SwiftyJSON/SwiftyJSON.git', :commit => '2b6054efa051565954e1d2b9da831680026cd768'
pod 'SwiftyRSA', :path => '/Users/zhaoxiguang/Workspace/SwiftyRSA'
pod 'FLAnimatedImage', :path => '/Users/zhaoxiguang/Library/Mobile Documents/com~apple~CloudDocs/Documents/Developer/FLAnimatedImage'
pod 'SDWebImage'
pod 'Masonry'
pod 'DogeChatNetwork', :path => '/Users/zhaoxiguang/Library/Mobile Documents/com~apple~CloudDocs/Documents/Developer/DogeChatNetwork'
pod 'LookinServer', :configurations => ['Debug']
pod 'RSAiOSWatchOS', :path => '/Users/zhaoxiguang/Library/Mobile Documents/com~apple~CloudDocs/Documents/Developer/RSAiOSWatchOS'
pod 'DataCompression'
pod 'DogeChatVideoUtil', :path => '/Users/zhaoxiguang/Library/Mobile Documents/com~apple~CloudDocs/Documents/Developer/DogeChatVideoUtil'
end


target 'DogeChatWatch Extension' do
  platform :watchos, '7.0'
  shared_pods
  pod 'AFNetworking'
  pod 'SwiftyJSON', :git => 'https://github.com/SwiftyJSON/SwiftyJSON.git', :commit => '2b6054efa051565954e1d2b9da831680026cd768'
  pod 'RSAiOSWatchOS', :path => '/Users/zhaoxiguang/Library/Mobile Documents/com~apple~CloudDocs/Documents/Developer/RSAiOSWatchOS'
end

target 'mynotification' do
  commonDefinesPod
end

target 'DogeChatSiri' do
  shared_pods
  pod 'RSAiOSWatchOS', :path => '/Users/zhaoxiguang/Library/Mobile Documents/com~apple~CloudDocs/Documents/Developer/RSAiOSWatchOS'
end

target 'DogeChatShare' do
  shared_pods
  pod 'RSAiOSWatchOS', :path => '/Users/zhaoxiguang/Library/Mobile Documents/com~apple~CloudDocs/Documents/Developer/RSAiOSWatchOS'
  pod 'DogeChatVideoUtil', :path => '/Users/zhaoxiguang/Library/Mobile Documents/com~apple~CloudDocs/Documents/Developer/DogeChatVideoUtil'
end
