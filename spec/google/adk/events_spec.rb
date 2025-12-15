# frozen_string_literal: true

require "spec_helper"

RSpec.describe Google::ADK::Event do
  let(:event_id) { "test-event-123" }
  let(:invocation_id) { "invocation-456" }
  let(:author) { "test_agent" }
  let(:timestamp) { Time.now }

  describe "#initialize" do
    it "creates an event with required attributes" do
      event = described_class.new(
        author: author,
        invocation_id: invocation_id
      )
      expect(event.author).to eq(author)
      expect(event.invocation_id).to eq(invocation_id)
    end

    it "generates an ID if not provided" do
      event = described_class.new(author: author, invocation_id: invocation_id)
      expect(event.id).not_to be_nil
      expect(event.id).to match(/^[a-f0-9-]+$/)
    end

    it "accepts a specific ID" do
      event = described_class.new(
        id: event_id,
        author: author,
        invocation_id: invocation_id
      )
      expect(event.id).to eq(event_id)
    end

    it "sets timestamp automatically" do
      event = described_class.new(author: author, invocation_id: invocation_id)
      expect(event.timestamp).to be_a(Time)
      expect(event.timestamp).to be <= Time.now
    end

    it "accepts content" do
      content = "Test message"
      event = described_class.new(
        author: author,
        invocation_id: invocation_id,
        content: content
      )
      expect(event.content).to eq(content)
    end

    it "initializes with empty function calls and responses" do
      event = described_class.new(author: author, invocation_id: invocation_id)
      expect(event.function_calls).to eq([])
      expect(event.function_responses).to eq([])
    end

    it "initializes with empty long_running_tool_ids" do
      event = described_class.new(author: author, invocation_id: invocation_id)
      expect(event.long_running_tool_ids).to eq(Set.new)
    end
  end

  describe "#is_final_response?" do
    it "returns true for user events" do
      event = described_class.new(author: "user", invocation_id: invocation_id)
      expect(event.is_final_response?).to be true
    end

    it "returns true when transfer_to_agent is nil" do
      event = described_class.new(
        author: author,
        invocation_id: invocation_id,
        actions: Google::ADK::EventActions.new
      )
      expect(event.is_final_response?).to be true
    end

    it "returns false when transfer_to_agent is set" do
      actions = Google::ADK::EventActions.new(transfer_to_agent: "other_agent")
      event = described_class.new(
        author: author,
        invocation_id: invocation_id,
        actions: actions
      )
      expect(event.is_final_response?).to be false
    end
  end

  describe ".new_id" do
    it "generates unique IDs" do
      id1 = described_class.new_id
      id2 = described_class.new_id
      expect(id1).not_to eq(id2)
      expect(id1).to match(/^[a-f0-9-]+$/)
    end
  end

  describe "#to_h" do
    it "serializes event to hash" do
      event = described_class.new(
        id: event_id,
        author: author,
        invocation_id: invocation_id,
        content: "Test content"
      )
      
      hash = event.to_h
      expect(hash[:id]).to eq(event_id)
      expect(hash[:author]).to eq(author)
      expect(hash[:invocation_id]).to eq(invocation_id)
      expect(hash[:content]).to eq("Test content")
      expect(hash[:timestamp]).to be_a(String)
    end
  end
end

RSpec.describe Google::ADK::EventActions do
  describe "#initialize" do
    it "creates empty actions" do
      actions = described_class.new
      expect(actions.state_delta).to eq({})
      expect(actions.agent_state).to be_nil
      expect(actions.transfer_to_agent).to be_nil
      expect(actions.escalate).to be false
    end

    it "accepts state_delta" do
      delta = { "key" => "value" }
      actions = described_class.new(state_delta: delta)
      expect(actions.state_delta).to eq(delta)
    end

    it "accepts transfer_to_agent" do
      actions = described_class.new(transfer_to_agent: "next_agent")
      expect(actions.transfer_to_agent).to eq("next_agent")
    end

    it "accepts escalate flag" do
      actions = described_class.new(escalate: true)
      expect(actions.escalate).to be true
    end

    it "accepts skip_summarization flag" do
      actions = described_class.new(skip_summarization: true)
      expect(actions.skip_summarization).to be true
    end

    it "initializes artifact_delta as empty hash" do
      actions = described_class.new
      expect(actions.artifact_delta).to eq({})
    end
  end

  describe "#to_h" do
    it "serializes non-nil attributes to hash" do
      actions = described_class.new(
        state_delta: { "key" => "value" },
        transfer_to_agent: "agent_name",
        escalate: true
      )
      
      hash = actions.to_h
      expect(hash[:state_delta]).to eq({ "key" => "value" })
      expect(hash[:transfer_to_agent]).to eq("agent_name")
      expect(hash[:escalate]).to be true
      expect(hash).not_to have_key(:agent_state)
    end

    it "excludes nil and empty values" do
      actions = described_class.new
      hash = actions.to_h
      expect(hash).to eq({})
    end
  end
end

RSpec.describe Google::ADK::FunctionCall do
  describe "#initialize" do
    it "creates a function call with name and arguments" do
      call = described_class.new(
        id: "call-123",
        name: "test_function",
        arguments: { "param" => "value" }
      )
      expect(call.id).to eq("call-123")
      expect(call.name).to eq("test_function")
      expect(call.arguments).to eq({ "param" => "value" })
    end

    it "generates ID if not provided" do
      call = described_class.new(
        name: "test_function",
        arguments: {}
      )
      expect(call.id).not_to be_nil
      expect(call.id).to start_with("call-")
    end
  end
end

RSpec.describe Google::ADK::FunctionResponse do
  describe "#initialize" do
    it "creates a function response" do
      response = described_class.new(
        id: "call-123",
        name: "test_function",
        response: { "result" => "success" }
      )
      expect(response.id).to eq("call-123")
      expect(response.name).to eq("test_function")
      expect(response.response).to eq({ "result" => "success" })
    end

    it "handles error responses" do
      response = described_class.new(
        id: "call-123",
        name: "test_function",
        response: { "error" => "Function failed" },
        is_error: true
      )
      expect(response.is_error).to be true
    end
  end
end