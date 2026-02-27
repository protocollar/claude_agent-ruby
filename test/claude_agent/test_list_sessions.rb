# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"
require "json"
require "set"

class TestClaudeAgentListSessions < ActiveSupport::TestCase
  SESSION_UUID_1 = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
  SESSION_UUID_2 = "b2c3d4e5-f6a7-8901-bcde-f12345678901"
  SESSION_UUID_3 = "c3d4e5f6-a7b8-9012-cdef-123456789012"

  setup do
    @tmpdir = Dir.mktmpdir("claude_test")
    @projects_dir = File.join(@tmpdir, "projects")
    FileUtils.mkdir_p(@projects_dir)

    # Override config dir for tests
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

  # --- SessionInfo Type ---

  test "session_info has all fields" do
    info = ClaudeAgent::SessionInfo.new(
      session_id: SESSION_UUID_1,
      summary: "Fix login bug",
      last_modified: 1706000000000,
      file_size: 4096,
      custom_title: "Login fix",
      first_prompt: "Help me fix the login page",
      git_branch: "fix/login",
      cwd: "/Users/dev/myapp"
    )
    assert_equal SESSION_UUID_1, info.session_id
    assert_equal "Fix login bug", info.summary
    assert_equal 1706000000000, info.last_modified
    assert_equal 4096, info.file_size
    assert_equal "Login fix", info.custom_title
    assert_equal "Help me fix the login page", info.first_prompt
    assert_equal "fix/login", info.git_branch
    assert_equal "/Users/dev/myapp", info.cwd
  end

  test "session_info optional fields default to nil" do
    info = ClaudeAgent::SessionInfo.new(
      session_id: SESSION_UUID_1,
      summary: "Test",
      last_modified: 0,
      file_size: 0
    )
    assert_nil info.custom_title
    assert_nil info.first_prompt
    assert_nil info.git_branch
    assert_nil info.cwd
  end

  test "session_info is frozen" do
    info = ClaudeAgent::SessionInfo.new(
      session_id: SESSION_UUID_1,
      summary: "Test",
      last_modified: 0,
      file_size: 0
    )
    assert info.frozen?
  end

  # --- Directory Encoding ---

  test "encode_project_dir replaces non-alphanumeric with dashes" do
    result = ClaudeAgent::SessionPaths.encode_project_dir("/Users/tom/myproject")
    assert_equal "-Users-tom-myproject", result
  end

  test "encode_project_dir preserves alphanumeric characters" do
    result = ClaudeAgent::SessionPaths.encode_project_dir("abc123")
    assert_equal "abc123", result
  end

  test "encode_project_dir truncates long paths with hash suffix" do
    long_path = "/Users/very/" + "a" * 300 + "/project"
    result = ClaudeAgent::SessionPaths.encode_project_dir(long_path)

    assert result.length > 200, "result should be longer than 200 (slug + hash)"
    assert result.start_with?("-Users-very-")
    # Should have the truncated slug followed by a hash
    parts = result.split("-")
    assert parts.length > 1
  end

  test "encode_project_dir short path is not truncated" do
    path = "/Users/dev/code"
    result = ClaudeAgent::SessionPaths.encode_project_dir(path)
    assert result.length <= 200
    assert_equal "-Users-dev-code", result
  end

  test "java_string_hash matches TypeScript DM function" do
    # Test with known values - the algorithm is: hash = ((hash << 5) - hash + charCode) | 0
    hash = ClaudeAgent::SessionPaths.java_string_hash("test")
    assert_instance_of String, hash
    refute_empty hash
    # The hash should be a base-36 string
    assert_match(/\A[0-9a-z]+\z/, hash)
  end

  test "java_string_hash is deterministic" do
    hash1 = ClaudeAgent::SessionPaths.java_string_hash("/Users/tom/project")
    hash2 = ClaudeAgent::SessionPaths.java_string_hash("/Users/tom/project")
    assert_equal hash1, hash2
  end

  test "java_string_hash differs for different inputs" do
    hash1 = ClaudeAgent::SessionPaths.java_string_hash("/Users/tom/project1")
    hash2 = ClaudeAgent::SessionPaths.java_string_hash("/Users/tom/project2")
    refute_equal hash1, hash2
  end

  # --- Empty Projects Directory ---

  test "list_sessions returns empty array when projects dir is empty" do
    result = ClaudeAgent.list_sessions
    assert_equal [], result
  end

  test "list_sessions returns empty array when projects dir does not exist" do
    FileUtils.rm_rf(@projects_dir)
    result = ClaudeAgent.list_sessions
    assert_equal [], result
  end

  # --- Single Session ---

  test "list_sessions parses a single session file" do
    project_dir = create_project_dir("/Users/dev/myapp")
    create_session_file(project_dir, SESSION_UUID_1, [
      user_message("Help me fix the login bug"),
      assistant_message("Sure, let me look at the code"),
      result_message(summary: "Fixed login bug")
    ])

    sessions = ClaudeAgent.list_sessions
    assert_equal 1, sessions.length

    session = sessions.first
    assert_instance_of ClaudeAgent::SessionInfo, session
    assert_equal SESSION_UUID_1, session.session_id
    assert_equal "Fixed login bug", session.summary
    assert_equal "Help me fix the login bug", session.first_prompt
    assert session.file_size > 0
    assert session.last_modified > 0
  end

  # --- Multiple Sessions ---

  test "list_sessions returns multiple sessions sorted by last_modified desc" do
    project_dir = create_project_dir("/Users/dev/myapp")

    # Create files with different mtimes
    path1 = create_session_file(project_dir, SESSION_UUID_1, [
      user_message("First session")
    ])
    sleep 0.05 # Ensure different mtime
    path2 = create_session_file(project_dir, SESSION_UUID_2, [
      user_message("Second session")
    ])

    sessions = ClaudeAgent.list_sessions
    assert_equal 2, sessions.length
    # Most recent first
    assert_equal SESSION_UUID_2, sessions[0].session_id
    assert_equal SESSION_UUID_1, sessions[1].session_id
    assert sessions[0].last_modified >= sessions[1].last_modified
  end

  # --- Limit Parameter ---

  test "list_sessions respects limit parameter" do
    project_dir = create_project_dir("/Users/dev/myapp")
    create_session_file(project_dir, SESSION_UUID_1, [ user_message("One") ])
    sleep 0.05
    create_session_file(project_dir, SESSION_UUID_2, [ user_message("Two") ])
    sleep 0.05
    create_session_file(project_dir, SESSION_UUID_3, [ user_message("Three") ])

    sessions = ClaudeAgent.list_sessions(limit: 2)
    assert_equal 2, sessions.length
    # Should return the 2 most recent
    assert_equal SESSION_UUID_3, sessions[0].session_id
    assert_equal SESSION_UUID_2, sessions[1].session_id
  end

  test "list_sessions with limit larger than total returns all" do
    project_dir = create_project_dir("/Users/dev/myapp")
    create_session_file(project_dir, SESSION_UUID_1, [ user_message("One") ])

    sessions = ClaudeAgent.list_sessions(limit: 100)
    assert_equal 1, sessions.length
  end

  # --- Dir Parameter ---

  test "list_sessions with dir scopes to specific project" do
    dir1 = create_project_dir("/Users/dev/app1")
    dir2 = create_project_dir("/Users/dev/app2")
    create_session_file(dir1, SESSION_UUID_1, [ user_message("App1 session") ])
    create_session_file(dir2, SESSION_UUID_2, [ user_message("App2 session") ])

    sessions = ClaudeAgent.list_sessions(dir: "/Users/dev/app1")
    assert_equal 1, sessions.length
    assert_equal SESSION_UUID_1, sessions.first.session_id
  end

  test "list_sessions with dir returns empty for unknown project" do
    sessions = ClaudeAgent.list_sessions(dir: "/nonexistent/project")
    assert_equal [], sessions
  end

  # --- Sidechain Filtering ---

  test "list_sessions filters out sidechain sessions" do
    project_dir = create_project_dir("/Users/dev/myapp")

    # Sidechain session (isSidechain on first line)
    create_session_file(project_dir, SESSION_UUID_1, [
      { type: "system", message: { content: "init" }, isSidechain: true }
    ])

    # Normal session
    create_session_file(project_dir, SESSION_UUID_2, [
      user_message("Normal session")
    ])

    sessions = ClaudeAgent.list_sessions
    assert_equal 1, sessions.length
    assert_equal SESSION_UUID_2, sessions.first.session_id
  end

  # --- Team Session Filtering ---

  test "list_sessions filters out team sessions" do
    project_dir = create_project_dir("/Users/dev/myapp")

    # Team session
    create_session_file(project_dir, SESSION_UUID_1, [
      { type: "system", message: { content: "init" }, teamName: "my-team" }
    ])

    # Normal session
    create_session_file(project_dir, SESSION_UUID_2, [
      user_message("Normal session")
    ])

    sessions = ClaudeAgent.list_sessions
    assert_equal 1, sessions.length
    assert_equal SESSION_UUID_2, sessions.first.session_id
  end

  # --- Invalid Filenames ---

  test "list_sessions skips non-UUID filenames" do
    project_dir = create_project_dir("/Users/dev/myapp")

    # Valid session
    create_session_file(project_dir, SESSION_UUID_1, [ user_message("Valid") ])

    # Invalid filenames
    File.write(File.join(project_dir, "not-a-uuid.jsonl"), "{}\n")
    File.write(File.join(project_dir, "12345.jsonl"), "{}\n")
    File.write(File.join(project_dir, "readme.txt"), "not a session\n")

    sessions = ClaudeAgent.list_sessions
    assert_equal 1, sessions.length
    assert_equal SESSION_UUID_1, sessions.first.session_id
  end

  # --- Optional Fields Extraction ---

  test "list_sessions extracts custom_title from tail" do
    project_dir = create_project_dir("/Users/dev/myapp")
    create_session_file(project_dir, SESSION_UUID_1, [
      user_message("Hello"),
      assistant_message("Hi", customTitle: "My Custom Title")
    ])

    sessions = ClaudeAgent.list_sessions
    assert_equal 1, sessions.length
    assert_equal "My Custom Title", sessions.first.custom_title
  end

  test "list_sessions extracts git_branch" do
    project_dir = create_project_dir("/Users/dev/myapp")
    create_session_file(project_dir, SESSION_UUID_1, [
      user_message("Hello"),
      assistant_message("Hi", gitBranch: "feature/cool")
    ])

    sessions = ClaudeAgent.list_sessions
    assert_equal "feature/cool", sessions.first.git_branch
  end

  test "list_sessions extracts cwd from head" do
    project_dir = create_project_dir("/Users/dev/myapp")
    create_session_file(project_dir, SESSION_UUID_1, [
      { type: "system", message: { content: "init" }, cwd: "/Users/dev/myapp" },
      user_message("Hello")
    ])

    sessions = ClaudeAgent.list_sessions
    assert_equal "/Users/dev/myapp", sessions.first.cwd
  end

  # --- Summary Fallback Chain ---

  test "summary uses custom_title when available" do
    project_dir = create_project_dir("/Users/dev/myapp")
    create_session_file(project_dir, SESSION_UUID_1, [
      user_message("Hello"),
      assistant_message("Hi", customTitle: "My Title", summary: "Auto summary")
    ])

    sessions = ClaudeAgent.list_sessions
    assert_equal "My Title", sessions.first.summary
  end

  test "summary falls back to file summary when no custom_title" do
    project_dir = create_project_dir("/Users/dev/myapp")
    create_session_file(project_dir, SESSION_UUID_1, [
      user_message("Hello"),
      result_message(summary: "Auto generated summary")
    ])

    sessions = ClaudeAgent.list_sessions
    assert_equal "Auto generated summary", sessions.first.summary
  end

  test "summary falls back to first_prompt when no summary" do
    project_dir = create_project_dir("/Users/dev/myapp")
    create_session_file(project_dir, SESSION_UUID_1, [
      user_message("Help me fix the login")
    ])

    sessions = ClaudeAgent.list_sessions
    assert_equal "Help me fix the login", sessions.first.summary
  end

  test "summary falls back to (session) when no other info" do
    project_dir = create_project_dir("/Users/dev/myapp")
    # A session with only a system message (no user prompt, no summary)
    create_session_file(project_dir, SESSION_UUID_1, [
      { type: "system", message: { content: "init" } }
    ])

    sessions = ClaudeAgent.list_sessions
    assert_equal "(session)", sessions.first.summary
  end

  # --- First Prompt Extraction ---

  test "first_prompt skips tool_result messages" do
    project_dir = create_project_dir("/Users/dev/myapp")
    create_session_file(project_dir, SESSION_UUID_1, [
      { type: "user", message: { content: [ { type: "tool_result", tool_use_id: "123", content: "result" } ] } },
      user_message("Real prompt")
    ])

    sessions = ClaudeAgent.list_sessions
    assert_equal "Real prompt", sessions.first.first_prompt
  end

  test "first_prompt skips meta messages" do
    project_dir = create_project_dir("/Users/dev/myapp")
    create_session_file(project_dir, SESSION_UUID_1, [
      { type: "user", message: { content: "<session-start-hook>setup</session-start-hook>" }, isMeta: true },
      user_message("Real prompt")
    ])

    sessions = ClaudeAgent.list_sessions
    assert_equal "Real prompt", sessions.first.first_prompt
  end

  test "first_prompt skips meta message patterns" do
    project_dir = create_project_dir("/Users/dev/myapp")
    create_session_file(project_dir, SESSION_UUID_1, [
      user_message("<local-command-stdout>some output</local-command-stdout>"),
      user_message("<session-start-hook>setup</session-start-hook>"),
      user_message("<tick>123</tick>"),
      user_message("Real prompt after meta")
    ])

    sessions = ClaudeAgent.list_sessions
    assert_equal "Real prompt after meta", sessions.first.first_prompt
  end

  test "first_prompt truncates long prompts at 200 chars" do
    project_dir = create_project_dir("/Users/dev/myapp")
    long_prompt = "x" * 250
    create_session_file(project_dir, SESSION_UUID_1, [
      user_message(long_prompt)
    ])

    sessions = ClaudeAgent.list_sessions
    prompt = sessions.first.first_prompt
    assert prompt.length <= 201 # 200 + ellipsis character
    assert prompt.end_with?("\u2026")
  end

  test "first_prompt extracts command name as fallback" do
    project_dir = create_project_dir("/Users/dev/myapp")
    create_session_file(project_dir, SESSION_UUID_1, [
      user_message("<command-name>commit</command-name>")
    ])

    sessions = ClaudeAgent.list_sessions
    assert_equal "commit", sessions.first.first_prompt
  end

  # --- Deduplication ---

  test "list_sessions deduplicates by session_id keeping most recent" do
    dir1 = create_project_dir("/Users/dev/app1")
    dir2 = create_project_dir("/Users/dev/app2")

    # Same session_id in two directories, different mtimes
    create_session_file(dir1, SESSION_UUID_1, [ user_message("Older") ])
    sleep 0.05
    create_session_file(dir2, SESSION_UUID_1, [ user_message("Newer") ])

    sessions = ClaudeAgent.list_sessions
    assert_equal 1, sessions.length
    assert_equal "Newer", sessions.first.first_prompt
  end

  # --- String Scanning ---

  test "extract_first finds first occurrence of JSON key" do
    buffer = '{"foo":"bar","foo":"baz"}'
    result = ClaudeAgent::ListSessions.send(:extract_first, buffer, "foo")
    assert_equal "bar", result
  end

  test "extract_last finds last occurrence of JSON key" do
    buffer = '{"foo":"bar","foo":"baz"}'
    result = ClaudeAgent::ListSessions.send(:extract_last, buffer, "foo")
    assert_equal "baz", result
  end

  test "extract_first returns nil when key not found" do
    buffer = '{"other":"value"}'
    result = ClaudeAgent::ListSessions.send(:extract_first, buffer, "missing")
    assert_nil result
  end

  test "extract handles escaped characters" do
    buffer = '{"msg":"hello \\"world\\""}'
    result = ClaudeAgent::ListSessions.send(:extract_first, buffer, "msg")
    assert_equal 'hello "world"', result
  end

  test "extract handles key with space after colon" do
    buffer = '{"key": "value"}'
    result = ClaudeAgent::ListSessions.send(:extract_first, buffer, "key")
    assert_equal "value", result
  end

  test "extract handles key without space after colon" do
    buffer = '{"key":"value"}'
    result = ClaudeAgent::ListSessions.send(:extract_first, buffer, "key")
    assert_equal "value", result
  end

  # --- Module Method ---

  test "ClaudeAgent.list_sessions delegates to ListSessions.call" do
    ClaudeAgent::ListSessions.expects(:call).with(dir: "/tmp", limit: 5).returns([])
    result = ClaudeAgent.list_sessions(dir: "/tmp", limit: 5)
    assert_equal [], result
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

  def assistant_message(text, **extra)
    {
      type: "assistant",
      message: {
        role: "assistant",
        content: [ { type: "text", text: text } ]
      },
      **extra
    }
  end

  def result_message(summary: nil, **extra)
    msg = {
      type: "result",
      subtype: "success",
      **extra
    }
    msg[:summary] = summary if summary
    msg
  end
end
