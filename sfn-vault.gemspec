$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__)) + '/lib/'
require 'sfn-vault/version'
Gem::Specification.new do |s|
  s.name = 'sfn-vault'
  s.version = SfnVault::VERSION.version
  s.summary = 'SparkleFormation Vault Callback'
  s.author = 'Sean Escriva'
  s.email = 'sean.escriva@gmail.com'
  s.homepage = 'http://github.com/webframp/sfn-vault'
  s.description = 'SparkleFormation Vault Callback'
  s.license = 'Apache-2.0'
  s.require_path = 'lib'
  s.add_dependency 'sfn', '>= 3.0', '< 4.0'
  s.add_dependency 'vault', '~> 0.7.3'
  s.add_development_dependency 'pry', '~> 0.10.4'
  s.add_development_dependency 'pry-byebug', '~> 3.4', '>= 3.4.2'
  s.add_development_dependency 'rb-readline', '~> 0.5.3'
  s.files = Dir['{lib,bin,docs}/**/*'] + %w(sfn-vault.gemspec README.md CHANGELOG.md LICENSE)
end
