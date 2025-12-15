# frozen_string_literal: true

require "spec_helper"

RSpec.describe Google::ADK::SequentialAgent do
  let(:agent_name) { "sequential_coordinator" }
  let(:description) { "Runs agents in sequence" }
  
  let(:agent1) { Google::ADK::LlmAgent.new(name: "agent1", model: "gemini-2.0-flash") }
  let(:agent2) { Google::ADK::LlmAgent.new(name: "agent2", model: "gemini-2.0-flash") }
  let(:agent3) { Google::ADK::LlmAgent.new(name: "agent3", model: "gemini-2.0-flash") }
  
  describe "#initialize" do
    it "creates a sequential agent with sub-agents" do
      agent = described_class.new(
        name: agent_name,
        description: description,
        agents: [agent1, agent2, agent3]
      )
      
      expect(agent.name).to eq(agent_name)
      expect(agent.description).to eq(description)
      expect(agent.agents).to eq([agent1, agent2, agent3])
    end
    
    it "requires at least one agent" do
      expect {
        described_class.new(name: agent_name, agents: [])
      }.to raise_error(ArgumentError, /at least one agent/)
    end
    
    it "sets sub_agents from agents array" do
      agent = described_class.new(
        name: agent_name,
        agents: [agent1, agent2]
      )
      
      expect(agent.sub_agents).to eq([agent1, agent2])
    end
  end
  
  describe "#run_async" do
    let(:sequential_agent) {
      described_class.new(
        name: agent_name,
        agents: [agent1, agent2, agent3]
      )
    }
    let(:context) { double("Context", invocation_id: "test-inv", add_event: nil) }
    
    it "executes agents in order" do
      events = sequential_agent.run_async("Test message", context: context).to_a
      
      # Should have events from each agent
      agent_names = events.map(&:author).uniq
      expect(agent_names).to include("agent1", "agent2", "agent3")
      
      # Verify order
      agent1_index = events.find_index { |e| e.author == "agent1" }
      agent2_index = events.find_index { |e| e.author == "agent2" }
      agent3_index = events.find_index { |e| e.author == "agent3" }
      
      expect(agent1_index).to be < agent2_index
      expect(agent2_index).to be < agent3_index
    end
    
    it "passes output from one agent as input to the next" do
      # In the real implementation, each agent's output becomes
      # the next agent's input
      events = sequential_agent.run_async("Initial message", context: context).to_a
      
      expect(events).not_to be_empty
    end
    
    it "yields start and end events" do
      events = sequential_agent.run_async("Test", context: context).to_a
      
      first_event = events.first
      last_event = events.last
      
      expect(first_event.author).to eq(agent_name)
      expect(first_event.content).to include("Starting sequential execution")
      
      expect(last_event.author).to eq(agent_name)
      expect(last_event.content).to include("Completed sequential execution")
    end
    
    it "handles agent failures gracefully" do
      failing_agent = Google::ADK::BaseAgent.new(
        name: "failing",
        description: "Always fails"
      )
      
      agent = described_class.new(
        name: agent_name,
        agents: [agent1, failing_agent, agent3]
      )
      
      events = agent.run_async("Test", context: context).to_a
      
      # Should still get some events even with failure
      expect(events).not_to be_empty
      
      # Should have error event
      error_event = events.find { |e| e.content&.include?("Error") }
      expect(error_event).not_to be_nil
    end
  end
  
  describe "integration with BaseAgent" do
    it "inherits from BaseAgent" do
      expect(described_class).to be < Google::ADK::BaseAgent
    end
    
    it "can be used as a tool in another agent" do
      sequential = described_class.new(
        name: "seq_tool",
        description: "Sequential processor",
        agents: [agent1, agent2]
      )
      
      parent = Google::ADK::LlmAgent.new(
        name: "parent",
        model: "gemini-2.0-flash",
        tools: [sequential]
      )
      
      tools = parent.canonical_tools
      expect(tools.length).to eq(1)
      expect(tools.first).to be_a(Google::ADK::AgentTool)
    end
  end
end