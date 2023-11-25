.PHONY: installed_xcodegen

# generates xcodeproj for frameworks build configuration
xcodeproj_with_frameworks: installed_xcodegen
	.tools/xcodegen/bin/xcodegen -s project_frameworks.yml

# install xcodegen
installed_xcodegen: .tools/xcodegen/bin/xcodegen

# install xcodegen if not installed
.tools/xcodegen/bin/xcodegen: scripts/install/install_xcodegen.sh
	scripts/install/install_xcodegen.sh
	touch $@

# generates xcodeproj for swift package manager build configuration
xcodeproj_with_spm: installed_xcodegen
	.tools/xcodegen/bin/xcodegen -s project_spm.yml

# builds station target with frameworks build configuration for iOS
build_with_frameworks: 
	d=$$(date +%s)\
	; xcodebuild -project frameworks.xcodeproj -scheme station -configuration Release -sdk iphoneos17.0 build\
    && echo "Build took $$(($$(date +%s)-d)) seconds"

# builds station target with swift package manager build configuration for iOS
build_with_spm:
	d=$$(date +%s)\
    ; xcodebuild -project spm.xcodeproj -scheme station -configuration Release -sdk iphoneos17.0 build\
    && echo "Build took $$(($$(date +%s)-d)) seconds"

# builds station target with development pods build configuration for iOS
build_with_pods:
	d=$$(date +%s)\
	; xcodebuild -workspace station.xcworkspace -scheme station -configuration Release -sdk iphoneos17.0 build\
	&& echo "Build took $$(($$(date +%s)-d)) seconds"
