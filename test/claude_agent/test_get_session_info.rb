# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"
require "json"

class TestClaudeAgentGetSessionInfo < ActiveSupport::TestCase
  SESSION_UUID = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
  SESSION_UUID_2 = "b2c3d4e5-f6a7-8901-bcde-f12345678901"

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

  test "get_session_info returns session info for existing session" do
    project_dir = create_project_dir("/Users/dev/myapp")
    create_session_file(project_dir, SESSION_UUID, [
      user_message("Hello world"),
      result_message(summary: "Greeted the user")
    ])

    info = ClaudeAgent.get_session_info(SESSION_UUID)

    assert_not_nil info
    assert_instance_of ClaudeAgent::SessionInfo, info
    assert_equal SESSION_UUID, info.session_id
    assert_equal "Greeted the user", info.summary
    assert_equal "Hello world", info.first_prompt
  end

  test "get_session_info returns nil for nonexistent session" do
    info = ClaudeAgent.get_session_info(SESSION_UUID)
    assert_nil info
  end

  test "get_session_info with dir scopes to project" do
    dir1 = create_project_dir("/Users/dev/app1")
    dir2 = create_project_dir("/Users/dev/app2")
    create_session_file(dir1, SESSION_UUID, [ user_message("In app1") ])
    create_session_file(dir2, SESSION_UUID_2, [ user_message("In app2") ])

    info = ClaudeAgent.get_session_info(SESSION_UUID, dir: "/Users/dev/app1")
    assert_not_nil info
    assert_equal SESSION_UUID, info.session_id

    info2 = ClaudeAgent.get_session_info(SESSION_UUID_2, dir: "/Users/dev/app1")
    assert_nil info2
  end

  test "get_session_info raises on invalid UUID" do
    assert_raises(ArgumentError) do
      ClaudeAgent.get_session_info("not-a-uuid")
    end
  end

  test "get_session_info filters sidechain sessions" do
    project_dir = create_project_dir("/Users/dev/myapp")
    create_session_file(project_dir, SESSION_UUID, [
      { type: "system", message: { content: "init" }, isSidechain: true }
    ])

    info = ClaudeAgent.get_session_info(SESSION_UUID)
    assert_nil info
  end

  test "ClaudeAgent.get_session_info delegates to GetSessionInfo.call" do
    ClaudeAgent::GetSessionInfo.expects(:call).with(SESSION_UUID, dir: "/tmp").returns(nil)
    result = ClaudeAgent.get_session_info(SESSION_UUID, dir: "/tmp")
    assert_nil result
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
