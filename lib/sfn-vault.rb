require 'sfn'
require 'vault'

module SfnVault
  autoload :Platform, 'sfn-vault/platform'
  autoload :Windows, 'sfn-vault/windows'
  autoload :CertificateStore, 'sfn-vault/certificate_store'
  autoload :Utils, 'sfn-vault/utils'
end

require 'sfn-vault/version'
require 'sfn-vault/callback'
require 'sfn-vault/inject'
