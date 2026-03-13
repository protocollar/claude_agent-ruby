# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"
require "json"

class TestClaudeAgentSessionMutations < ActiveSupport::TestCase
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

  # --- rename_session ---

  test "rename_session appends custom-title entry" do
    project_dir = create_project_dir("/Users/dev/myapp")
    create_session_file(project_dir, SESSION_UUID, [
      { type: "user", message: { role: "user", content: "hello" } }
    ])

    ClaudeAgent.rename_session(SESSION_UUID, "My New Title")

    lines = File.readlines(File.join(project_dir, "#{SESSION_UUID}.jsonl"))
    last_entry = JSON.parse(lines.last)

    assert_equal "custom-title", last_entry["type"]
    assert_equal "My New Title", last_entry["customTitle"]
    assert_equal SESSION_UUID, last_entry["sessionId"]
  end

  test "rename_session raises on invalid UUID" do
    assert_raises(ArgumentError) do
      ClaudeAgent.rename_session("not-a-uuid", "Title")
    end
  end

  test "rename_session raises on empty title" do
    project_dir = create_project_dir("/Users/dev/myapp")
    create_session_file(project_dir, SESSION_UUID, [
      { type: "user", message: { role: "user", content: "hello" } }
    ])

    assert_raises(ArgumentError) do
      ClaudeAgent.rename_session(SESSION_UUID, "")
    end

    assert_raises(ArgumentError) do
      ClaudeAgent.rename_session(SESSION_UUID, nil)
    end
  end

  test "rename_session raises when session not found" do
    assert_raises(ClaudeAgent::Error) do
      ClaudeAgent.rename_session(SESSION_UUID, "Title")
    end
  end

  test "rename_session with dir parameter" do
    project_dir = create_project_dir("/Users/dev/myapp")
    create_session_file(project_dir, SESSION_UUID, [
      { type: "user", message: { role: "user", content: "hello" } }
    ])

    ClaudeAgent.rename_session(SESSION_UUID, "Scoped Title", dir: "/Users/dev/myapp")

    lines = File.readlines(File.join(project_dir, "#{SESSION_UUID}.jsonl"))
    last_entry = JSON.parse(lines.last)
    assert_equal "Scoped Title", last_entry["customTitle"]
  end

  # --- tag_session ---

  test "tag_session appends tag entry" do
    project_dir = create_project_dir("/Users/dev/myapp")
    create_session_file(project_dir, SESSION_UUID, [
      { type: "user", message: { role: "user", content: "hello" } }
    ])

    ClaudeAgent.tag_session(SESSION_UUID, "important")

    lines = File.readlines(File.join(project_dir, "#{SESSION_UUID}.jsonl"))
    last_entry = JSON.parse(lines.last)

    assert_equal "tag", last_entry["type"]
    assert_equal "important", last_entry["tag"]
    assert_equal SESSION_UUID, last_entry["sessionId"]
  end

  test "tag_session clears tag with nil" do
    project_dir = create_project_dir("/Users/dev/myapp")
    create_session_file(project_dir, SESSION_UUID, [
      { type: "user", message: { role: "user", content: "hello" } }
    ])

    ClaudeAgent.tag_session(SESSION_UUID, nil)

    lines = File.readlines(File.join(project_dir, "#{SESSION_UUID}.jsonl"))
    last_entry = JSON.parse(lines.last)

    assert_equal "tag", last_entry["type"]
    assert_equal "", last_entry["tag"]
  end

  test "tag_session sanitizes unicode" do
    project_dir = create_project_dir("/Users/dev/myapp")
    create_session_file(project_dir, SESSION_UUID, [
      { type: "user", message: { role: "user", content: "hello" } }
    ])

    ClaudeAgent.tag_session(SESSION_UUID, "test\u200Btag\u200C")

    lines = File.readlines(File.join(project_dir, "#{SESSION_UUID}.jsonl"))
    last_entry = JSON.parse(lines.last)

    assert_equal "testtag", last_entry["tag"]
  end

  test "tag_session raises on invalid UUID" do
    assert_raises(ArgumentError) do
      ClaudeAgent.tag_session("not-a-uuid", "tag")
    end
  end

  test "tag_session raises when session not found" do
    assert_raises(ClaudeAgent::Error) do
      ClaudeAgent.tag_session(SESSION_UUID, "tag")
    end
  end

  # --- Unicode sanitization ---

  test "sanitize_unicode removes zero-width characters" do
    result = ClaudeAgent::SessionMutations.sanitize_unicode("hello\u200Bworld")
    assert_equal "helloworld", result
  end

  test "sanitize_unicode removes directional marks" do
    result = ClaudeAgent::SessionMutations.sanitize_unicode("hello\u200Eworld\u200F")
    assert_equal "helloworld", result
  end

  test "sanitize_unicode preserves normal text" do
    result = ClaudeAgent::SessionMutations.sanitize_unicode("hello world 123")
    assert_equal "hello world 123", result
  end

  # --- Module method delegation ---

  test "ClaudeAgent.rename_session delegates to SessionMutations" do
    ClaudeAgent::SessionMutations.expects(:rename_session).with(SESSION_UUID, "Title", dir: nil)
    ClaudeAgent.rename_session(SESSION_UUID, "Title")
  end

  test "ClaudeAgent.tag_session delegates to SessionMutations" do
    ClaudeAgent::SessionMutations.expects(:tag_session).with(SESSION_UUID, "tag", dir: nil)
    ClaudeAgent.tag_session(SESSION_UUID, "tag")
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
end
