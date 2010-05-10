
# wrap template commands in block so their execution can be controlled
# in unit testing
def template(&block)
  @store_template = block
  yield unless ENV['TEST']
end

def app_name
  File.basename(root)
end

def highline
  @highline ||= begin
    require "highline"
    HighLine.new
  end
end

def parse_keys(message)
  {
    :key    => (message.match(/Consumer key:\s+(.*)/)[1] rescue "TWITTER_CONSUMERKEY"),
    :secret => (message.match(/Consumer secret:\s+(.*)/)[1] rescue "TWITTER_CONSUMERSECRET")
  }
end

def heroku(cmd, arguments="")
  run "heroku #{cmd} #{arguments}"
end

def gem_with_version(name, options = {})
  if gem_spec = Gem.source_index.find_name(name).last
    version = gem_spec.version.to_s
    options = {:version => ">= #{version}"}.merge(options)
    gem(name, options)
  else
    $stderr.puts "ERROR: cannot find gem #{name}; cannot load version. Adding it anyway."
    gem(name, options)
  end
  options
end

def remove_gems(options)
  env = options.delete(:env)
  gems_code = /^\s*config.gem.*\n/
  file = env.nil? ? 'config/environment.rb' : "config/environments/#{env}.rb"
  gsub_file file, gems_code, ""
end

# Usage:
#   heroku_gem 'oauth'
#   heroku_gem 'hpricot', :version => '>= 0.2', :source => 'code.whytheluckystiff.net'
#   heroku_gem 'dm-core', :version => '0.9.10'
def heroku_gem(gem, options = {})
  options = gem_with_version(gem, options)
  file ".gems", "" unless File.exists?(".gems")

  version_str = options[:version] ? "--version '#{options[:version]}'" : ""
  source_str  = options[:source]  ? "--source '#{options[:source]}'" : ""
  append_file '.gems', "#{gem} #{version_str} #{source_str}\n"
end

def default_heroku_user
  @default_heroku_user ||= begin
    credentials = File.join(ENV['HOME'], '.heroku', 'credentials')
    if File.exist? credentials
      File.read(credentials) =~ /^(.*@.*)$/
      $1
    else
      false
    end
  end
end

def keep_all_empty_folders
  Dir['**/*'].reject {|p| File.file? p}.each do |path|
    keep_empty_folder path
  end
end

def keep_empty_folder(path)
  if Dir[File.join(path, "*")].empty?
    gitignore = File.join(path, ".gitignore")
    run "touch #{gitignore}"
  end
end

def plugin(*args)
  unless ENV['NO_PLUGINS']
    super
  end
end

def run_template
  @store_template.call
end
