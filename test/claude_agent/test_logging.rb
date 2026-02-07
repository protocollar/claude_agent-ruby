# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentLogging < ActiveSupport::TestCase
  setup do
    @original_logger = ClaudeAgent.instance_variable_get(:@logger)
    @original_debug = ENV["CLAUDE_AGENT_DEBUG"]
    ClaudeAgent.instance_variable_set(:@logger, nil)
  end

  teardown do
    ClaudeAgent.instance_variable_set(:@logger, @original_logger)
    if @original_debug
      ENV["CLAUDE_AGENT_DEBUG"] = @original_debug
    else
      ENV.delete("CLAUDE_AGENT_DEBUG")
    end
  end

  # --- NullLogger ---

  test "NullLogger is a Logger" do
    logger = ClaudeAgent::NullLogger.new
    assert_kind_of Logger, logger
  end

  test "NullLogger methods return true" do
    logger = ClaudeAgent::NullLogger.new
    assert_equal true, logger.debug("test")
    assert_equal true, logger.info("test")
    assert_equal true, logger.warn("test")
    assert_equal true, logger.error("test")
    assert_equal true, logger.fatal("test")
    assert_equal true, logger.unknown("test")
  end

  test "NullLogger level predicates return false" do
    logger = ClaudeAgent::NullLogger.new
    refute logger.debug?
    refute logger.info?
    refute logger.warn?
    refute logger.error?
    refute logger.fatal?
  end

  test "NullLogger add returns true" do
    logger = ClaudeAgent::NullLogger.new
    assert_equal true, logger.add(Logger::INFO, "test")
  end

  # --- Module-level logger ---

  test "default logger is NullLogger" do
    ENV.delete("CLAUDE_AGENT_DEBUG")
    ClaudeAgent.instance_variable_set(:@logger, nil)
    assert_instance_of ClaudeAgent::NullLogger, ClaudeAgent.logger
  end

  test "logger can be set" do
    custom = Logger.new(StringIO.new)
    ClaudeAgent.logger = custom
    assert_equal custom, ClaudeAgent.logger
  end

  test "logger can be reset to nil for default" do
    ClaudeAgent.logger = Logger.new(StringIO.new)
    ClaudeAgent.instance_variable_set(:@logger, nil)
    assert_instance_of ClaudeAgent::NullLogger, ClaudeAgent.logger
  end

  # --- debug! ---

  test "debug! returns a Logger" do
    result = ClaudeAgent.debug!(output: StringIO.new)
    assert_instance_of Logger, result
  end

  test "debug! sets logger at DEBUG level" do
    ClaudeAgent.debug!(output: StringIO.new)
    assert_equal Logger::DEBUG, ClaudeAgent.logger.level
  end

  test "debug! writes to the specified output" do
    output = StringIO.new
    ClaudeAgent.debug!(output: output)
    ClaudeAgent.logger.info("test") { "hello" }
    assert_match(/hello/, output.string)
  end

  test "debug! uses compact formatter with gem tag and progname" do
    output = StringIO.new
    ClaudeAgent.debug!(output: output)
    ClaudeAgent.logger.info("transport") { "spawned" }
    assert_match(/\[ClaudeAgent\]/, output.string)
    assert_match(/transport: spawned/, output.string)
    assert_match(/INFO/, output.string)
  end

  # --- CLAUDE_AGENT_DEBUG env var ---

  test "CLAUDE_AGENT_DEBUG enables debug logger by default" do
    ENV["CLAUDE_AGENT_DEBUG"] = "1"
    ClaudeAgent.instance_variable_set(:@logger, nil)
    logger = ClaudeAgent.logger
    refute_instance_of ClaudeAgent::NullLogger, logger
    assert_equal Logger::DEBUG, logger.level
  end

  test "CLAUDE_AGENT_DEBUG not set uses NullLogger" do
    ENV.delete("CLAUDE_AGENT_DEBUG")
    ClaudeAgent.instance_variable_set(:@logger, nil)
    assert_instance_of ClaudeAgent::NullLogger, ClaudeAgent.logger
  end

  # --- Options#logger ---

  test "Options#logger defaults to nil" do
    options = ClaudeAgent::Options.new
    assert_nil options.logger
  end

  test "Options#logger can be set" do
    custom = Logger.new(StringIO.new)
    options = ClaudeAgent::Options.new(logger: custom)
    assert_equal custom, options.logger
  end

  test "Options#effective_logger returns instance logger when set" do
    custom = Logger.new(StringIO.new)
    options = ClaudeAgent::Options.new(logger: custom)
    assert_equal custom, options.effective_logger
  end

  test "Options#effective_logger falls back to module logger" do
    module_logger = Logger.new(StringIO.new)
    ClaudeAgent.logger = module_logger
    options = ClaudeAgent::Options.new
    assert_equal module_logger, options.effective_logger
  end

  test "Options#logger is not serialized to CLI args" do
    custom = Logger.new(StringIO.new)
    options = ClaudeAgent::Options.new(logger: custom)
    args = options.to_cli_args
    refute args.any? { |a| a.include?("logger") }
  end
end
