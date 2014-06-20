# MockEM
[![Gem Version](https://badge.fury.io/rb/mock_em.svg)](http://badge.fury.io/rb/mock_em)
[![Build Status](https://travis-ci.org/rightscale/mock_em.png)](https://travis-ci.org/rightscale/mock_em)
[![Dependency Status](https://gemnasium.com/rightscale/mock_em.svg)](https://gemnasium.com/rightscale/mock_em)

MockEM provides the same interface as [EM](https://github.com/eventmachine/eventmachine/) (a.k.a. [EventMachine](https://github.com/eventmachine/eventmachine/)), but simulates the passage of time to execute your 
scheduled actions without delay. It is intended for use in tests.

Uses [Timecop](https://github.com/travisjeffery/timecop) for simulating the passage of time.

## Getting Started
You'll need to add `require 'mock_em'`, as well as `require 'timecop'`.

At the beginning of your spec you can use the following snippet to mock EM within the scope of that spec.

```ruby
# mock & restore EM
before(:all) do
  @logger = Logger.new(STDOUT)  # <-- Choose your own logger, as appropriate
    
  # Mock EM
  @orig_EM = EM
  EM = MockEM::MockEM.new(@logger, Timecop)
end
after(:all) do
  EM = @orig_EM
  Timecop.return
end
```

Any references to `EM` will then be using MockEM.

As a quick demonstration, the following code has a timer that would wait for 8 minutes with EM, but with MockEM it completes instantaneously:
 
```ruby
require 'timecop'
require 'mock_em'
logger = Logger.new(STDOUT)
em = MockEM::MockEM.new(logger, Timecop)

em.run do
  em.add_timer(8 * 60) do
    puts "Done!"
    em.stop
  end
end    
```

## Supported Features
MockEM supports many of the features of EM. Example of supported methods:

  - Reactor: `run`, `stop`, `reactor_running?`
  - Timers: `next_tick`, `add_timer`, `add_periodic_timer`, `cancel_timer`, `get_max_timer_count`
  - Hooks: `add_shutdown_hook`, `error_handler`

Refer to `mock_em_spec.rb` for more details, as it runs the same set of specs against both `MockEM` and `EM`,
to verify the behavior is identical.

## Unsupported Features
Your mileage may vary.

## TODO
  - [ ] add Travis CI integration for specs

## Compatibility
Ruby 1.8.7 and above is supported.

## Contributing
Pull requests welcome.

If you'd like to add missing functionality, you can use `mock_em_spec.rb` to verify that the behavior is identical in both `MockEM` and `EM`. 

Maintained by the RightScale "Cornsilk_team"

## License
MIT License, see [LICENSE](LICENSE)
