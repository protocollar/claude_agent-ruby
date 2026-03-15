# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "json"
require "fileutils"

class TestClaudeAgentForkSession < ActiveSupport::TestCase
  setup do
    @tmpdir = Dir.mktmpdir
    @session_id = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    @msg1_uuid = "11111111-1111-1111-1111-111111111111"
    @msg2_uuid = "22222222-2222-2222-2222-222222222222"
    @msg3_uuid = "33333333-3333-3333-3333-333333333333"

    @entries = [
      { "type" => "system", "uuid" => @msg1_uuid, "sessionId" => @session_id, "parentUuid" => nil },
      { "type" => "user", "uuid" => @msg2_uuid, "sessionId" => @session_id, "parentUuid" => @msg1_uuid,
        "message" => { "role" => "user", "content" => "Hello" } },
      { "type" => "assistant", "uuid" => @msg3_uuid, "session_id" => @session_id, "parentUuid" => @msg2_uuid,
        "message" => { "role" => "assistant", "content" => "Hi there" } }
    ]

    # Write source session file
    @session_file = File.join(@tmpdir, "#{@session_id}.jsonl")
    File.open(@session_file, "w") do |f|
      @entries.each { |e| f.write("#{JSON.generate(e)}\n") }
    end
  end

  teardown do
    FileUtils.rm_rf(@tmpdir)
  end

  test "basic fork creates new session file" do
    ClaudeAgent::SessionMutations.stub(:find_session_file, @session_file) do
      result = ClaudeAgent::ForkSession.call(@session_id)

      assert_instance_of ClaudeAgent::ForkSessionResult, result
      assert_match ClaudeAgent::SessionPaths::UUID_PATTERN, result.session_id
      refute_equal @session_id, result.session_id

      dest_path = File.join(@tmpdir, "#{result.session_id}.jsonl")
      assert File.exist?(dest_path)
    end
  end

  test "forked entries have remapped UUIDs" do
    ClaudeAgent::SessionMutations.stub(:find_session_file, @session_file) do
      result = ClaudeAgent::ForkSession.call(@session_id)

      dest_path = File.join(@tmpdir, "#{result.session_id}.jsonl")
      forked = File.readlines(dest_path, chomp: true).map { |l| JSON.parse(l) }

      assert_equal 3, forked.size

      # No original UUIDs should remain
      original_uuids = [ @msg1_uuid, @msg2_uuid, @msg3_uuid ]
      forked.each do |entry|
        refute_includes original_uuids, entry["uuid"] if entry["uuid"]
      end
    end
  end

  test "parent-child UUID relationships are preserved" do
    ClaudeAgent::SessionMutations.stub(:find_session_file, @session_file) do
      result = ClaudeAgent::ForkSession.call(@session_id)

      dest_path = File.join(@tmpdir, "#{result.session_id}.jsonl")
      forked = File.readlines(dest_path, chomp: true).map { |l| JSON.parse(l) }

      # Entry 1's parentUuid is nil (root)
      assert_nil forked[0]["parentUuid"]

      # Entry 2's parentUuid should point to entry 1's new uuid
      assert_equal forked[0]["uuid"], forked[1]["parentUuid"]

      # Entry 3's parentUuid should point to entry 2's new uuid
      assert_equal forked[1]["uuid"], forked[2]["parentUuid"]
    end
  end

  test "session IDs are remapped" do
    ClaudeAgent::SessionMutations.stub(:find_session_file, @session_file) do
      result = ClaudeAgent::ForkSession.call(@session_id)

      dest_path = File.join(@tmpdir, "#{result.session_id}.jsonl")
      forked = File.readlines(dest_path, chomp: true).map { |l| JSON.parse(l) }

      forked.each do |entry|
        # Both sessionId and session_id fields should be remapped
        assert_equal result.session_id, entry["sessionId"] if entry.key?("sessionId")
        assert_equal result.session_id, entry["session_id"] if entry.key?("session_id")
      end
    end
  end

  test "truncation at up_to_message_id" do
    ClaudeAgent::SessionMutations.stub(:find_session_file, @session_file) do
      result = ClaudeAgent::ForkSession.call(@session_id, up_to_message_id: @msg2_uuid)

      dest_path = File.join(@tmpdir, "#{result.session_id}.jsonl")
      forked = File.readlines(dest_path, chomp: true).map { |l| JSON.parse(l) }

      # Should only contain entries up to and including msg2
      assert_equal 2, forked.size
    end
  end

  test "truncation with invalid message_id raises" do
    ClaudeAgent::SessionMutations.stub(:find_session_file, @session_file) do
      assert_raises(ArgumentError) do
        ClaudeAgent::ForkSession.call(@session_id, up_to_message_id: "nonexistent-uuid")
      end
    end
  end

  test "title appends custom-title entry" do
    ClaudeAgent::SessionMutations.stub(:find_session_file, @session_file) do
      result = ClaudeAgent::ForkSession.call(@session_id, title: "My forked session")

      dest_path = File.join(@tmpdir, "#{result.session_id}.jsonl")
      forked = File.readlines(dest_path, chomp: true).map { |l| JSON.parse(l) }

      # Original 3 entries + 1 custom-title entry
      assert_equal 4, forked.size

      title_entry = forked.last
      assert_equal "custom-title", title_entry["type"]
      assert_equal "My forked session", title_entry["customTitle"]
      assert_equal result.session_id, title_entry["sessionId"]
    end
  end

  test "invalid session_id raises ArgumentError" do
    assert_raises(ArgumentError) do
      ClaudeAgent::ForkSession.call("not-a-uuid")
    end
  end

  test "missing session raises Error" do
    ClaudeAgent::SessionMutations.stub(:find_session_file, nil) do
      assert_raises(ClaudeAgent::Error) do
        ClaudeAgent::ForkSession.call(@session_id)
      end
    end
  end

  test "delegation from ClaudeAgent module" do
    ClaudeAgent::SessionMutations.stub(:find_session_file, @session_file) do
      result = ClaudeAgent.fork_session(@session_id)

      assert_instance_of ClaudeAgent::ForkSessionResult, result
      assert_match ClaudeAgent::SessionPaths::UUID_PATTERN, result.session_id
    end
  end

  test "ForkSessionResult is a Data type" do
    result = ClaudeAgent::ForkSessionResult.new(session_id: "test-id")
    assert_equal "test-id", result.session_id
    assert result.frozen?
  end
end
