require 'sfn-parameters'

# This module implements helper functions to build a valid X509 bundle on
# for SSL verification based on installed certificates.
module SfnVault
  module CertificateStore

    include SfnVault::Platform

    # Add to an X509 store, ignoring duplicates
    def self.safe_add(cert_store, cert)
      cert_store.add_cert(cert)
    rescue OpenSSL::X509::StoreError => e
      raise unless e.message == 'cert already in hash table'
    end

    # Return a certificate store that can be used to validate certificates with
    # the system certificate authorities. This will probably not do anything on
    # OS X, which monkey patches OpenSSL in terrible ways to insert its own
    # validation. On most *nix platforms, this will add the system certificates
    # using OpenSSL::X509::Store#set_default_paths. On Windows, this will use
    # SfnVault::Windows::RootCerts to look up the CAs trusted by the system.
    #
    # @return [OpenSSL::X509::Store]
    #
    def self.default_ssl_cert_store
      cert_store = OpenSSL::X509::Store.new
      cert_store.set_default_paths
      # set_default_paths() doesn't do anything on Windows, so look up
      # certificates using the win32 API.
      if SfnVault::Platform.windows?
        require 'sfn-vault/windows/root_certs'
        SfnVault::Windows::RootCerts.instance.to_a.uniq.each do |cert|
          safe_add(cert_store, cert)
        end
      end
      cert_store
    end
  end
end
