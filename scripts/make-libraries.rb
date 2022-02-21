#!/usr/bin/env ruby

require 'fileutils'
require 'open3'

# to be run after +make+
# 1. combines the Debug-iphoneos and Debug-iphonesimulator libs into a FAT lib
# 2. creates a static Framework using the combined lib
# 3. stages the calabash.framework to ./

# @return [String] the combined binary name
def combined_lib_name
  'calabash-combined.a'
end

# @return [String] the combined binary for Frank plugin name
def combined_frank_lib_name
  'libFrankCalabash.a'
end

# @return [String] the combined binary for dylib name
def combined_dylib_name
  'libCalabash.dylib'
end

# @return [String] constructs a path using +directory+ and +lib_name+
# @param [String] directory the directory path
# @param [String] lib_name name of the library
# @raise [RuntimeError] if no file exists at path
def path_to_lib(directory, lib_name)
  unless File.directory?(directory)
    raise "expected directory '#{directory}' to exist"
  end

  path = File.join(directory, lib_name)

  unless File.exists?(path)
    raise "expected library at '#{path}' to exist"
  end
  path
end

# @return [String] the path to the device lib
# @param [Hash] opts directory and lib name options
def path_to_device_lib(opts = {})
  default_opts = {:directory => './build/Debug-iphoneos',
                  :lib_name => 'libcalabash-device.a'}
  merged = default_opts.merge(opts)
  path_to_lib(merged[:directory], merged[:lib_name])
end

# @return [String] the path to the simulator lib
# @param [Hash] opts directory and lib name options
def path_to_simulator_lib(opts = {})
  default_opts = {:directory => './build/Debug-iphonesimulator',
                  :lib_name => 'libcalabash-simulator.a'}
  merged = default_opts.merge(opts)

  path_to_lib(merged[:directory], merged[:lib_name])
end

# @return [String] the path to the device frank lib
# @param [Hash] opts directory and lib name options
def path_to_device_frank_lib(opts = {})
  default_opts = {:directory => './build/Debug-iphoneos',
                  :lib_name => 'libFrankCalabashDevice.a'}
  merged = default_opts.merge(opts)
  path_to_lib(merged[:directory], merged[:lib_name])
end

# @return [String] the path to the simulator frank lib
# @param [Hash] opts directory and lib name options
def path_to_simulator_frank_lib(opts = {})
  default_opts = {:directory => './build/Debug-iphonesimulator',
                  :lib_name => 'libFrankCalabash.a'}
  merged = default_opts.merge(opts)

  path_to_lib(merged[:directory], merged[:lib_name])
end

# creates a staging directory for the combined library.
#
# if a directory exists at the :directory option it is deleted.
#
# @return [String] path to the staging directory
# @param [Hash] opts directory option
def make_combined_lib_staging_dir(opts = {})
  default_opts = {:directory => './build/Debug-combined'}
  merged = default_opts.merge(opts)
  path = merged[:directory]
  if File.exists?(path)
    FileUtils.rm_r(path)
  end
  FileUtils.mkdir(path)
  path
end

# @return [String] a file path to use as the -output of lipo -create
# @param [String] directory the base directory
# @param [String] name the name of the combined lib
def combined_lib_path(directory, name)
  unless File.directory?(directory)
    raise "expected directory '#{directory}' to exist"
  end
  File.join(directory, name)
end

# @param [Array<String>] inputs an array of lib paths to pass to lipo
# @param [Object] output the combined library
# @return [String] lipo create command
def lipo_cmd(inputs, output)
  "xcrun lipo -create #{inputs.join(' ')} -output #{output}"
end

# @return [String] lipo info command
# @param [String] lib path to a library or executable binary
def lipo_info(lib)
  "xcrun lipo -info #{lib}"
end

def lipo_put_info(lib)
  cmd = lipo_info(lib)
  puts 'INFO: checking combined lib'
  puts "INFO: #{cmd}"
  lipo_info = `#{cmd}`
  result = $?

  unless result.success?
    puts 'FAIL: could not check the combined lib'
    puts "FAIL: '#{lipo_info.strip}'"
    exit result.to_i
  end
end

def lipo_verify(lib, arch, sdk)
  "xcrun -sdk #{sdk} lipo #{lib} -verify_arch '#{arch}'"
end

def xcode_version
  xcode_build_output = `xcrun xcodebuild -version`.split("\n")
  xcode_build_output.each do |line|
    match=/^Xcode\s(.*)$/.match(line.strip)
    return match[1] if match && match.length > 1
  end
end

def lipo_verify_arches(lib, sdk, arches=['x86_64', 'armv7', 'armv7s', 'arm64'])
  arches.each do |arch|
    cmd = lipo_verify(lib, arch, sdk)
    Open3.popen3(cmd) do |_, _, _, wait_thr|
      exit_status = wait_thr.value
      if exit_status.success?
        puts "INFO: #{lib} contains arch '#{arch}'"
      else
        puts "FAIL: could not verify lib contains arch '#{arch}'"
        puts "FAIL: '#{cmd}'"
        exit 1
      end
    end
  end
end

## Assumes we have already build and setup stage for calabash combined libs
def lipo_combine_frank_libs
  staging = make_combined_lib_staging_dir
  inputs = [path_to_device_frank_lib, path_to_simulator_frank_lib]
  output = combined_lib_path(staging, combined_frank_lib_name)
  cmd = lipo_cmd(inputs, output)

  puts 'INFO: combining libs'
  puts "INFO: #{cmd}"
  lipo_create = `#{cmd}`
  result = $?

  unless result.success?
    puts 'FAIL: could not create combined lib'
    puts "FAIL: '#{lipo_create.strip}'"
    exit result.to_i
  end

  lipo_put_info(output)
  lipo_verify_arches(output, 'iphonesimulator')
end

def framework_product_name
  'calabash'
end

def make_xcframework(opts = {})
  default_opts = {:directory => './build/Debug-combined/calabash.xcframework'}
  merged = default_opts.merge(opts)
  platforms = {
    "iphoneos" => {:path => path_to_device_lib, :arches => ['arm64']},
    "iphonesimulator" => {:path => path_to_simulator_lib, :arches => ['arm64','x86_64']}
  }

  directory = merged[:directory]
  plistBuddy = '/usr/libexec/PlistBuddy'
  puts "INFO: making xcframework at '#{directory}'"
  FileUtils.mkdir_p(File.join(directory))
  plist = File.join(directory, "Info.plist")
  FileUtils.cp('./scripts/templates/XCFramework.Info.plist', plist)

  platforms.each do |platform, info|
    puts "INFO: making framework for '#{platform}'"
    make_framework({
      :directory => File.join(File.join(directory, platform), 'calabash.framework'),
      :platform => platform,
      :path_to_lib => info[:path],
      :arches => info[:arches]
    })
    plist_index = nil
    for index in 0..1 do
      if `#{plistBuddy} -c "Print :AvailableLibraries:#{index}:LibraryIdentifier" #{plist}`.chomp == platform
        puts "INFO: found platform '#{platform}' at index #{index} in '#{plist}'"
        plist_index = index
      end
    end
    if plist_index == nil
      puts "FAIL: couldn't find entry for platform '#{platform}' in #{plist}"
      exit 1
    end
    info[:arches].each do |arch|
      `#{plistBuddy} -c "Add :AvailableLibraries:#{plist_index}:SupportedArchitectures:0 string #{arch}" #{plist}`
    end
  end
end

private def make_framework(opts = {})
  default_opts = {:directory => './build/Debug-combined/calabash.framework',
                  :platform => 'iphoneos',
                  :path_to_lib => path_to_device_lib,
                  :arches => ['arm64'],
                  :version_exe => './build/Debug/version'}

  merged = default_opts.merge(opts)

  directory = merged[:directory]
  if File.exists?(directory)
    FileUtils.rm_r(directory)
  end

  puts "INFO: making framework at '#{directory}'"

  framework_name = framework_product_name
  lib = merged[:path_to_lib]
  puts "INFO: installing lib '#{lib}' to '#{directory}'"

  unless File.exists?(lib)
    puts 'FAIL: lib does not exist'
    puts "FAIL: could not find '#{File.join(Dir.pwd, lib)}'"
    exit 1
  end

  FileUtils.mkdir_p(File.join(directory, 'Versions/A/Headers'))
  FileUtils.cp(lib, "#{directory}/Versions/A/#{framework_name}")
  `cp -a ./build/Debug-iphoneos/calabashHeaders/* #{directory}/Versions/A/Headers`
  `ln -sfh A #{directory}/Versions/Current`
  `ln -sfh Versions/Current/#{framework_name} #{directory}/#{framework_name}`
  `ln -sfh Versions/Current/Headers #{directory}/Headers`

  version_exe = merged[:version_exe]
  puts "INFO: installing Resources to '#{directory}'"
  resource_path = File.join(directory, 'Versions/A/Resources')
  FileUtils.mkdir_p(resource_path)
  FileUtils.cp(version_exe, resource_path)

  Dir.chdir(directory) do
    `ln -sfh Versions/Current/Resources Resources`

    version = `Resources/version`.chomp!
    `ln -sfh A Versions/#{version}`
  end

  puts 'INFO: verifying framework'
  lib = "#{directory}/calabash"
  lipo_verify_arches(lib, merged[:platform], merged[:arches])
end

def stage_framework(opts = {})
  default_opts = {:source => './build/Debug-combined/calabash.xcframework',
                  :target => './'}
  merged = default_opts.merge(opts)

  source = merged[:source]
  target = merged[:target]
  puts "INFO: staging '#{source}' to '#{target}'"

  if File.directory?('./calabash.xcframework')
    puts 'INFO: removing old calabash.xcframework'
    FileUtils.rm_r('./calabash.xcframework')
  end

  tar_file = './calabash.xcframework.tar'
  if File.exists?(tar_file)
    puts 'INFO: removing old calabash.xcframework.tar'
    FileUtils.rm(tar_file)
  end

  puts "INFO: making a tarball of #{source}"
  `tar -C #{File.join(source, '..')} -cf calabash.xcframework.tar calabash.xcframework`

  puts 'INFO: extracting calabash.framework from tarball'
  `tar -xf #{tar_file}`
  puts 'INFO: cleaning up'
  FileUtils.rm(tar_file)
end

def stage_frank_lib
  source = File.expand_path('build/Debug-combined/libFrankCalabash.a')
  unless File.exists? source
    puts 'FAIL: build/Debug-combined/libFrankCalabash.a does not exist.  Did you forget to run `make frank`?'
    exit 1
  end

  target = File.expand_path('./libFrankCalabash.a')
  if File.exists?(target)
    puts 'INFO: removing old libFrankCalabash.a'
    FileUtils.rm(target)
  end

  puts "INFO: staging '#{source}' to ./"
  FileUtils.cp(source, target)
end

# @param [Hash] opts :device and :sim dylib paths
# @return [Boolean] true if both device and sim dylibs are built
def dylibs_built?(opts = {})
  default_opts = {:device => './build/Debug-iphoneos/libCalabashDyn.dylib',
                  :sim => './build/Debug-iphonesimulator/libCalabashDynSim.dylib'}
  merged = default_opts.merge(opts)
  File.exist?(merged[:device]) && File.exist?(merged[:sim])
end

# @return [String] the path to the device lib
# @param [Hash] opts directory and lib name options
def path_to_device_dylib(opts = {})
  default_opts = {:directory => './build/Debug-iphoneos',
                  :lib_name => 'libCalabashDyn.dylib'}
  merged = default_opts.merge(opts)
  path_to_lib(merged[:directory], merged[:lib_name])
end

# @return [String] the path to the simulator lib
# @param [Hash] opts directory and lib name options
def path_to_simulator_dylib(opts = {})
  default_opts = {:directory => './build/Debug-iphonesimulator',
                  :lib_name => 'libCalabashDynSim.dylib'}
  merged = default_opts.merge(opts)

  path_to_lib(merged[:directory], merged[:lib_name])
end

def verify_dylibs(which=:both)
  case which
    when :both
      verify_dylibs :device
      verify_dylibs :sim
    when :sim
      simulator_dylib = path_to_simulator_dylib
      lipo_verify_arches(simulator_dylib, 'iphonesimulator', ['arm64', 'x86_64'])
      lipo_put_info(simulator_dylib)
    when :device
      device_dylib = path_to_device_dylib
      lipo_verify_arches(device_dylib, 'iphoneos', ['arm64'])
      lipo_put_info(device_dylib)
    else
      raise "Expected `which` arg '#{which}' to be one of [:sim, :device, :both]"
  end
end

def stage_dylibs
  device_dylib = path_to_device_dylib
  simulator_dylib = path_to_simulator_dylib
  unless dylibs_built?({:sim => simulator_dylib, :device => device_dylib})
    puts 'FAIL:  the dylibs have not been built. Did you forget to run `make dylibs`?'
    exit 1
  end

  target_dir = File.expand_path('./calabash-dylibs')
  if File.directory?(target_dir)
    puts 'INFO:  removing old calabash-dylibs'
    FileUtils.rm_rf target_dir
  end

  FileUtils.mkdir target_dir

  puts "INFO: staging '#{device_dylib}' to ./calabash-dylibs"
  FileUtils.cp(device_dylib, target_dir)

  puts "INFO: staging '#{simulator_dylib}' to ./calabash-dylibs"
  FileUtils.cp(simulator_dylib, target_dir)
end

if ARGV[0] == 'verify-framework'
  make_xcframework
  stage_framework
  exit 0
end

if ARGV[0] == 'verify-frank'
  lipo_combine_frank_libs
  stage_frank_lib
  exit 0
end

if ARGV[0] == 'verify-dylibs'
  verify_dylibs
  stage_dylibs
  exit 0
end

if ARGV[0] == 'verify-sim-dylib'
  verify_dylibs :sim

  simulator_dylib = path_to_simulator_dylib

  target_dir = File.expand_path('./calabash-dylibs')
  if File.directory?(target_dir)
    puts 'INFO:  removing old calabash-dylibs'
    FileUtils.rm_rf target_dir
  end

  FileUtils.mkdir target_dir

  puts "INFO: staging '#{simulator_dylib}' to ./calabash-dylibs"
  FileUtils.cp(simulator_dylib, target_dir)

  exit 0
end
