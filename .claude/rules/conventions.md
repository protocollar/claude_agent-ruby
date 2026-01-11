# Ruby Conventions

Idiomatic Ruby patterns for well-structured, maintainable gems.

## File Organization

### Directory Structure

Organize by concern with clear architectural layers:

```
lib/
├── gem_name.rb              # Entry point, requires everything
├── gem_name/
│   ├── version.rb           # Version constant only
│   ├── error.rb             # Error hierarchy
│   ├── cli/                 # CLI layer (orchestration)
│   │   ├── base.rb
│   │   └── feature.rb
│   ├── commands/            # Command builders (what to execute)
│   │   ├── base.rb
│   │   └── feature.rb
│   ├── configuration/       # Config loading and validation
│   │   ├── validation.rb
│   │   └── validator/
│   └── utils.rb             # Utility module
```

### Three-Tier Architecture

Separate concerns into distinct layers:

| Layer | Purpose | Example |
|-------|---------|---------|
| CLI | Orchestrates operations, user interaction | `Cli::App#deploy` |
| Commands | Builds command arrays, no execution | `Commands::App#run` |
| Configuration | Loads, validates, provides config | `Configuration::Role` |

### Entry Point Pattern

The main file loads dependencies and defines the top-level interface:

```ruby
# lib/gem_name.rb
require_relative "gem_name/version"
require_relative "gem_name/error"
require_relative "gem_name/configuration"
# ... other requires

module GemName
  class Error < StandardError; end
  class ConfigurationError < Error; end

  class << self
    def query(prompt, **options)
      # Convenience method for common use case
    end
  end
end
```

## Module & Class Patterns

### Mixins over Deep Inheritance

Compose behavior using modules:

```ruby
class App < Base
  include Assets, Containers, Logging, Proxy
end
```

### ActiveSupport::Concern

Structure mixins with clear class/instance separation:

```ruby
module Validation
  extend ActiveSupport::Concern

  class_methods do
    def validation_doc
      @validation_doc ||= load_validation_doc
    end
  end

  def validate!(config, context:, with: Validator)
    with.new(config, context: context).validate!
  end
end
```

### Delegation

Reduce boilerplate with `delegate`:

```ruby
class Configuration
  delegate :service, :hooks_path, to: :raw_config, allow_nil: true
  delegate :escape_shell_value, :argumentize, to: Utils
end

class Boot
  delegate :execute, :capture_with_info, to: :sshkit
  delegate :assets?, :running_proxy?, to: :role
end
```

### Factory Methods

Prefer factory class methods over complex constructors:

```ruby
class << self
  def create_from(file:, version: nil)
    new(load_file(file), version: version)
  end

  private

  def load_file(path)
    # ...
  end
end
```

### Inquiry Objects

Use ActiveSupport's `inquiry` for readable predicates:

```ruby
def initialize(name, config:)
  @name = name.inquiry
  @config = config
end

# Later:
role.name.web?      # => true if name is "web"
role.name.worker?   # => true if name is "worker"
```

## Error Handling

### Simple Hierarchy

Inherit directly from `StandardError` with clear namespacing:

```ruby
module GemName
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class ProcessError < Error; end

  module Cli
    class BootError < StandardError; end
    class LockError < StandardError; end
  end
end
```

### Context in Errors

Include relevant context as attributes:

```ruby
class ProcessError < Error
  attr_reader :exit_code, :stderr

  def initialize(message, exit_code: nil, stderr: nil)
    @exit_code = exit_code
    @stderr = stderr
    super(message)
  end
end
```

## Method Organization

### Public/Private Separation

Keep implementation details private. Use Rails-style indentation under `private`:

```ruby
class Command
  # Public interface
  def execute(host:)
    build_command(host).tap { |cmd| validate!(cmd) }
  end

  private
    def build_command(host)
      # Implementation detail
    end

    def validate!(cmd)
      # Implementation detail
    end
end
```

### Group Related Helpers

```ruby
private
  # --- Command Building ---

  def combine(*commands, by: "&&")
    commands.compact.flatten.join(" #{by} ")
  end

  def chain(*commands)
    combine(*commands, by: ";")
  end

  def pipe(*commands)
    combine(*commands, by: "|")
  end

  # --- Validation ---

  def valid_name?(name)
    name.match?(/\A[a-z0-9_-]+\z/)
  end
```

### Naming Conventions

| Element      | Convention                 | Example                                   |
|--------------|----------------------------|-------------------------------------------|
| Predicates   | `?` suffix                 | `valid?`, `running?`, `configured?`       |
| Mutators     | `!` suffix                 | `validate!`, `reset!`, `configure!`       |
| Setters      | `=` suffix                 | `name=`, `options=`                       |
| Converters   | `to_*` prefix              | `to_h`, `to_json`, `to_cli_args`          |
| Builders     | `build_*` prefix           | `build_command`, `build_options`          |
| Initializers | `initialize_*` prefix      | `initialize_env`, `initialize_proxy`      |
| Validators   | `ensure_*` or `validate_*` | `ensure_required_keys`, `validate_config` |

## Configuration & Validation

### Validate at Construction

Don't defer validation:

```ruby
def initialize(name, config:)
  @name = name.inquiry
  @config = config

  validate! \
    config,
    context: "accessories/#{name}",
    with: Validator::Accessory

  @env = initialize_env
  @proxy = initialize_proxy if running_proxy?
end
```

### Validator Classes

Dedicated validator with context tracking:

```ruby
class Validator
  attr_reader :config, :example, :context

  def initialize(config, example:, context:)
    @config = config
    @example = example
    @context = context
  end

  def validate!
    ensure_required_keys_present
    validate_against_example
  end

  private
    def with_context(key)
      "#{context}/#{key}"
    end

    def error(message)
      raise ConfigurationError, "[#{context}] #{message}"
    end
end
```

### Validation Mixin

Reusable validation behavior:

```ruby
module Validation
  extend ActiveSupport::Concern

  class_methods do
    def validation_config_key
      name.demodulize.underscore
    end
  end

  def validate!(config, context: nil, with: Validator)
    context ||= self.class.validation_config_key
    with.new(config, example: validation_example, context: context).validate!
  end
end

class Accessory
  include Validation

  def initialize(name, config:)
    @name = name
    validate!(config, context: "accessories/#{name}")
  end
end
```

### Lazy Initialization

Use `||=` for computed properties:

```ruby
def tags
  @tags ||= raw_config.fetch("tags", []).map { |t| Tag.new(t) }
end

def env_tags
  @env_tags ||= if (tags = raw_config.env["tags"])
    tags.map { |name, config| Env::Tag.new(name, config: config) }
  else
    []
  end
end
```

## Command Pattern

### Return Data, Don't Execute

Build command representations rather than executing directly:

```ruby
def run(hostname: nil)
  docker :run,
    "--detach",
    "--restart unless-stopped",
    "--name", container_name,
    *env_args(host),
    image,
    cmd
end

# Returns: [:docker, :run, "--detach", ..., "image:tag", "cmd"]
```

This enables:
- Testing without execution
- Command composition
- Auditing what will run
- SSH tunneling via execution layer

### Private Helpers for Command Building

```ruby
private
  def combine(*commands, by: "&&")
    commands
      .compact
      .collect { |command| Array(command) + [by] }.flatten
      .tap { |commands| commands.pop }
  end

  def docker(*args)
    args.compact.unshift(:docker)
  end

  def pipe(*commands)
    combine(*commands, by: "|")
  end

  def chain(*commands)
    combine(*commands, by: ";")
  end
```

## Utility Modules

### Extend Self Pattern

```ruby
module Utils
  extend self

  def escape_shell_value(value)
    Shellwords.escape(value.to_s)
  end

  def argumentize(argument, attributes, sensitive: false)
    Array(attributes).flat_map do |key, value|
      [argument, sensitive ? Sensitive.new(value) : value]
    end
  end

  def filter_specific_items(filters, items)
    filters.empty? ? items : items.select { |item| filters.include?(item) }
  end
end

# Usage: Utils.escape_shell_value(val)
# Or via delegation: delegate :escape_shell_value, to: Utils
```

## Testing Patterns

### Test Framework

Use Minitest with ActiveSupport::TestCase:

```ruby
class ConfigurationTest < ActiveSupport::TestCase
  setup do
    @deploy = { service: "app", image: "app:latest" }
    @config = Configuration.new(@deploy)
  end

  teardown do
    # Clean up
  end

  test "service name valid" do
    assert_nothing_raised do
      Configuration.new(@deploy.merge(service: "valid-name"))
    end
  end

  test "raises on invalid service name" do
    assert_raises(ConfigurationError) do
      Configuration.new(@deploy.merge(service: "INVALID"))
    end
  end
end
```

### Custom Test Base Classes

Share setup across tests:

```ruby
class CliTestCase < ActiveSupport::TestCase
  setup do
    @original_env = ENV.to_h
    ENV["VERSION"] = "test"
  end

  teardown do
    ENV.replace(@original_env)
  end

  private
    def stub_setup
      # Shared test helpers
    end
end

class CommandsTestCase < ActiveSupport::TestCase
  setup do
    @config = Configuration.new(default_config)
  end

  private
    def default_config
      { service: "app", image: "app:latest" }
    end
end
```

### Mocking with Mocha

```ruby
require "mocha/minitest"

class ClientTest < ActiveSupport::TestCase
  test "spawns subprocess with correct args" do
    Process.expects(:spawn).with(
      "claude", "--print", "--output-format", "json",
      has_entries(chdir: "/tmp")
    ).returns(123)

    client.start
  end

  test "handles timeout" do
    transport = Transport.new
    transport.stubs(:read_line).raises(Timeout::Error)

    assert_raises(TimeoutError) { transport.receive }
  end
end
```

### Stubbing Methods

```ruby
test "uses custom model when specified" do
  options = Options.new(model: "opus")
  options.stubs(:validate!).returns(true)

  assert_equal "opus", options.model
end

test "retries on connection failure" do
  sequence = sequence("retry")

  client.expects(:connect).in_sequence(sequence).raises(ConnectionError)
  client.expects(:connect).in_sequence(sequence).returns(true)

  client.connect_with_retry
end
```

## Code Style

### Frozen String Literals

Every file starts with:

```ruby
# frozen_string_literal: true
```

### Hash Formatting

```ruby
# Single line for few keys
{ name: "value", type: :string }

# Multi-line for many keys or nested structures
{
  name: "value",
  type: :string,
  options: {
    required: true,
    default: nil
  }
}
```

### Method Chaining

```ruby
# Fluent interfaces return self
def configure(key, value)
  @config[key] = value
  self
end

# Usage
builder.configure(:timeout, 30).configure(:retries, 3)
```

### Guard Clauses

Prefer early returns:

```ruby
def process(input)
  return if input.nil?
  return default_value if input.empty?

  # Main logic
end
```

### Line Continuation

Use backslash for method calls spanning lines:

```ruby
validate! \
  config,
  example: validation_yml["accessories"]["mysql"],
  context: "accessories/#{name}",
  with: Validator::Accessory
```

## Advanced Patterns

### Global Coordinator (Use Sparingly)

For CLI applications that need shared state:

```ruby
# lib/gem_name/cli.rb
COORDINATOR = Coordinator.new

class Cli::Base
  def initialize(*)
    super
    initialize_coordinator unless COORDINATOR.configured?
  end
end
```

### Factory Methods in Coordinator

```ruby
class Coordinator
  def app(role: nil, host: nil)
    Commands::App.new(config, role: role, host: host)
  end

  def builder
    @builder ||= Commands::Builder.new(config)
  end

  def configured?
    @config.present?
  end
end
```
