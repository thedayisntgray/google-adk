# frozen_string_literal: true

require "spec_helper"

RSpec.describe Google::ADK::ReadonlyContext do
  let(:invocation_id) { "test-invocation-123" }
  let(:agent_name) { "test_agent" }
  let(:initial_state) { { "app:key" => "value", "user:name" => "Alice" } }

  describe "#initialize" do
    it "creates a readonly context with required attributes" do
      context = described_class.new(
        invocation_id: invocation_id,
        agent_name: agent_name,
        state: initial_state
      )
      
      expect(context.invocation_id).to eq(invocation_id)
      expect(context.agent_name).to eq(agent_name)
      expect(context.state).to eq(initial_state)
    end

    it "freezes the state to prevent modifications" do
      context = described_class.new(
        invocation_id: invocation_id,
        agent_name: agent_name,
        state: initial_state
      )
      
      expect { context.state["new_key"] = "value" }.to raise_error(FrozenError)
    end
  end
end

RSpec.describe Google::ADK::CallbackContext do
  let(:invocation_id) { "test-invocation-123" }
  let(:agent_name) { "test_agent" }
  let(:initial_state) { { "app:key" => "value" } }
  let(:session) { double("Session", state: initial_state.dup) }

  describe "#initialize" do
    it "creates a callback context with session" do
      context = described_class.new(
        invocation_id: invocation_id,
        agent_name: agent_name,
        session: session
      )
      
      expect(context.invocation_id).to eq(invocation_id)
      expect(context.agent_name).to eq(agent_name)
      expect(context.session).to eq(session)
    end
  end

  describe "#state" do
    it "returns mutable session state" do
      context = described_class.new(
        invocation_id: invocation_id,
        agent_name: agent_name,
        session: session
      )
      
      context.state["app:new_key"] = "new_value"
      expect(context.state["app:new_key"]).to eq("new_value")
    end
  end

  describe "#update_state" do
    it "updates multiple state values" do
      context = described_class.new(
        invocation_id: invocation_id,
        agent_name: agent_name,
        session: session
      )
      
      updates = { "app:key1" => "value1", "user:key2" => "value2" }
      context.update_state(updates)
      
      expect(context.state["app:key1"]).to eq("value1")
      expect(context.state["user:key2"]).to eq("value2")
    end
  end
end

RSpec.describe Google::ADK::ToolContext do
  let(:invocation_id) { "test-invocation-123" }
  let(:agent_name) { "test_agent" }
  let(:session) { double("Session", state: {}) }
  let(:auth_service) { double("AuthService") }

  describe "#initialize" do
    it "creates a tool context with auth support" do
      context = described_class.new(
        invocation_id: invocation_id,
        agent_name: agent_name,
        session: session,
        auth_service: auth_service
      )
      
      expect(context.auth_service).to eq(auth_service)
    end
  end

  describe "#request_auth" do
    it "delegates to auth service" do
      context = described_class.new(
        invocation_id: invocation_id,
        agent_name: agent_name,
        session: session,
        auth_service: auth_service
      )
      
      expect(auth_service).to receive(:request_auth).with("oauth", { scope: "read" })
      context.request_auth("oauth", scope: "read")
    end
  end
end

RSpec.describe Google::ADK::InvocationContext do
  let(:invocation_id) { "test-invocation-123" }
  let(:agent) { Google::ADK::BaseAgent.new(name: "test_agent", description: "Test") }
  let(:session) { double("Session", id: "session-123", events: [], state: {}) }
  let(:session_service) { double("SessionService") }

  describe "#initialize" do
    it "creates an invocation context" do
      context = described_class.new(
        session: session,
        agent: agent,
        invocation_id: invocation_id,
        session_service: session_service
      )
      
      expect(context.session).to eq(session)
      expect(context.agent).to eq(agent)
      expect(context.invocation_id).to eq(invocation_id)
      expect(context.session_service).to eq(session_service)
    end

    it "initializes agent states" do
      context = described_class.new(
        session: session,
        agent: agent,
        invocation_id: invocation_id,
        session_service: session_service
      )
      
      expect(context.agent_states).to eq({})
    end

    it "accepts run configuration" do
      run_config = Google::ADK::RunConfig.new(max_tokens: 1000)
      context = described_class.new(
        session: session,
        agent: agent,
        invocation_id: invocation_id,
        session_service: session_service,
        run_config: run_config
      )
      
      expect(context.run_config.max_tokens).to eq(1000)
    end
  end

  describe "#get_agent_state" do
    it "returns agent state for a given agent name" do
      context = described_class.new(
        session: session,
        agent: agent,
        invocation_id: invocation_id,
        session_service: session_service
      )
      
      context.agent_states["test_agent"] = { "key" => "value" }
      expect(context.get_agent_state("test_agent")).to eq({ "key" => "value" })
    end

    it "returns empty hash for unknown agent" do
      context = described_class.new(
        session: session,
        agent: agent,
        invocation_id: invocation_id,
        session_service: session_service
      )
      
      expect(context.get_agent_state("unknown")).to eq({})
    end
  end

  describe "#update_agent_state" do
    it "updates agent state" do
      context = described_class.new(
        session: session,
        agent: agent,
        invocation_id: invocation_id,
        session_service: session_service
      )
      
      context.update_agent_state("test_agent", { "key" => "new_value" })
      expect(context.agent_states["test_agent"]).to eq({ "key" => "new_value" })
    end
  end
end

RSpec.describe Google::ADK::ContextCacheConfig do
  describe "#initialize" do
    it "creates cache config with defaults" do
      config = described_class.new
      
      expect(config.min_tokens).to eq(1024)
      expect(config.ttl_seconds).to eq(300)
      expect(config.cache_intervals).to eq([])
    end

    it "accepts custom values" do
      config = described_class.new(
        min_tokens: 2048,
        ttl_seconds: 600,
        cache_intervals: [100, 200]
      )
      
      expect(config.min_tokens).to eq(2048)
      expect(config.ttl_seconds).to eq(600)
      expect(config.cache_intervals).to eq([100, 200])
    end
  end
end

RSpec.describe Google::ADK::RunConfig do
  describe "#initialize" do
    it "creates run config with defaults" do
      config = described_class.new
      
      expect(config.max_tokens).to be_nil
      expect(config.temperature).to eq(0.7)
      expect(config.context_window_compression).to be false
    end

    it "accepts custom configuration" do
      config = described_class.new(
        max_tokens: 4096,
        temperature: 0.9,
        context_window_compression: true
      )
      
      expect(config.max_tokens).to eq(4096)
      expect(config.temperature).to eq(0.9)
      expect(config.context_window_compression).to be true
    end
  end
end