# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"
require "json"

# Round-trip tests: verify that mutations written by append_jsonl
# are correctly picked up by list_sessions and get_session_info.
class TestClaudeAgentSessionRoundtrip < ActiveSupport::TestCase
  SESSION_UUID = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"

  setup do
    @tmpdir = Dir.mktmpdir("claude_test")
    @projects_dir = File.join(@tmpdir, "projects")
    FileUtils.mkdir_p(@projects_dir)

    @original_env = ENV["CLAUDE_CONFIG_DIR"]
    ENV["CLAUDE_CONFIG_DIR"] = @tmpdir
  end

  teardown do
    FileUtils.remove_entry(@tmpdir) if @tmpdir && File.exist?(@tmpdir)
    if @original_env
      ENV["CLAUDE_CONFIG_DIR"] = @original_env
    else
      ENV.delete("CLAUDE_CONFIG_DIR")
    end
  end

  # --- rename_session round-trip ---

  test "rename_session updates summary returned by list_sessions" do
    project_dir = create_project_dir("/Users/dev/myapp")
    create_session_file(project_dir, SESSION_UUID, [
      user_message("Original prompt"),
      result_message(summary: "Original summary")
    ])

    # Verify original summary
    sessions = ClaudeAgent.list_sessions
    assert_equal "Original summary", sessions.first.summary

    # Rename
    ClaudeAgent.rename_session(SESSION_UUID, "Renamed Title")

    # Verify updated summary (custom_title takes precedence)
    sessions = ClaudeAgent.list_sessions
    assert_equal "Renamed Title", sessions.first.summary
    assert_equal "Renamed Title", sessions.first.custom_title
  end

  test "rename_session updates custom_title returned by get_session_info" do
    project_dir = create_project_dir("/Users/dev/myapp")
    create_session_file(project_dir, SESSION_UUID, [
      user_message("Hello")
    ])

    ClaudeAgent.rename_session(SESSION_UUID, "New Title")

    info = ClaudeAgent.get_session_info(SESSION_UUID)
    assert_not_nil info
    assert_equal "New Title", info.custom_title
    assert_equal "New Title", info.summary
  end

  test "multiple renames use the last title" do
    project_dir = create_project_dir("/Users/dev/myapp")
    create_session_file(project_dir, SESSION_UUID, [
      user_message("Hello")
    ])

    ClaudeAgent.rename_session(SESSION_UUID, "First Title")
    ClaudeAgent.rename_session(SESSION_UUID, "Second Title")
    ClaudeAgent.rename_session(SESSION_UUID, "Final Title")

    info = ClaudeAgent.get_session_info(SESSION_UUID)
    assert_equal "Final Title", info.custom_title
  end

  # --- tag_session round-trip ---

  test "tag_session updates tag returned by list_sessions" do
    project_dir = create_project_dir("/Users/dev/myapp")
    create_session_file(project_dir, SESSION_UUID, [
      user_message("Hello")
    ])

    # Verify no tag initially
    sessions = ClaudeAgent.list_sessions
    assert_nil sessions.first.tag

    # Tag
    ClaudeAgent.tag_session(SESSION_UUID, "important")

    # Verify tag
    sessions = ClaudeAgent.list_sessions
    assert_equal "important", sessions.first.tag
  end

  test "tag_session updates tag returned by get_session_info" do
    project_dir = create_project_dir("/Users/dev/myapp")
    create_session_file(project_dir, SESSION_UUID, [
      user_message("Hello")
    ])

    ClaudeAgent.tag_session(SESSION_UUID, "review-needed")

    info = ClaudeAgent.get_session_info(SESSION_UUID)
    assert_not_nil info
    assert_equal "review-needed", info.tag
  end

  test "clearing tag with nil results in nil tag from list_sessions" do
    project_dir = create_project_dir("/Users/dev/myapp")
    create_session_file(project_dir, SESSION_UUID, [
      user_message("Hello")
    ])

    # Set a tag
    ClaudeAgent.tag_session(SESSION_UUID, "tagged")
    sessions = ClaudeAgent.list_sessions
    assert_equal "tagged", sessions.first.tag

    # Clear the tag (nil writes empty string, extract_last returns "" which is truthy but empty)
    ClaudeAgent.tag_session(SESSION_UUID, nil)
    sessions = ClaudeAgent.list_sessions
    # The cleared tag is an empty string (last "tag" value in file)
    assert_equal "", sessions.first.tag
  end

  test "re-tagging overwrites previous tag" do
    project_dir = create_project_dir("/Users/dev/myapp")
    create_session_file(project_dir, SESSION_UUID, [
      user_message("Hello")
    ])

    ClaudeAgent.tag_session(SESSION_UUID, "v1")
    ClaudeAgent.tag_session(SESSION_UUID, "v2")

    info = ClaudeAgent.get_session_info(SESSION_UUID)
    assert_equal "v2", info.tag
  end

  # --- Combined mutations ---

  test "rename and tag together are both reflected" do
    project_dir = create_project_dir("/Users/dev/myapp")
    create_session_file(project_dir, SESSION_UUID, [
      user_message("Hello")
    ])

    ClaudeAgent.rename_session(SESSION_UUID, "My Project")
    ClaudeAgent.tag_session(SESSION_UUID, "starred")

    info = ClaudeAgent.get_session_info(SESSION_UUID)
    assert_equal "My Project", info.custom_title
    assert_equal "My Project", info.summary
    assert_equal "starred", info.tag
    assert_equal "Hello", info.first_prompt
  end

  # --- get_session_info round-trip with offset ---

  test "get_session_info finds session that list_sessions returns with offset" do
    project_dir = create_project_dir("/Users/dev/myapp")
    uuid2 = "b2c3d4e5-f6a7-8901-bcde-f12345678901"

    create_session_file(project_dir, SESSION_UUID, [ user_message("First") ])
    sleep 0.05
    create_session_file(project_dir, uuid2, [ user_message("Second") ])

    # list_sessions with offset=1 skips the most recent
    sessions = ClaudeAgent.list_sessions(offset: 1)
    assert_equal 1, sessions.length
    assert_equal SESSION_UUID, sessions.first.session_id

    # get_session_info can still find both
    info1 = ClaudeAgent.get_session_info(SESSION_UUID)
    info2 = ClaudeAgent.get_session_info(uuid2)
    assert_not_nil info1
    assert_not_nil info2
  end

  private

  def create_project_dir(path)
    slug = ClaudeAgent::SessionPaths.encode_project_dir(path)
    dir = File.join(@projects_dir, slug)
    FileUtils.mkdir_p(dir)
    dir
  end

  def create_session_file(project_dir, uuid, lines)
    path = File.join(project_dir, "#{uuid}.jsonl")
    content = lines.map { |line| JSON.generate(line) }.join("\n") + "\n"
    File.write(path, content)
    path
  end

  def user_message(text)
    {
      type: "user",
      message: {
        role: "user",
        content: [ { type: "text", text: text } ]
      }
    }
  end

  def result_message(summary: nil, **extra)
    msg = { type: "result", subtype: "success", **extra }
    msg[:summary] = summary if summary
    msg
  end
end
