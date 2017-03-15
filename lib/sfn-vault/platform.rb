require 'sfn-vault'

module SfnVault
  module Platform

    # Return true if we are running on Windows.
    #
    # @return [Boolean]
    #
    def self.windows?
      # Ruby only sets File::ALT_SEPARATOR on Windows, and the Ruby standard
      # library uses that to test what platform it's on.
      # https://github.com/rest-client/rest-client/blob/master/lib/restclient/platform.rb#L17
      !!File::ALT_SEPARATOR
    end
  end
end
