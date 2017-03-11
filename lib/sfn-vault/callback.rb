require 'sfn-parameters'

# Modeled after the Assume Role callback
module Sfn
  class Callback
    class VaultRead < Callback

      # Cache credentials for re-use to prevent re-generation of temporary
      # credentials on every command request.
      VAULT_CACHED_ITEMS = [
        :vault_lease_id,
        :vault_lease_expiration,
        :aws_access_key_id,
        :aws_secret_access_key
      ]

      # Inject credentials read from vault path
      # into API provider configuration
      def after_config(*_)
        ui.debug "Entering #{__callee__}"
        # if credentials block contains vault_read_path
        if(enabled? && config.fetch(:credentials, :vault_read_path))
          ui.debug "attempting to load stored session"
          load_stored_session
        end
      end

      # Store session credentials until lease expires
      def after(*_)
        ui.debug "Entering #{__callee__}"
        if(enabled?)
          if(config.fetch(:credentials, :vault_read_path) && api.connection.aws_region)
            path = cache_file
            ui.debug "Vault storing credentials to #{path}"
            FileUtils.touch(path)
            File.chmod(0600, path)
            values = load_stored_values(path)
            VAULT_CACHED_ITEMS.map do |key|
              values[key] = api.connection.data[key]
            end
            File.open(path, 'w') do |file|
              file.puts MultiJson.dump(values)
            end
          end
        end
      end

      # @return [TrueClass, FalseClass]
      def enabled?
        config.fetch(:vault, :status, 'enabled').to_s == 'enabled'
      end

      # @return String path
      def cache_file
        config.fetch(:vault, :cache_file, '.sfn-vault')
      end

      # @param [FixNum] expiration
      # @return [TrueClass, FalseClass]
      # check lease is just: time.now greater than lease expires?
      def expired?(expiration)
        Time.now.to_i > expiration
      end

      def vault_addr
        address = config.fetch(:vault, :vault_addr, ENV['VAULT_ADDR'])
        ui.debug "Entering #{__callee__}"
        if address.nil?
          ui.error 'Set vault_addr in .sfn or VAULT_ADDR in environment'
          exit
        end
        ui.debug "Vault address is #{address}"
        address
      end

      def vault_token
        token = config.fetch(:vault, :vault_token, ENV['VAULT_TOKEN'])
        ui.debug "Entering #{__callee__}"
        if token.nil?
          ui.error 'Set :vault_token in .sfn or VAULT_TOKEN in environment'
          exit
        end
        ui.debug "Vault token is #{token}"
        token
      end

      # @return [Object] of type Vault::Secret
      def vault_read
        ui.debug "Entering #{__callee__}"
        # BUG: OpenSSL::SSL::SSLError: SSL_connect returned=1 errno=0 state=error: certificate verify failed
        certs = SfnVault::CertificateStore.default_ssl_cert_store
        ui.debug "read default cert store: #{certs}"

        conf = {
          address: vault_addr,
          token: vault_token,
        }

        ui.debug "merging platform specific config"
        conf.merge!({ssl_ca_path: '/etc/ssl/certs'}) unless SfnVault::Platform.windows?
        conf.merge!({ssl_cert_store: certs}) if certs


        ui.debug "have config hash"
        client = Vault::Client.new(conf)
        ui.debug "have vault client"
        ui.debug "Vault client is #{client}"
        read_path = config.fetch(:credentials, :vault_read_path, "aws/creds/deploy") # save this value?
        ui.debug "Vault read path is #{read_path}"
        retries = config.fetch(:vault, :retries, 5)

        ui.debug "Trying logical read"
        client.logical.read(read_path)
        # credential = client.with_retries(Exception, attempts: retries) do |attempt, e|
        #   ui.debug "Vault attempting to get credential with retries: #{attempt} of #{retries}"
        #   raise Exception
        # end
        ui.debug "Vault retrieved credential: #{credential}"
        credential
      end

      # Load stored configuration data into the api connection
      # or read retrieve with Vault client
      # @return [TrueClass, FalseClass]
      def load_stored_session
        # require 'pry'
        # binding.pry
        ui.debug "Entering #{__callee__}"
        path = cache_file
        FileUtils.touch(path)
        if(File.exist?(path))
          values = load_stored_values(path)
          VAULT_CACHED_ITEMS.each do |key|
            api.connection.data[key] = values[key]
          end
          if values[:vault_lease_expiration].nil?
            values[:vault_lease_expiration] = 0
          end
          if(expired?(values[:vault_lease_expiration]))
            ui.debug "No credential or lease expired"
            begin
              secret = vault_read
              ui.debug "vault lease: #{secret.lease_id}"
              # without the sleep the credentials are not ready
              ui.info "Sleeping 30s for first time credentials system wide activation"
              # this is arbitrary
              timeout = config.fetch(:vault, :iam_delay, 15)
              sleep(timeout)
              api.connection.data[:vault_lease_id] = secret.lease_id # maybe unused?
              api.connection.data[:vault_lease_expiration] = Time.now.to_i + secret.lease_duration
              # update keys in api connection
              api.connection.data[:aws_access_key_id] = secret.data[:access_key]
              api.connection.data[:aws_secret_access_key] = secret.data[:secret_key]
            rescue
            end
          end
          true
        else
          false
        end
      end

      # Load stored values
      #
      # @param path [String]
      # @return [Hash]
      def load_stored_values(path)
        begin
          if(File.exist?(path))
            MultiJson.load(File.read(path)).to_smash
          else
            Smash.new
          end
        rescue MultiJson::ParseError
          Smash.new
        end
      end

      # Default quiet mode
      def quiet
        true unless config[:debug]
      end

    end
  end
end