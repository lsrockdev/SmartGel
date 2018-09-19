# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

target 'SmartGel' do
  # Uncomment the next line if you're using Swift or would like to use dynamic frameworks
  # use_frameworks!

  # Pods for SmartGel
pod 'RESideMenu', '~> 4.0.7'
pod 'MBProgressHUD', '~> 1.0.0'
pod 'Firebase/Core', '~> 4.13.0'
pod 'Firebase/Database'	
pod 'Firebase/Auth'
pod 'Firebase/Storage'	
pod 'Firebase/DynamicLinks'	
pod 'GPUImage', '~> 0.1.4'
pod 'SDWebImage', '~> 4.0'
pod 'SCLAlertView-Objective-C'
pod 'PFNavigationDropdownMenu'
pod 'GLCalendarView', '~> 1.0.0'

pod 'Fabric', '~> 1.7.7'
pod 'Crashlytics', '~> 3.10.2'

post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '9.2'
        end
    end
end

end
