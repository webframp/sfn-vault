# SparkleFormation Vault Read Callback

Provides a mechanism to read dynamic credentials for use with AWS Orchestration
APIs from a [Vault](https://www.vaultproject.io/intro/getting-started/dynamic-secrets.html) secret backend.

Currently supported cloud providers:

* AWS

On initial usage this will read the configured vault path to obtain temporary
aws credentials and cache them locally in `.sfn-vault`. When the lease expires a
new credential will be requested.

## Usage

Make the callback available by adding it to the bundle via the
project's Gemfile:

~~~ruby
group :sfn do
  gem 'sfn-vault'
end
~~~

### Vault Read

#### Enable

The `sfn-vault` callback is configured via the `.sfn`
configuration file. First the callback must be enabled:

~~~ruby
Configuration.new do
  callbacks do
    require ['sfn-vault']
    default ['vault_read']
  end
end
~~~

#### Configuration

The default read path is `aws/creds/deploy` and will be used without
configuration but it is customizable. 

Vault read configuration is controlled within the `.sfn` file:

~~~ruby

Configuration.new
  credentials do
    #  Remote provider name
    provider :aws
    #  AWS credentials information can be empty
    aws_access_key_id ""
    aws_secret_access_key ""
    aws_region 'us-east-1'
    aws_bucket_region 'us-east-1'
    # read path for vault client
    vault_read_path 'awsqa/creds/auto_deploy'
  end
end
~~~

The vault read callback will look for `VAULT_ADDR` and `VAULT_TOKEN` environment
variables by default, or you can set `vault_addr` and `vault_token` in the vault
section of your configuration. It is generally best to set these as environment
variables since the `.sfn `file should be checked into version control.

The following additional parameters can be adjusted by adding a `vault` section
to your `.sfn` config:

~~~ruby
Configuration.new
  vault do
    vault_addr 'http://127.0.0.1:8200'
    vault_token 'vault-access-token'
    # globally disable vault read callback
    status 'disabled'
    # customize the name of cache file
    cache_file '.sfn-vault'
    # customize vault api client retries
    retries 5
    # number of seconds to wait for iam creds to be ready
    iam_delay 15
  end
end
~~~

# Info

* Repository: https://github.com/webframp/sfn-vault
* IRC: Freenode @ #sparkleformation
