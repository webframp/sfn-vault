# SparkleFormation Vault Callback

Provides a mechanism to read dynamic credentials for use with AWS Orchestration
APIs from a [Vault](https://www.vaultproject.io/intro/getting-started/dynamic-secrets.html) secret backend.

Also provides a method to set and store template parameters in a configured
Vault instance. This is implemented by handling a custom parameter 'type'.

**This is early alpha quality code**

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

### Vault Pseudo Parameters
Cloudformation parameters can have
optional
[AWS-Specific Parameter Types](http://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/parameters-section-structure.html?shortFooter=true#aws-specific-parameter-types).
In a similar way this callback looks for a special parameter type named
`Vault::Generic::Secret` and will dynamically get or set a key value from Vault.
The key will be named to match the parameters name. Then the parameter type in the
template is changed to 'String' which can be understood by AWS.

Generally these should be set as `NoEcho` parameters and a dsl helper method is
provided to generate this type of named parameter.

Example usage in template:
~~~ruby
vault_parameter!(:secret_value)
~~~

Will result in a template with the following parameter defined:
~~~json
"Parameters": {
  "SecretValue": {
    "NoEcho": true,
    "Description": "Generated secret automatically stored in Vault",
    "Type": "String"
  }
}
~~~

And the value of this parameter will be stored and retrieved from a Vault key by default named:

~~~
cubbyhole/
~~~

The value will be stored in vault and retrieved dynamically at stack creation
time. If the `sfn` command is running in a CI environment, where the `CI`
environment variable is set, then the callback will attempt to use the default
generic secret backed path in a stack specific location.

For local development needs or if this environment variable is undetected the
vault cubbyhole is used.

The path is configurable by using the `:pseudo_parameter_path` in the sfn config:

~~~ruby
...
vault do
  pseudo_parameter_path "/secret/aws_secrets"
end
~~~

By default 15 character base64 strings are generated using SecureRandom. The
length can be adjusted by setting `:pseudo_parameter_length` in the config to
any integer value.

# Info

* Repository: https://github.com/webframp/sfn-vault
* IRC: Freenode @ #sparkleformation
