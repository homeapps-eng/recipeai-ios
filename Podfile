platform :ios, '15.0'
use_frameworks!

target 'RecipeAI' do
  use_frameworks!
    
  pod 'FirebaseCore'
  pod 'FirebaseAnalytics'
  pod 'FirebaseAuth'
  pod 'FirebaseFirestore'
  pod 'GoogleSignIn'
  pod 'Google-Mobile-Ads-SDK'

  post_install do |installer|
      installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
          config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
        end
      end
    end
end
