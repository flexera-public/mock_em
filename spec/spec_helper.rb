require 'mock_em'

require 'logger'
require 'timecop'

require 'flexmock'
Spec::Runner.configure do |config|
  config.mock_with :flexmock
end

require 'ruby-debug' # enable debugger support
