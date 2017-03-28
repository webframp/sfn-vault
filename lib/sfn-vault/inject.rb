class SparkleFormation
  module SparkleAttribute
    module Aws

      # A small helper method for adding the specific named
      # parameter struct with the custom type
      def _vault_parameter(vp_name)
        __t_stringish(vp_name)
        parameters.set!(vp_name) do
          no_echo true
          description "Generated secret automatically stored in Vault"
          type 'Vault::Generic::Secret'
        end
      end
      alias_method :vault_parameter!, :_vault_parameter
    end
  end
end
