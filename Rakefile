# Rakefile
require 'fileutils'
require 'securerandom'

# Assuming your version file is app/version.rb
VERSION_FILE = 'app/version.rb'

desc "Increments the minor version number"
task :bump_minor do
  current_version = File.read(VERSION_FILE).match(/VERSION = "(\d+\.\d+)"/)[1]
  major, minor = current_version.split('.').map(&:to_i)
  new_version = "#{major}.#{minor + 1}"

  content = File.read(VERSION_FILE)
  new_content = content.gsub(/VERSION = "\d+\.\d+"/, "VERSION = \"#{new_version}\"")
  File.write(VERSION_FILE, new_content)

  puts "Version bumped from #{current_version} to #{new_version}"
end

desc "Displays the current version"
task :version do
  current_version = File.read(VERSION_FILE).match(/VERSION = "(\d+\.\d+)"/)[1]
  puts "Current Angalia Version: #{current_version}"
end

desc "Commits to repository with version and custom message"
task :release, [:msg] do |t, args|
  # t is the task object, args is a Rake::TaskArguments object
  # Access the message using args[:msg]

  version = File.read(VERSION_FILE).match(/VERSION = "(\d+\.\d+)"/)[1]

  # Construct the commit message
  commit_message = "v#{version}"
  commit_message += " - #{args[:msg]}" if args[:msg] && !args[:msg].empty?

  # Execute Git commands
  system("git add .")
  system("git commit -m '#{commit_message}'")

  puts "Git commit for version #{version}"
end

desc  "Generate secret string"
task  :gensecret do
  secret_string = SecureRandom.hex(64)
  puts "Generated Secret String: #{secret_string}"
end  # task


desc "Checks for system package dependencies using pkgcheck.sh"
task :packages do
  puts "Running required system packages dependency check..."
  # Execute the pkgcheck.sh script
  unless system("./pkgcheck.sh")
    abort "Dependency check failed. Please review the output above."
  end
  puts "Dependency check passed."
end

