require 'sfn-parameters'
require 'securerandom'
require 'vault'

# Modeled after the Assume Role callback
module Sfn
  class Callback
    class VaultRead < Callback


      include SfnVault::Utils

      # Cache credentials for re-use to prevent re-generation of temporary
      # credentials on every command request.
      VAULT_CACHED_ITEMS = [
        :vault_lease_id,
        :vault_lease_expiration,
        :aws_access_key_id,
        :aws_secret_access_key
      ]

      def template(*args)
        # search for all parameters of type 'Vault::Generic::Secret'
        # 1. use the sparkleformation instance to get at the parameter hash,
        config[:parameters] ||= Smash.new
        stack = args.first[:sparkle_stack]
        # 2. find names for things you want,
        pseudo_parameters(stack).each do |param|
          param_path = vault_path_name(args, param)
          ui.debug "Using #{param_path} for saved parameter"
          # check if already saved in vault
          # Save the secret unless one already exists at the defined path
          client = vault_client
          unless client.logical.read(param_path)
            ui.info "Vault: No pre-existing value for parameter #{param} saving new secret"
            client.logical.write(param_path, value: random_secret)
          end
          # Read saved secret back from Vault and update parameters config
          # 3. set param into config
          config[:parameters][param] = client.logical.read(param_path).data[:value]
          # 4. update type in template and that should do it
          stack.compile.parameters.set!(param).type 'String'
        end
      end

      # Use SecureRandom to generate a suitable password
      # Length is configurable by setting `pseudo_parameter_length` in the vault
      # section of the sfn config
      #
      # @return [String] The generated string
      def random_secret
        SecureRandom.base64(config.fetch(:vault, :pseudo_parameter_length, 15))
      end

      # Build the path where generated secrets can be saved in Vault
      # This will use the value of `:pseudo_parameter_path` from the config if set. If
      # unset it will attempt to build a type of standardized path based on the
      # combined value any stack 'Project' tag and Stack name.
      # Project will fallback to 'SparkleFormation' if unset
      #
      # @param args [Array] Array of args passed to the sfn instance
      # @param parameter [String] Template parameter to save value for in vault
      # @return [String] String value or stack name if available or default to template name
      def vault_path_name(args, parameter)
        pref = config.get(:vault, :pseudo_parameter_path)
        # If we have a stack name use it, otherwise try to get from env and fallback to just template name
        stack = args.first[:sparkle_stack]
        stack_name = args.first[:stack_name].nil? ? ENV.fetch('STACK_NAME', stack.name).to_s : args.first[:stack_name]
        project = config[:options][:tags].fetch('Project', 'SparkleFormation')

        # When running in a detectable CI environment assume that we have rights to save a generic secret
        # but honor user preference value if set
        vault_path = if ci_environment?
                       # write to vault at generic path
                       base = pref.nil? ?  "secret" : pref
                       File.join(base, project, stack_name, parameter)
                     else
                       base = pref.nil? ?  "cubbyhole" : pref
                       # or for local dev use cubbyhole
                       File.join(base, project, stack_name, parameter)
                     end
        ui.debug "Vault: generated parameter value will be stored at #{vault_path}"
        vault_path
      end

      # Lookup all pseudo parameters in the template
      #
      # @param stack [SparkleFormation] An instance of the stack template
      # @param parameter [String] The string value of the pseudo type to lookup
      # @return [Array] Array of parameter names matching the pseudo type
      def pseudo_parameters(stack, parameter: 'Vault::Generic::Secret')
        stack.dump.fetch('Parameters', {}).map{|k,v| k if v['Type'] == parameter}.compact
      end


      # Check if we are running in any detectable CI type environments
      #
      # @return [TrueClass, FalseClass]
      def ci_environment?
        # check for any ci system env variables
        return true if ENV['GO_PIPELINE_NAME']
        return true if ENV['CI']
        false
      end

      def after_config(*_)
        # Inject credentials read from configured vault path
        # into API provider configuration
        # if credentials block contains vault_read_path
        # TODO: this could be done earlier if at all possible so credentials
        # struct does not need the aws config
        if(enabled? && config.fetch(:credentials, :vault_read_path))
          load_stored_session
        end
      end

      # Store session credentials until lease expires
      def after(*_)
        if(enabled?)
          if(config.fetch(:credentials, :vault_read_path) && api.connection.aws_region)
            path = cache_file
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

      # @return [String ]path
      def cache_file
        config.fetch(:vault, :cache_file, '.sfn-vault')
      end

      # @param [FixNum] expiration
      # @return [TrueClass, FalseClass]
      # check lease is just: time.now greater than lease expires?
      def expired?(expiration)
        Time.now.to_i >= expiration
      end

      # @return [Object] of type Vault::Secret
      def vault_read
        client = vault_client
        ui.debug "Have Vault client, configured with: #{client.options}"
        read_path = config.fetch(:credentials, :vault_read_path, "aws/creds/deploy") # save this value?
        credential = client.logical.read(read_path)
        credential
      end

      # Load stored configuration data into the api connection
      # or read retrieve with Vault client
      # @return [TrueClass, FalseClass]
      def load_stored_session
        path = cache_file
        FileUtils.touch(path)
        if(File.exist?(path))
          values = load_stored_values(path)
          VAULT_CACHED_ITEMS.each do |key|
            api.connection.data[key] = values[key]
            if [:aws_access_key_id, :aws_secret_access_key].member?(key)
              ui.debug "Updating environment #{key} with #{values[key]}"
              # also update environment for this process
              ENV[key.to_s] = values[key]
            end
          end
          if values[:vault_lease_expiration].nil?
            values[:vault_lease_expiration] = 0
          end
          if(expired?(values[:vault_lease_expiration]))
            begin
              secret = vault_read
              # without the sleep the credentials are not ready
              # this is arbitrary
              timeout = config.fetch(:vault, :iam_delay, 30)
              ui.info "Sleeping #{timeout}s for first time credentials system wide activation"
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
