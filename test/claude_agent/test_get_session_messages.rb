# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"
require "json"
require "set"
require "securerandom"

class TestClaudeAgentGetSessionMessages < ActiveSupport::TestCase
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

  # --- SessionMessage Type ---

  test "session_message has all fields" do
    msg = ClaudeAgent::SessionMessage.new(
      type: "user",
      uuid: "abc-123",
      session_id: SESSION_UUID,
      message: { "role" => "user", "content" => "Hello" }
    )
    assert_equal "user", msg.type
    assert_equal "abc-123", msg.uuid
    assert_equal SESSION_UUID, msg.session_id
    assert_equal({ "role" => "user", "content" => "Hello" }, msg.message)
    assert_nil msg.parent_tool_use_id
  end

  test "session_message is frozen" do
    msg = ClaudeAgent::SessionMessage.new(
      type: "user",
      uuid: "abc-123",
      session_id: SESSION_UUID,
      message: {}
    )
    assert msg.frozen?
  end

  # --- Basic Retrieval ---

  test "returns user and assistant messages" do
    create_session([
      system_line,
      user_line("Hello"),
      assistant_line("Hi there")
    ])

    messages = ClaudeAgent.get_session_messages(SESSION_UUID)
    assert_equal 2, messages.length

    assert_equal "user", messages[0].type
    assert_equal "assistant", messages[1].type
    assert_equal SESSION_UUID, messages[0].session_id
    assert_nil messages[0].parent_tool_use_id
  end

  test "returns messages with correct content" do
    create_session([
      user_line("What is Ruby?"),
      assistant_line("Ruby is a programming language")
    ])

    messages = ClaudeAgent.get_session_messages(SESSION_UUID)
    assert_equal 2, messages.length
    assert_equal "What is Ruby?", messages[0].message["content"].first["text"]
    assert_equal "Ruby is a programming language", messages[1].message["content"].first["text"]
  end

  test "returns empty array for missing session" do
    messages = ClaudeAgent.get_session_messages("00000000-0000-0000-0000-000000000000")
    assert_equal [], messages
  end

  test "returns empty array for invalid session ID" do
    messages = ClaudeAgent.get_session_messages("not-a-uuid")
    assert_equal [], messages
  end

  test "returns empty array for empty string" do
    messages = ClaudeAgent.get_session_messages("")
    assert_equal [], messages
  end

  # --- Pagination ---

  test "limit returns at most N messages" do
    create_session([
      user_line("One"),
      assistant_line("Reply one"),
      user_line("Two"),
      assistant_line("Reply two"),
      user_line("Three"),
      assistant_line("Reply three")
    ])

    messages = ClaudeAgent.get_session_messages(SESSION_UUID, limit: 3)
    assert_equal 3, messages.length
    assert_equal "user", messages[0].type
    assert_equal "assistant", messages[1].type
    assert_equal "user", messages[2].type
  end

  test "offset skips messages from the start" do
    create_session([
      user_line("One"),
      assistant_line("Reply one"),
      user_line("Two"),
      assistant_line("Reply two")
    ])

    messages = ClaudeAgent.get_session_messages(SESSION_UUID, offset: 2)
    assert_equal 2, messages.length
    assert_equal "user", messages[0].type
    assert_equal "Two", messages[0].message["content"].first["text"]
  end

  test "limit and offset together" do
    create_session([
      user_line("One"),
      assistant_line("Reply one"),
      user_line("Two"),
      assistant_line("Reply two"),
      user_line("Three"),
      assistant_line("Reply three")
    ])

    messages = ClaudeAgent.get_session_messages(SESSION_UUID, limit: 2, offset: 2)
    assert_equal 2, messages.length
    assert_equal "Two", messages[0].message["content"].first["text"]
    assert_equal "Reply two", messages[1].message["content"].first["text"]
  end

  test "offset beyond total returns empty" do
    create_session([
      user_line("One"),
      assistant_line("Reply one")
    ])

    messages = ClaudeAgent.get_session_messages(SESSION_UUID, offset: 100)
    assert_equal [], messages
  end

  test "limit of zero returns all messages" do
    create_session([
      user_line("One"),
      assistant_line("Reply one")
    ])

    messages = ClaudeAgent.get_session_messages(SESSION_UUID, limit: 0)
    assert_equal 2, messages.length
  end

  # --- Filtering ---

  test "excludes meta messages" do
    create_session([
      user_line("Real prompt"),
      { type: "user", uuid: uuid, sessionId: SESSION_UUID, parentUuid: nil,
        isMeta: true, message: { role: "user", content: [ { type: "text", text: "meta msg" } ] } },
      assistant_line("Response")
    ])

    messages = ClaudeAgent.get_session_messages(SESSION_UUID)
    assert_equal 2, messages.length
    texts = messages.map { |m| m.message["content"].first["text"] }
    refute_includes texts, "meta msg"
  end

  test "excludes sidechain messages" do
    create_session([
      user_line("Main thread"),
      { type: "user", uuid: uuid, sessionId: SESSION_UUID, parentUuid: nil,
        isSidechain: true, message: { role: "user", content: [ { type: "text", text: "sidechain" } ] } },
      assistant_line("Response")
    ])

    messages = ClaudeAgent.get_session_messages(SESSION_UUID)
    assert_equal 2, messages.length
    texts = messages.map { |m| m.message["content"].first["text"] }
    refute_includes texts, "sidechain"
  end

  test "excludes team messages" do
    create_session([
      user_line("Main thread"),
      { type: "user", uuid: uuid, sessionId: SESSION_UUID, parentUuid: nil,
        teamName: "my-team", message: { role: "user", content: [ { type: "text", text: "team msg" } ] } },
      assistant_line("Response")
    ])

    messages = ClaudeAgent.get_session_messages(SESSION_UUID)
    assert_equal 2, messages.length
    texts = messages.map { |m| m.message["content"].first["text"] }
    refute_includes texts, "team msg"
  end

  test "excludes system and progress messages" do
    create_session([
      system_line,
      user_line("Hello"),
      { type: "progress", uuid: uuid, sessionId: SESSION_UUID, parentUuid: nil,
        message: { content: "progress data" } },
      assistant_line("Response")
    ])

    messages = ClaudeAgent.get_session_messages(SESSION_UUID)
    assert_equal 2, messages.length
    assert_equal "user", messages[0].type
    assert_equal "assistant", messages[1].type
  end

  # --- Thread Reconstruction ---

  test "reconstructs linear thread" do
    uuid1 = uuid
    uuid2 = uuid
    uuid3 = uuid
    uuid4 = uuid

    create_session([
      { type: "user", uuid: uuid1, sessionId: SESSION_UUID, parentUuid: nil,
        message: { role: "user", content: [ { type: "text", text: "First" } ] } },
      { type: "assistant", uuid: uuid2, sessionId: SESSION_UUID, parentUuid: uuid1,
        message: { role: "assistant", content: [ { type: "text", text: "Reply first" } ] } },
      { type: "user", uuid: uuid3, sessionId: SESSION_UUID, parentUuid: uuid2,
        message: { role: "user", content: [ { type: "text", text: "Second" } ] } },
      { type: "assistant", uuid: uuid4, sessionId: SESSION_UUID, parentUuid: uuid3,
        message: { role: "assistant", content: [ { type: "text", text: "Reply second" } ] } }
    ])

    messages = ClaudeAgent.get_session_messages(SESSION_UUID)
    assert_equal 4, messages.length
    texts = messages.map { |m| m.message["content"].first["text"] }
    assert_equal [ "First", "Reply first", "Second", "Reply second" ], texts
  end

  test "picks latest branch on fork" do
    root_uuid = uuid
    branch_a = uuid
    branch_b = uuid

    create_session([
      { type: "user", uuid: root_uuid, sessionId: SESSION_UUID, parentUuid: nil,
        message: { role: "user", content: [ { type: "text", text: "Root" } ] } },
      { type: "assistant", uuid: branch_a, sessionId: SESSION_UUID, parentUuid: root_uuid,
        message: { role: "assistant", content: [ { type: "text", text: "Branch A" } ] } },
      { type: "assistant", uuid: branch_b, sessionId: SESSION_UUID, parentUuid: root_uuid,
        message: { role: "assistant", content: [ { type: "text", text: "Branch B" } ] } }
    ])

    messages = ClaudeAgent.get_session_messages(SESSION_UUID)
    assert_equal 2, messages.length
    # Should pick Branch B (later in file = higher index)
    assert_equal "Root", messages[0].message["content"].first["text"]
    assert_equal "Branch B", messages[1].message["content"].first["text"]
  end

  test "prefers main thread over sidechain on fork" do
    root_uuid = uuid
    sidechain_uuid = uuid
    main_uuid = uuid

    create_session([
      { type: "user", uuid: root_uuid, sessionId: SESSION_UUID, parentUuid: nil,
        message: { role: "user", content: [ { type: "text", text: "Root" } ] } },
      # Sidechain appears later in file but should not be preferred
      { type: "assistant", uuid: sidechain_uuid, sessionId: SESSION_UUID, parentUuid: root_uuid,
        isSidechain: true,
        message: { role: "assistant", content: [ { type: "text", text: "Sidechain reply" } ] } },
      { type: "assistant", uuid: main_uuid, sessionId: SESSION_UUID, parentUuid: root_uuid,
        message: { role: "assistant", content: [ { type: "text", text: "Main reply" } ] } }
    ])

    messages = ClaudeAgent.get_session_messages(SESSION_UUID)
    assert_equal 2, messages.length
    assert_equal "Root", messages[0].message["content"].first["text"]
    assert_equal "Main reply", messages[1].message["content"].first["text"]
  end

  test "walks through progress nodes to find user/assistant leaf" do
    user_uuid = uuid
    progress_uuid = uuid
    assistant_uuid = uuid

    create_session([
      { type: "user", uuid: user_uuid, sessionId: SESSION_UUID, parentUuid: nil,
        message: { role: "user", content: [ { type: "text", text: "Hello" } ] } },
      { type: "assistant", uuid: assistant_uuid, sessionId: SESSION_UUID, parentUuid: user_uuid,
        message: { role: "assistant", content: [ { type: "text", text: "Reply" } ] } },
      { type: "progress", uuid: progress_uuid, sessionId: SESSION_UUID, parentUuid: assistant_uuid,
        message: { content: "tool progress" } }
    ])

    messages = ClaudeAgent.get_session_messages(SESSION_UUID)
    assert_equal 2, messages.length
    assert_equal "Hello", messages[0].message["content"].first["text"]
    assert_equal "Reply", messages[1].message["content"].first["text"]
  end

  # --- Edge Cases ---

  test "handles empty session file" do
    project_dir = create_project_dir("/Users/dev/myapp")
    File.write(File.join(project_dir, "#{SESSION_UUID}.jsonl"), "")

    messages = ClaudeAgent.get_session_messages(SESSION_UUID)
    assert_equal [], messages
  end

  test "handles session with only system messages" do
    create_session([ system_line ])

    messages = ClaudeAgent.get_session_messages(SESSION_UUID)
    assert_equal [], messages
  end

  test "skips corrupted JSON lines" do
    project_dir = create_project_dir("/Users/dev/myapp")
    u = user_line("Hello")
    a = assistant_line("Reply")
    a[:parentUuid] = u[:uuid]
    lines = [
      JSON.generate(stringify_keys_deep(u)),
      "this is not json {{{",
      JSON.generate(stringify_keys_deep(a))
    ]
    File.write(File.join(project_dir, "#{SESSION_UUID}.jsonl"), lines.join("\n") + "\n")

    messages = ClaudeAgent.get_session_messages(SESSION_UUID)
    assert_equal 2, messages.length
  end

  test "skips lines without uuid" do
    project_dir = create_project_dir("/Users/dev/myapp")
    lines = [
      JSON.generate({ type: "user", message: { content: "no uuid" } }),
      JSON.generate(user_line("With UUID"))
    ]
    File.write(File.join(project_dir, "#{SESSION_UUID}.jsonl"), lines.join("\n") + "\n")

    messages = ClaudeAgent.get_session_messages(SESSION_UUID)
    assert_equal 1, messages.length
    assert_equal "With UUID", messages[0].message["content"].first["text"]
  end

  # --- Dir Parameter ---

  test "dir scopes search to specific project" do
    dir1 = create_project_dir("/Users/dev/app1")
    dir2 = create_project_dir("/Users/dev/app2")

    u1 = user_line("App1")
    a1 = assistant_line("Reply1")
    a1[:parentUuid] = u1[:uuid]
    write_session_file(dir1, SESSION_UUID, [ u1, a1 ])

    other_uuid = "b2c3d4e5-f6a7-8901-bcde-f12345678901"
    u2 = user_line("App2")
    a2 = assistant_line("Reply2")
    a2[:parentUuid] = u2[:uuid]
    write_session_file(dir2, other_uuid, [ u2, a2 ])

    messages = ClaudeAgent.get_session_messages(SESSION_UUID, dir: "/Users/dev/app1")
    assert_equal 2, messages.length
    assert_equal "App1", messages[0].message["content"].first["text"]
  end

  test "dir returns empty for unknown project" do
    messages = ClaudeAgent.get_session_messages(SESSION_UUID, dir: "/nonexistent/project")
    assert_equal [], messages
  end

  # --- Module Delegation ---

  test "ClaudeAgent.get_session_messages delegates to GetSessionMessages.call" do
    ClaudeAgent::GetSessionMessages.expects(:call)
      .with(SESSION_UUID, dir: "/tmp", limit: 10, offset: 5)
      .returns([])
    result = ClaudeAgent.get_session_messages(SESSION_UUID, dir: "/tmp", limit: 10, offset: 5)
    assert_equal [], result
  end

  private

  def uuid
    SecureRandom.uuid
  end

  def create_project_dir(path)
    slug = ClaudeAgent::SessionPaths.encode_project_dir(path)
    dir = File.join(@projects_dir, slug)
    FileUtils.mkdir_p(dir)
    dir
  end

  def write_session_file(project_dir, session_uuid, lines)
    path = File.join(project_dir, "#{session_uuid}.jsonl")
    content = lines.map { |line| JSON.generate(stringify_keys_deep(line)) }.join("\n") + "\n"
    File.write(path, content)
    path
  end

  # Creates a session file with auto-chained parentUuid links.
  # Messages that don't already have a parentUuid set (or have nil)
  # get chained to the previous message's uuid.
  def create_session(lines)
    project_dir = create_project_dir("/Users/dev/myapp")

    # Auto-chain: set parentUuid to previous message's uuid when not explicitly set
    prev_uuid = nil
    lines.each do |line|
      if line[:parentUuid].nil? && prev_uuid
        line[:parentUuid] = prev_uuid
      end
      prev_uuid = line[:uuid]
    end

    write_session_file(project_dir, SESSION_UUID, lines)
  end

  def stringify_keys_deep(obj)
    case obj
    when Hash
      obj.transform_keys(&:to_s).transform_values { |v| stringify_keys_deep(v) }
    when Array
      obj.map { |v| stringify_keys_deep(v) }
    else
      obj
    end
  end

  def system_line
    { type: "system", uuid: uuid, sessionId: SESSION_UUID, parentUuid: nil,
      message: { content: "init" } }
  end

  def user_line(text)
    { type: "user", uuid: uuid, sessionId: SESSION_UUID, parentUuid: nil,
      message: { role: "user", content: [ { type: "text", text: text } ] } }
  end

  def assistant_line(text)
    { type: "assistant", uuid: uuid, sessionId: SESSION_UUID, parentUuid: nil,
      message: { role: "assistant", content: [ { type: "text", text: text } ] } }
  end
end
