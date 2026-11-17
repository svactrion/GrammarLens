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
    next if config.build_settings[key] == value
    changes << "#{target.name} #{config.name}: #{key} = #{value}"
    config.build_settings[key] = value
  end
end

# --- W1: the bridge, the shared App Group store, Runner's entitlements -----
runner_group = project.main_group.children.find { |g| g.display_name == 'Runner' }
shared_group = group_for(project, 'Shared', 'Shared')

ensure_source(runner, ensure_file(runner_group, 'GrammarLensBridge.swift', changes), changes)
ensure_file(runner_group, 'Runner.entitlements', changes)
ensure_source(runner, ensure_file(shared_group, 'AppGroupStore.swift', changes), changes)
ensure_setting(runner, 'CODE_SIGN_ENTITLEMENTS', 'Runner/Runner.entitlements', changes)

tests = project.targets.find { |t| t.name == 'RunnerTests' } or abort 'no RunnerTests target'
tests_group = project.main_group.children.find { |g| g.display_name == 'RunnerTests' }
ensure_source(tests, ensure_file(tests_group, 'BridgeTests.swift', changes), changes)

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
