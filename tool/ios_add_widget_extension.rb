#!/usr/bin/env ruby
# frozen_string_literal: true

# Adds the "Next up" WidgetKit extension (ios/NextUpWidget/) to
# ios/Runner.xcodeproj, and embeds it in the app. See docs/HOME_WIDGETS.md.
#
#   ruby tool/ios_add_widget_extension.rb
#
# Safe to run again: it finds what is already there and only adds what is
# missing (or puts back a setting someone changed). It needs the xcodeproj
# gem, which ships with CocoaPods (`gem list xcodeproj`).
#
# What it does:
#   1. Raises the app's iOS deployment target to 14.0 where it is lower:
#      WidgetKit, and the home_widget plugin, need iOS 14. (Every iPhone
#      that runs iOS 13 can run iOS 14.) The Podfile says the same.
#   2. Adds the NextUpWidget group with its Swift files, Info.plist,
#      entitlements (the App Group), privacy manifest and xcconfig.
#   3. Adds the NextUpWidget app-extension target: bundle id
#      app.myotherapp.in.NextUpWidget, Runner's development team,
#      automatic signing, iPhone only, iOS 14.0.
#   4. Embeds it in Runner ("Embed Foundation Extensions", placed before
#      "Thin Binary" -- after it, Xcode reports a dependency cycle) and
#      makes Runner depend on it.
#   5. Checks that Runner's entitlements carry the App Group.

require 'xcodeproj'

ROOT = File.expand_path('..', __dir__)
PROJECT_PATH = File.join(ROOT, 'ios', 'Runner.xcodeproj')

NAME = 'NextUpWidget'
BUNDLE_ID = 'app.myotherapp.in.NextUpWidget'
APP_GROUP = 'group.app.myotherapp.in'
MIN_IOS = '14.0'
EMBED_PHASE = 'Embed Foundation Extensions'

SOURCES = %w[NextUpWidget.swift NextUpData.swift].freeze
RESOURCES = %w[PrivacyInfo.xcprivacy].freeze
OTHER_FILES = %w[Info.plist NextUpWidget.entitlements NextUpWidget.xcconfig].freeze

def log(message)
  puts "  #{message}"
end

def version_below?(value, minimum)
  Gem::Version.new(value.to_s) < Gem::Version.new(minimum)
rescue ArgumentError
  false
end

project = Xcodeproj::Project.open(PROJECT_PATH)
runner = project.targets.find { |t| t.name == 'Runner' } or abort 'No Runner target'

team = runner.build_configurations
             .map { |c| c.build_settings['DEVELOPMENT_TEAM'] }
             .compact.first or abort "Runner has no DEVELOPMENT_TEAM"

puts "Runner.xcodeproj: adding #{NAME} (team #{team})"

# 1. The app's deployment target.
(project.build_configurations + runner.build_configurations).each do |config|
  target = config.build_settings['IPHONEOS_DEPLOYMENT_TARGET']
  next unless target && version_below?(target, MIN_IOS)

  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = MIN_IOS
  log "#{config.name}: IPHONEOS_DEPLOYMENT_TARGET #{target} -> #{MIN_IOS}"
end

podfile = File.join(ROOT, 'ios', 'Podfile')
podfile_text = File.read(podfile)
if (match = podfile_text.match(/^platform :ios, '([\d.]+)'/)) && version_below?(match[1], MIN_IOS)
  File.write(podfile, podfile_text.sub(match[0], "platform :ios, '#{MIN_IOS}'"))
  log "Podfile: platform :ios #{match[1]} -> #{MIN_IOS}"
end

# 2. The files.
group = project.main_group.children.find { |g| g.display_name == NAME } ||
        project.main_group.new_group(NAME, NAME)
file_refs = {}
(SOURCES + RESOURCES + OTHER_FILES).each do |file|
  abort "Missing ios/#{NAME}/#{file}" unless File.exist?(File.join(ROOT, 'ios', NAME, file))
  file_refs[file] = group.files.find { |f| f.path == file } || group.new_reference(file)
end

# 3. The target.
widget = project.targets.find { |t| t.name == NAME }
unless widget
  widget = project.new_target(:app_extension, NAME, :ios, MIN_IOS, nil, :swift)
  log "added target #{NAME}"
end

# xcodeproj links Foundation.framework by a path into this Mac's SDK
# (iPhoneOSxx.x.sdk), which another Xcode doesn't have. Swift links the
# system frameworks it imports by itself.
widget.frameworks_build_phase.files.dup.each do |build_file|
  ref = build_file.file_ref
  next unless ref && ref.path.to_s.end_with?('Foundation.framework') && ref.source_tree == 'DEVELOPER_DIR'

  widget.frameworks_build_phase.remove_build_file(build_file)
  parent = ref.parent
  ref.remove_from_project
  parent.remove_from_project if parent.is_a?(Xcodeproj::Project::Object::PBXGroup) &&
                                parent.display_name == 'iOS' && parent.children.empty?
end

SOURCES.each do |file|
  ref = file_refs[file]
  widget.source_build_phase.add_file_reference(ref, true)
end
RESOURCES.each do |file|
  ref = file_refs[file]
  widget.resources_build_phase.add_file_reference(ref, true)
end

xcconfig = file_refs['NextUpWidget.xcconfig']
widget.build_configurations.each do |config|
  config.base_configuration_reference = xcconfig
  settings = config.build_settings
  settings.merge!(
    'PRODUCT_NAME' => '$(TARGET_NAME)',
    'PRODUCT_BUNDLE_IDENTIFIER' => BUNDLE_ID,
    'INFOPLIST_FILE' => "#{NAME}/Info.plist",
    'GENERATE_INFOPLIST_FILE' => 'NO',
    'CODE_SIGN_ENTITLEMENTS' => "#{NAME}/#{NAME}.entitlements",
    'CODE_SIGN_STYLE' => 'Automatic',
    'DEVELOPMENT_TEAM' => team,
    'IPHONEOS_DEPLOYMENT_TARGET' => MIN_IOS,
    'TARGETED_DEVICE_FAMILY' => '1',
    'SWIFT_VERSION' => '5.0',
    'SKIP_INSTALL' => 'YES',
    'APPLICATION_EXTENSION_API_ONLY' => 'YES',
    'CURRENT_PROJECT_VERSION' => '$(FLUTTER_BUILD_NUMBER)',
    'MARKETING_VERSION' => '$(FLUTTER_BUILD_NAME)',
    'LD_RUNPATH_SEARCH_PATHS' => [
      '$(inherited)',
      '@executable_path/Frameworks',
      '@executable_path/../../Frameworks'
    ],
    'SWIFT_EMIT_LOC_STRINGS' => 'YES',
    'ENABLE_USER_SCRIPT_SANDBOXING' => 'NO'
  )
  # Signing follows Runner's: "iPhone Developer" for device builds.
  settings['CODE_SIGN_IDENTITY[sdk=iphoneos*]'] = 'iPhone Developer'
  settings.delete('ASSETCATALOG_COMPILER_APPICON_NAME')
  if config.name == 'Debug'
    settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone'
    settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG'
  end
end

attributes = project.root_object.attributes
attributes['TargetAttributes'] ||= {}
attributes['TargetAttributes'][widget.uuid] ||= {}
attributes['TargetAttributes'][widget.uuid].merge!(
  'CreatedOnToolsVersion' => '15.0',
  'DevelopmentTeam' => team
)

# 4. Embedded in Runner, before "Thin Binary".
embed = runner.copy_files_build_phases.find { |p| p.name == EMBED_PHASE }
unless embed
  embed = runner.new_copy_files_build_phase(EMBED_PHASE)
  log "added #{EMBED_PHASE} to Runner"
end
embed.symbol_dst_subfolder_spec = :plug_ins
embed.dst_path = ''
unless embed.files_references.include?(widget.product_reference)
  build_file = embed.add_file_reference(widget.product_reference, true)
  build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
end
thin = runner.build_phases.find { |p| p.respond_to?(:name) && p.name == 'Thin Binary' }
if thin
  runner.build_phases.delete(embed)
  runner.build_phases.insert(runner.build_phases.index(thin), embed)
end

unless runner.dependencies.any? { |d| d.target == widget }
  runner.add_dependency(widget)
  log "Runner depends on #{NAME}"
end

project.save

# 5. Runner's App Group.
%w[Runner.entitlements Runner.Release.entitlements].each do |file|
  path = File.join(ROOT, 'ios', 'Runner', file)
  plist = Xcodeproj::Plist.read_from_path(path)
  groups = plist['com.apple.security.application-groups'] || []
  next if groups.include?(APP_GROUP)

  plist['com.apple.security.application-groups'] = groups + [APP_GROUP]
  Xcodeproj::Plist.write_to_path(plist, path)
  log "#{file}: added #{APP_GROUP}"
end

puts "Done. Now: flutter pub get && (cd ios && pod install), then build."
