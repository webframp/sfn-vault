require 'sfn-vault'

module SfnVault
  module Utils

    def vault_client
      certs = SfnVault::CertificateStore.default_ssl_cert_store

      conf = {
        address: vault_addr,
        token: vault_token,
      }
      conf.merge!({ssl_ca_path: '/etc/ssl/certs'}) unless SfnVault::Platform.windows?
      conf.merge!({ssl_cert_store: certs}) if certs

      client = Vault::Client.new(conf)
      client
    end

    def vault_addr
      address = config.fetch(:vault, :vault_addr, ENV['VAULT_ADDR'])
      if address.nil?
        ui.error 'Set vault_addr in .sfn or VAULT_ADDR in environment'
        exit
      end
      ui.debug "Vault address is #{address}"
      address
    end

    def vault_token
      token = config.fetch(:vault, :vault_token, ENV['VAULT_TOKEN'])
      if token.nil?
        ui.error 'Set :vault_token in .sfn or VAULT_TOKEN in environment'
        exit
      end
      ui.debug "Vault token is #{token}"
      token
    end

    # Test write/read/delete operations
    # to determine if we can save a secret
    # @param [Vault::Client] client
    # @return [TrueClass, FalseClass]
    def vault_writeable?(client)
      secret = 'cubbyhole/SfnVaultCallbackCheck'
      value = 'ensure_writeable'
      if client.logical.write(secret, value: value)
        read = client.logical.read(test_secret)
        client.logical.delete(test_secret)
        if read.data == value
          return true
        end
      end
    end
  end
end
