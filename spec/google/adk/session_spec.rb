# frozen_string_literal: true

require "spec_helper"
require "time"

RSpec.describe Google::ADK::Session do
  let(:session_id) { "session-123" }
  let(:app_name) { "test-app" }
  let(:user_id) { "user-456" }

  describe "#initialize" do
    it "creates a session with required attributes" do
      session = described_class.new(
        id: session_id,
        app_name: app_name,
        user_id: user_id
      )

      expect(session.id).to eq(session_id)
      expect(session.app_name).to eq(app_name)
      expect(session.user_id).to eq(user_id)
    end

    it "initializes with empty state" do
      session = described_class.new(
        id: session_id,
        app_name: app_name,
        user_id: user_id
      )

      expect(session.state).to eq({})
    end

    it "initializes with empty events array" do
      session = described_class.new(
        id: session_id,
        app_name: app_name,
        user_id: user_id
      )

      expect(session.events).to eq([])
    end

    it "sets last_update_time to current time" do
      session = described_class.new(
        id: session_id,
        app_name: app_name,
        user_id: user_id
      )

      expect(session.last_update_time).to be_a(Time)
      expect(session.last_update_time).to be <= Time.now
    end

    it "accepts initial state" do
      initial_state = { "key" => "value" }
      session = described_class.new(
        id: session_id,
        app_name: app_name,
        user_id: user_id,
        state: initial_state
      )

      expect(session.state).to eq(initial_state)
    end

    it "accepts initial events" do
      event = Google::ADK::Event.new(
        invocation_id: "inv-123",
        author: "user"
      )
      session = described_class.new(
        id: session_id,
        app_name: app_name,
        user_id: user_id,
        events: [event]
      )

      expect(session.events).to eq([event])
    end
  end

  describe "#to_h" do
    it "serializes session to hash" do
      session = described_class.new(
        id: session_id,
        app_name: app_name,
        user_id: user_id,
        state: { "key" => "value" }
      )

      hash = session.to_h
      expect(hash[:id]).to eq(session_id)
      expect(hash[:app_name]).to eq(app_name)
      expect(hash[:user_id]).to eq(user_id)
      expect(hash[:state]).to eq({ "key" => "value" })
      expect(hash[:events]).to eq([])
      expect(hash[:last_update_time]).to be_a(String)
    end
  end

  describe ".from_h" do
    it "deserializes session from hash" do
      time = Time.now
      hash = {
        id: session_id,
        app_name: app_name,
        user_id: user_id,
        state: { "key" => "value" },
        events: [],
        last_update_time: time.iso8601
      }

      session = described_class.from_h(hash)
      expect(session.id).to eq(session_id)
      expect(session.app_name).to eq(app_name)
      expect(session.user_id).to eq(user_id)
      expect(session.state).to eq({ "key" => "value" })
      expect(session.last_update_time.to_i).to eq(time.to_i)
    end
  end
end

RSpec.describe Google::ADK::BaseSessionService do
  let(:service) { described_class.new }

  describe "interface methods" do
    %i[create_session get_session update_session append_event delete_session list_sessions].each do |method|
      it "raises NotImplementedError for #{method}" do
        expect { service.send(method) }.to raise_error(NotImplementedError)
      end
    end
  end
end

RSpec.describe Google::ADK::InMemorySessionService do
  let(:service) { described_class.new }
  let(:app_name) { "test-app" }
  let(:user_id) { "user-123" }

  describe "#create_session" do
    it "creates a new session" do
      session = service.create_session(
        app_name: app_name,
        user_id: user_id
      )

      expect(session).to be_a(Google::ADK::Session)
      expect(session.app_name).to eq(app_name)
      expect(session.user_id).to eq(user_id)
      expect(session.id).not_to be_nil
    end

    it "accepts initial state" do
      initial_state = { "key" => "value" }
      session = service.create_session(
        app_name: app_name,
        user_id: user_id,
        initial_state: initial_state
      )

      expect(session.state).to eq(initial_state)
    end

    it "generates unique session IDs" do
      session1 = service.create_session(app_name: app_name, user_id: user_id)
      session2 = service.create_session(app_name: app_name, user_id: user_id)

      expect(session1.id).not_to eq(session2.id)
    end
  end

  describe "#get_session" do
    it "retrieves an existing session" do
      created = service.create_session(app_name: app_name, user_id: user_id)
      
      retrieved = service.get_session(
        app_name: app_name,
        user_id: user_id,
        session_id: created.id
      )

      expect(retrieved).to eq(created)
    end

    it "returns nil for non-existent session" do
      session = service.get_session(
        app_name: app_name,
        user_id: user_id,
        session_id: "non-existent"
      )

      expect(session).to be_nil
    end
  end

  describe "#update_session" do
    it "updates session state" do
      session = service.create_session(app_name: app_name, user_id: user_id)
      
      updated = service.update_session(
        app_name: app_name,
        user_id: user_id,
        session_id: session.id,
        state_updates: { "new_key" => "new_value" }
      )

      expect(updated.state["new_key"]).to eq("new_value")
    end

    it "updates last_update_time" do
      session = service.create_session(app_name: app_name, user_id: user_id)
      old_time = session.last_update_time
      
      sleep 0.01 # Ensure time difference
      updated = service.update_session(
        app_name: app_name,
        user_id: user_id,
        session_id: session.id,
        state_updates: {}
      )

      expect(updated.last_update_time).to be > old_time
    end

    it "returns nil for non-existent session" do
      updated = service.update_session(
        app_name: app_name,
        user_id: user_id,
        session_id: "non-existent",
        state_updates: {}
      )

      expect(updated).to be_nil
    end
  end

  describe "#append_event" do
    it "adds event to session" do
      session = service.create_session(app_name: app_name, user_id: user_id)
      event = Google::ADK::Event.new(invocation_id: "inv-123", author: "user")

      updated = service.append_event(
        app_name: app_name,
        user_id: user_id,
        session_id: session.id,
        event: event
      )

      expect(updated.events).to include(event)
      expect(updated.events.length).to eq(1)
    end

    it "returns nil for non-existent session" do
      event = Google::ADK::Event.new(invocation_id: "inv-123", author: "user")
      
      updated = service.append_event(
        app_name: app_name,
        user_id: user_id,
        session_id: "non-existent",
        event: event
      )

      expect(updated).to be_nil
    end
  end

  describe "#delete_session" do
    it "removes existing session" do
      session = service.create_session(app_name: app_name, user_id: user_id)
      
      result = service.delete_session(
        app_name: app_name,
        user_id: user_id,
        session_id: session.id
      )

      expect(result).to be true
      
      retrieved = service.get_session(
        app_name: app_name,
        user_id: user_id,
        session_id: session.id
      )
      expect(retrieved).to be_nil
    end

    it "returns false for non-existent session" do
      result = service.delete_session(
        app_name: app_name,
        user_id: user_id,
        session_id: "non-existent"
      )

      expect(result).to be false
    end
  end

  describe "#list_sessions" do
    it "returns all sessions for a user" do
      session1 = service.create_session(app_name: app_name, user_id: user_id)
      session2 = service.create_session(app_name: app_name, user_id: user_id)

      sessions = service.list_sessions(app_name: app_name, user_id: user_id)

      expect(sessions.length).to eq(2)
      expect(sessions.map(&:id)).to contain_exactly(session1.id, session2.id)
    end

    it "returns empty array for user with no sessions" do
      sessions = service.list_sessions(app_name: app_name, user_id: "unknown-user")

      expect(sessions).to eq([])
    end

    it "isolates sessions by app_name" do
      session1 = service.create_session(app_name: "app1", user_id: user_id)
      session2 = service.create_session(app_name: "app2", user_id: user_id)

      sessions = service.list_sessions(app_name: "app1", user_id: user_id)

      expect(sessions.length).to eq(1)
      expect(sessions.first.id).to eq(session1.id)
    end
  end
end