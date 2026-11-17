#!/usr/bin/env ruby
# Configures ios/Runner.xcodeproj for the widgets and reminders task
# (docs/design/ui-polish/handoff/TASK-widgets.md) without the Xcode UI.
#
# Idempotent: running it again changes nothing. Backs up project.pbxproj to
# build/pbxproj-backup/ before every save. Never touches team, signing style
# or provisioning settings (the owner's step).
#
#   ruby tool/ios/configure_xcode_project.rb            # all steps
#   ruby tool/ios/configure_xcode_project.rb --dry-run  # report only
require 'fileutils'
require 'time'
require 'xcodeproj'

ROOT = File.expand_path('../..', __dir__)
PROJECT_PATH = File.join(ROOT, 'ios', 'Runner.xcodeproj')
DRY_RUN = ARGV.include?('--dry-run')

project = Xcodeproj::Project.open(PROJECT_PATH)
runner = project.targets.find { |t| t.name == 'Runner' } or abort 'no Runner target'
changes = []

def group_for(project, name, path)
  project.main_group.children.find { |g| g.isa == 'PBXGroup' && g.display_name == name } ||
    project.main_group.new_group(name, path)
end

def ensure_file(group, path, changes)
  existing = group.files.find { |f| f.path == path }
  return existing if existing
  changes << "file reference #{group.display_name}/#{path}"
  group.new_reference(path)
end

def ensure_source(target, ref, changes)
  return if target.source_build_phase.files_references.include?(ref)
  changes << "#{ref.path} → #{target.name} Sources"
  target.source_build_phase.add_file_reference(ref)
end

def ensure_setting(target, key, value, changes)
  target.build_configurations.each do |config|
    current = config.build_settings[key]
    current = current.join(' ') if current.is_a?(Array)
    next if current == value
    changes << "#{target.name} #{config.name}: #{key} = #{value}"
    config.build_settings[key] = value
  end
end

# --- W1: the bridge, the shared App Group store, Runner's entitlements -----
runner_group = project.main_group.children.find { |g| g.display_name == 'Runner' }
shared_group = group_for(project, 'Shared', 'Shared')

ensure_source(runner, ensure_file(runner_group, 'GrammarLensBridge.swift', changes), changes)
ensure_source(runner, ensure_file(runner_group, 'ReminderScheduler.swift', changes), changes)
ensure_file(runner_group, 'Runner.entitlements', changes)
ensure_source(runner, ensure_file(shared_group, 'AppGroupStore.swift', changes), changes)
ensure_setting(runner, 'CODE_SIGN_ENTITLEMENTS', 'Runner/Runner.entitlements', changes)

tests = project.targets.find { |t| t.name == 'RunnerTests' } or abort 'no RunnerTests target'
tests_group = project.main_group.children.find { |g| g.display_name == 'RunnerTests' }
ensure_source(tests, ensure_file(tests_group, 'BridgeTests.swift', changes), changes)

# --- W2: the widget extension ---------------------------------------------
EXT_NAME = 'GrammarLensWidgets'
EXT_BUNDLE_ID = 'com.ahmettayfur.grammarlens.widgets'
ext_group = group_for(project, EXT_NAME, EXT_NAME)
ext_sources = %w[GrammarLensWidgets.swift WidgetTimeline.swift WidgetViews.swift WidgetStyle.swift]
ext_refs = ext_sources.map { |f| ensure_file(ext_group, f, changes) }
ensure_file(ext_group, 'Info.plist', changes)
ensure_file(ext_group, "#{EXT_NAME}.entitlements", changes)
payload_ref = ensure_file(shared_group, 'WidgetPayload.swift', changes)
store_ref = shared_group.files.find { |f| f.path == 'AppGroupStore.swift' }

ext = project.targets.find { |t| t.name == EXT_NAME }
unless ext
  changes << "target #{EXT_NAME} (app extension)"
  ext = project.new_target(:app_extension, EXT_NAME, :ios, '15.0', project.products_group, :swift)
  # Flutter's xcconfigs give the extension FLUTTER_BUILD_NAME / NUMBER, so its
  # version always matches the app's.
  runner.build_configurations.each do |runner_config|
    ext_config = ext.build_configurations.find { |c| c.name == runner_config.name } ||
                 ext.add_build_configuration(runner_config.name, runner_config.name == 'Debug' ? :debug : :release)
    ext_config.base_configuration_reference = runner_config.base_configuration_reference
  end
end
(ext_refs + [payload_ref, store_ref]).each { |ref| ensure_source(ext, ref, changes) }
{
  'PRODUCT_BUNDLE_IDENTIFIER' => EXT_BUNDLE_ID,
  'PRODUCT_NAME' => '$(TARGET_NAME)',
  'INFOPLIST_FILE' => "#{EXT_NAME}/Info.plist",
  'GENERATE_INFOPLIST_FILE' => 'NO',
  'CODE_SIGN_ENTITLEMENTS' => "#{EXT_NAME}/#{EXT_NAME}.entitlements",
  'IPHONEOS_DEPLOYMENT_TARGET' => '15.0',
  'SWIFT_VERSION' => '5.0',
  'TARGETED_DEVICE_FAMILY' => '1,2',
  'SKIP_INSTALL' => 'YES',
  'APPLICATION_EXTENSION_API_ONLY' => 'YES',
  'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks',
  'SWIFT_EMIT_LOC_STRINGS' => 'NO',
}.each { |key, value| ensure_setting(ext, key, value, changes) }
# Signing stays the owner's (TASK-widgets fixed decision 2): drop whatever
# the gem's template put there, so the target inherits the project's.
ext.build_configurations.each do |config|
  %w[CODE_SIGN_STYLE DEVELOPMENT_TEAM PROVISIONING_PROFILE_SPECIFIER CODE_SIGN_IDENTITY].each do |key|
    next unless config.build_settings.key?(key)
    changes << "#{EXT_NAME} #{config.name}: remove #{key}"
    config.build_settings.delete(key)
  end
end

unless runner.dependencies.any? { |d| d.target == ext }
  changes << "Runner depends on #{EXT_NAME}"
  runner.add_dependency(ext)
end

embed = runner.copy_files_build_phases.find { |p| p.name == 'Embed Foundation Extensions' }
unless embed
  changes << 'Runner: Embed Foundation Extensions phase'
  embed = runner.new_copy_files_build_phase('Embed Foundation Extensions')
  embed.symbol_dst_subfolder_spec = :plug_ins
end
unless embed.files_references.include?(ext.product_reference)
  changes << "embed #{EXT_NAME}.appex"
  build_file = embed.add_file_reference(ext.product_reference)
  build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
end
# Right after "Embed Frameworks", before Flutter's "Thin Binary" and the
# Crashlytics script: an embed phase after them forms a build cycle.
frameworks = runner.build_phases.find { |p| p.respond_to?(:name) && p.name == 'Embed Frameworks' }
want = runner.build_phases.index(frameworks) + 1
have = runner.build_phases.index(embed)
if have != want && have != want - 1
  changes << 'move Embed Foundation Extensions after Embed Frameworks'
  runner.build_phases.delete(embed)
  runner.build_phases.insert(runner.build_phases.index(frameworks) + 1, embed)
end

# The snapshot and timeline tests (RunnerTests, `@testable import Runner`)
# render the widget views: Runner compiles the extension's view, timeline
# and payload files too (not its @main bundle), so there is one copy of
# each type for the tests. The app itself never shows them.
%w[WidgetTimeline.swift WidgetViews.swift WidgetStyle.swift].each do |f|
  ensure_source(runner, ext_group.files.find { |r| r.path == f }, changes)
end
ensure_source(runner, payload_ref, changes)
%w[WidgetSnapshotTests.swift WidgetTimelineTests.swift ReminderSchedulerTests.swift].each do |f|
  ensure_source(tests, ensure_file(tests_group, f, changes), changes)
end

# --- save ------------------------------------------------------------------
if changes.empty?
  puts 'Nothing to change.'
  exit 0
end
puts changes.map { |c| "  + #{c}" }
if DRY_RUN
  puts '(dry run: not saved)'
  exit 0
end
backup_dir = File.join(ROOT, 'build', 'pbxproj-backup')
FileUtils.mkdir_p(backup_dir)
backup = File.join(backup_dir, "project.pbxproj.#{Time.now.strftime('%Y%m%d-%H%M%S')}")
FileUtils.cp(File.join(PROJECT_PATH, 'project.pbxproj'), backup)
puts "Backup: #{backup}"
project.save
# xcodeproj shortens the comment of Flutter's local Swift package reference;
# Flutter's own project migrations match the comment Xcode writes, so put it
# back exactly.
pbxproj = File.join(PROJECT_PATH, 'project.pbxproj')
text = File.read(pbxproj)
text = text.gsub('/* XCLocalSwiftPackageReference "FlutterGeneratedPluginSwiftPackage" */',
                 '/* XCLocalSwiftPackageReference "Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage" */')
File.write(pbxproj, text)
puts 'Saved.'
