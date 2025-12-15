# frozen_string_literal: true

require "spec_helper"

RSpec.describe Google::ADK::Runner do
  let(:agent) { Google::ADK::LlmAgent.new(name: "test_agent", model: "gemini-2.0-flash") }
  let(:app_name) { "test_app" }
  let(:user_id) { "user123" }
  let(:runner) { described_class.new(agent: agent, app_name: app_name) }

  describe "#initialize" do
    it "creates a runner with agent and app_name" do
      expect(runner.agent).to eq(agent)
      expect(runner.app_name).to eq(app_name)
    end

    it "initializes with InMemorySessionService by default" do
      expect(runner.session_service).to be_a(Google::ADK::InMemorySessionService)
    end

    it "accepts custom session service" do
      custom_service = double("SessionService")
      runner = described_class.new(
        agent: agent,
        app_name: app_name,
        session_service: custom_service
      )
      expect(runner.session_service).to eq(custom_service)
    end

    it "accepts plugins" do
      plugin = double("Plugin")
      runner = described_class.new(
        agent: agent,
        app_name: app_name,
        plugins: [plugin]
      )
      expect(runner.plugins).to eq([plugin])
    end
  end

  describe "#run" do
    it "creates a session and executes the agent" do
      message = "Hello, agent!"
      events = runner.run(
        user_id: user_id,
        message: message
      )

      expect(events).to be_an(Enumerator)
      
      # Collect all events
      all_events = events.to_a
      expect(all_events).not_to be_empty
      expect(all_events.first).to be_a(Google::ADK::Event)
    end

    it "accepts an existing session_id" do
      session = runner.session_service.create_session(
        app_name: app_name,
        user_id: user_id
      )

      events = runner.run(
        user_id: user_id,
        session_id: session.id,
        message: "Hello"
      )

      expect(events).to be_an(Enumerator)
    end

    it "creates new invocation_id for each run" do
      events1 = runner.run(user_id: user_id, message: "First").to_a
      events2 = runner.run(user_id: user_id, message: "Second").to_a

      expect(events1.first.invocation_id).not_to eq(events2.first.invocation_id)
    end
  end

  describe "#run_async" do
    it "delegates to run method" do
      message = "Hello async"
      
      # Since we're not actually using async in this simple implementation
      events = runner.run_async(
        user_id: user_id,
        message: message
      )

      expect(events).to be_an(Enumerator)
    end
  end

  describe "event processing" do
    it "yields user message event first" do
      message = "Test message"
      events = runner.run(
        user_id: user_id,
        message: message
      ).to_a

      user_event = events.find { |e| e.author == "user" }
      expect(user_event).not_to be_nil
      expect(user_event.content).to eq(message)
    end

    it "yields agent response events" do
      events = runner.run(
        user_id: user_id,
        message: "Hello"
      ).to_a

      agent_events = events.select { |e| e.author == agent.name }
      expect(agent_events).not_to be_empty
    end

    it "updates session with events" do
      session = runner.session_service.create_session(
        app_name: app_name,
        user_id: user_id
      )

      runner.run(
        user_id: user_id,
        session_id: session.id,
        message: "Hello"
      ).to_a

      updated_session = runner.session_service.get_session(
        app_name: app_name,
        user_id: user_id,
        session_id: session.id
      )

      expect(updated_session.events).not_to be_empty
    end
  end

  describe "plugin integration" do
    let(:plugin) { double("Plugin") }
    let(:runner_with_plugin) {
      described_class.new(
        agent: agent,
        app_name: app_name,
        plugins: [plugin]
      )
    }

    it "calls on_user_message on plugins" do
      allow(plugin).to receive(:on_user_message)
      allow(plugin).to receive(:on_event)
      allow(plugin).to receive(:on_agent_start)
      allow(plugin).to receive(:on_agent_end)

      runner_with_plugin.run(
        user_id: user_id,
        message: "Hello"
      ).to_a

      expect(plugin).to have_received(:on_user_message)
    end

    it "calls on_event on plugins for each event" do
      allow(plugin).to receive(:on_user_message)
      allow(plugin).to receive(:on_event).at_least(:once)
      allow(plugin).to receive(:on_agent_start)
      allow(plugin).to receive(:on_agent_end)

      runner_with_plugin.run(
        user_id: user_id,
        message: "Hello"
      ).to_a

      expect(plugin).to have_received(:on_event).at_least(:once)
    end
  end

  describe "error handling" do
    it "yields error event on agent failure" do
      failing_agent = Google::ADK::BaseAgent.new(
        name: "failing_agent",
        description: "Always fails"
      )
      
      runner = described_class.new(
        agent: failing_agent,
        app_name: app_name
      )

      events = runner.run(
        user_id: user_id,
        message: "This will fail"
      ).to_a

      # Should still yield some events even on failure
      expect(events).not_to be_empty
    end
  end
end

RSpec.describe Google::ADK::InMemoryRunner do
  let(:agent) { Google::ADK::LlmAgent.new(name: "test_agent", model: "gemini-2.0-flash") }
  let(:app_name) { "test_app" }
  let(:runner) { described_class.new(agent: agent, app_name: app_name) }

  describe "#initialize" do
    it "creates runner with InMemorySessionService" do
      expect(runner.session_service).to be_a(Google::ADK::InMemorySessionService)
    end
  end
end

RSpec.describe Google::ADK::Plugin do
  let(:plugin) { described_class.new }

  describe "interface methods" do
    it "provides default implementations" do
      context = double("Context")
      event = double("Event")

      expect { plugin.on_user_message(context, "message") }.not_to raise_error
      expect { plugin.on_event(context, event) }.not_to raise_error
      expect { plugin.on_agent_start(context) }.not_to raise_error
      expect { plugin.on_agent_end(context) }.not_to raise_error
    end
  end
end