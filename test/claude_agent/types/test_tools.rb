# frozen_string_literal: true

require "test_helper"

class TestClaudeAgentTypesTools < ActiveSupport::TestCase
  # --- ToolsPreset ---

  test "tools_preset" do
    preset = ClaudeAgent::ToolsPreset.new(preset: "claude_code")
    assert_equal "preset", preset.type
    assert_equal "claude_code", preset.preset
  end

  test "tools_preset_to_h" do
    preset = ClaudeAgent::ToolsPreset.new(preset: "claude_code")
    assert_equal({ type: "preset", preset: "claude_code" }, preset.to_h)
  end

  # --- SlashCommand ---

  test "slash_command" do
    cmd = ClaudeAgent::SlashCommand.new(
      name: "commit",
      description: "Create a commit",
      argument_hint: "[message]"
    )
    assert_equal "commit", cmd.name
    assert_equal "Create a commit", cmd.description
    assert_equal "[message]", cmd.argument_hint
  end

  test "slash_command_defaults" do
    cmd = ClaudeAgent::SlashCommand.new(name: "help")
    assert_nil cmd.description
    assert_nil cmd.argument_hint
  end
end
