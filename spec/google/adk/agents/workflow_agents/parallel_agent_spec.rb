# frozen_string_literal: true

require "spec_helper"

RSpec.describe Google::ADK::ParallelAgent do
  let(:agent_name) { "parallel_coordinator" }
  let(:description) { "Runs agents in parallel" }
  
  let(:agent1) { Google::ADK::LlmAgent.new(name: "agent1", model: "gemini-2.0-flash") }
  let(:agent2) { Google::ADK::LlmAgent.new(name: "agent2", model: "gemini-2.0-flash") }
  let(:agent3) { Google::ADK::LlmAgent.new(name: "agent3", model: "gemini-2.0-flash") }
  
  describe "#initialize" do
    it "creates a parallel agent with sub-agents" do
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
    
    it "accepts aggregation_strategy" do
      agent = described_class.new(
        name: agent_name,
        agents: [agent1, agent2],
        aggregation_strategy: :first
      )
      
      expect(agent.aggregation_strategy).to eq(:first)
    end
    
    it "defaults to :all aggregation strategy" do
      agent = described_class.new(
        name: agent_name,
        agents: [agent1, agent2]
      )
      
      expect(agent.aggregation_strategy).to eq(:all)
    end
  end
  
  describe "#run_async" do
    let(:parallel_agent) {
      described_class.new(
        name: agent_name,
        agents: [agent1, agent2, agent3]
      )
    }
    let(:context) { double("Context", invocation_id: "test-inv", add_event: nil) }
    
    it "executes all agents with the same input" do
      events = parallel_agent.run_async("Test message", context: context).to_a
      
      # Should have events from each agent
      agent_names = events.map(&:author).uniq
      expect(agent_names).to include("agent1", "agent2", "agent3")
    end
    
    it "yields start and end events" do
      events = parallel_agent.run_async("Test", context: context).to_a
      
      first_event = events.first
      last_event = events.last
      
      expect(first_event.author).to eq(agent_name)
      expect(first_event.content).to include("Starting parallel execution")
      
      expect(last_event.author).to eq(agent_name)
      expect(last_event.content).to include("Completed parallel execution")
    end
    
    it "aggregates results with :all strategy" do
      agent = described_class.new(
        name: agent_name,
        agents: [agent1, agent2],
        aggregation_strategy: :all
      )
      
      events = agent.run_async("Test", context: context).to_a
      
      # Final event should mention all results
      final_event = events.last
      expect(final_event.content).to include("Results from 2 agents")
    end
    
    it "returns first result with :first strategy" do
      agent = described_class.new(
        name: agent_name,
        agents: [agent1, agent2],
        aggregation_strategy: :first
      )
      
      events = agent.run_async("Test", context: context).to_a
      
      # Should include mention of using first result
      final_event = events.last
      expect(final_event.content).to include("first agent")
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
      
      # Should still complete and return results from successful agents
      expect(events).not_to be_empty
      
      # Should mention the failure
      error_mention = events.any? { |e| e.content&.include?("failed") }
      expect(error_mention).to be true
    end
  end
  
  describe "integration with BaseAgent" do
    it "inherits from BaseAgent" do
      expect(described_class).to be < Google::ADK::BaseAgent
    end
  end
end