require "frizz/version"
require "colorize"

module Frizz
  autoload :Site, "frizz/site"
  autoload :Local, "frizz/local"
  autoload :Remote, "frizz/remote"
  autoload :Distribution, "frizz/distribution"
  autoload :Sync, "frizz/sync"
  autoload :Configuration, "frizz/configuration"
  autoload :Environment, "frizz/environment"
  autoload :NullEnvironment, "frizz/null_environment"
  autoload :Ignorance, "frizz/ignorance"

  class << self
    def configure
      yield(configuration)
    end

    def configuration
      @configuration ||= Configuration.new
    end
  end
end
