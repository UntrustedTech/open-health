# Adds the HealthWidgets extension (Home Screen widgets and the workout
# Live Activity) to Runner.xcodeproj. The GitHub iOS build runs it before
# `flutter build ios`, as there's no Mac here to add the target in Xcode.
# Running it again does nothing.
#
#   gem install xcodeproj && ruby ios/add_widget_extension.rb
require 'xcodeproj'

NAME = 'HealthWidgets'
GROUP_ID = 'group.health.untrustedtech.dev'

ios = __dir__
project = Xcodeproj::Project.open(File.join(ios, 'Runner.xcodeproj'))
if project.targets.any? { |t| t.name == NAME }
  puts "#{NAME} is already in the project"
  exit 0
end

version = File.read(File.join(ios, '..', 'pubspec.yaml'))[/^version:\s*(\S+)/, 1]
build_name, build_number = version.split('+')

app = project.targets.find { |t| t.name == 'Runner' }
ext = project.new_target(:app_extension, NAME, :ios, '17.0', nil, :swift)

widgets = project.main_group.new_group(NAME, NAME)
Dir[File.join(ios, NAME, '*.swift')].sort.each do |file|
  ext.source_build_phase.add_file_reference(widgets.new_reference(File.basename(file)))
end
widgets.new_reference('Info.plist')
widgets.new_reference("#{NAME}.entitlements")

# The Live Activity's attributes are compiled into both.
shared = project.main_group.new_group('Shared', 'Shared')
attributes = shared.new_reference('WorkoutAttributes.swift')
ext.source_build_phase.add_file_reference(attributes)
app.source_build_phase.add_file_reference(attributes)

runner_group = project.main_group.find_subpath('Runner', false)
app.source_build_phase.add_file_reference(runner_group.new_reference('WorkoutActivity.swift'))

# The app still runs on iOS 15, which has no ActivityKit.
app.build_configurations.each do |config|
  flags = Array(config.build_settings['OTHER_LDFLAGS'] || '$(inherited)')
  config.build_settings['OTHER_LDFLAGS'] = flags + ['-weak_framework', 'ActivityKit']
end

ext.build_configurations.each do |config|
  config.build_settings.merge!(
    'PRODUCT_NAME' => NAME,
    'PRODUCT_BUNDLE_IDENTIFIER' => 'health.untrustedtech.dev.HealthWidgets',
    'INFOPLIST_FILE' => "#{NAME}/Info.plist",
    'GENERATE_INFOPLIST_FILE' => 'NO',
    'CODE_SIGN_ENTITLEMENTS' => "#{NAME}/#{NAME}.entitlements",
    'IPHONEOS_DEPLOYMENT_TARGET' => '17.0',
    'SWIFT_VERSION' => '5.0',
    'TARGETED_DEVICE_FAMILY' => '1,2',
    'MARKETING_VERSION' => build_name,
    'CURRENT_PROJECT_VERSION' => build_number,
    'SKIP_INSTALL' => 'YES',
    'APPLICATION_EXTENSION_API_ONLY' => 'YES',
    'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks',
    'ENABLE_BITCODE' => 'NO',
  )
end

# Embedded in the app, before Flutter's "Thin Binary" script so Xcode
# doesn't find a build cycle.
embed = app.new_copy_files_build_phase('Embed Foundation Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
embed.add_file_reference(ext.product_reference, true).settings =
  { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
app.build_phases.delete(embed)
thin = app.build_phases.index { |p| p.respond_to?(:name) && p.name == 'Thin Binary' }
app.build_phases.insert(thin || app.build_phases.length, embed)
app.add_dependency(ext)

project.save
puts "Added #{NAME} (#{build_name} #{build_number}) to Runner.xcodeproj; App Group #{GROUP_ID}"
