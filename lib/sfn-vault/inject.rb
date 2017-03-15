class SparkleFormation
  module SparkleAttribute
    module Aws

      require 'vault'
      require 'securerandom'

      # Polluting SparkleFormation::SparkleAttribute::Aws namespace ?
      include SfnVault::Utils

      # example usage: vault_parameter!(:masterpassword)
      def _vault_parameter(*vp_args)
        vp_name, vp_opts = vp_args
        __t_stringish(vp_name)
        if vp_opts
          vp_path = vp_opts[:path] if vp_opts[:path]
        end
        parameters.set!("vault_parameter_#{vp_name}") do
          no_echo true
          description "Automatically generated Vault param #{vp_name}"
          type 'String'
        end
      end
      alias_method :vault_parameter!, :_vault_parameter
    end
  end
end

# do stuff
# save to vault cubbyhole/name, ex: cubbyhole/masterpassword
# generate parameter json with NoEcho true
# inject parameter value, see sfn-parameters
