# frozen_string_literal: true

require "spec_helper"

RSpec.describe Google::ADK::LoopAgent do
  let(:agent_name) { "loop_coordinator" }
  let(:description) { "Runs agent in a loop" }
  let(:loop_agent) { Google::ADK::LlmAgent.new(name: "worker", model: "gemini-2.0-flash") }
  
  describe "#initialize" do
    it "creates a loop agent with an agent and condition" do
      condition = proc { |_result, iteration| iteration < 3 }
      
      agent = described_class.new(
        name: agent_name,
        description: description,
        agent: loop_agent,
        loop_condition: condition
      )
      
      expect(agent.name).to eq(agent_name)
      expect(agent.description).to eq(description)
      expect(agent.agent).to eq(loop_agent)
      expect(agent.loop_condition).to eq(condition)
    end
    
    it "accepts max_iterations" do
      agent = described_class.new(
        name: agent_name,
        agent: loop_agent,
        max_iterations: 5
      )
      
      expect(agent.max_iterations).to eq(5)
    end
    
    it "defaults to 10 max iterations" do
      agent = described_class.new(
        name: agent_name,
        agent: loop_agent
      )
      
      expect(agent.max_iterations).to eq(10)
    end
    
    it "sets sub_agents with the loop agent" do
      agent = described_class.new(
        name: agent_name,
        agent: loop_agent
      )
      
      expect(agent.sub_agents).to eq([loop_agent])
    end
  end
  
  describe "#run_async" do
    let(:context) { double("Context", invocation_id: "test-inv", add_event: nil) }
    
    context "with iteration limit" do
      it "loops up to max_iterations" do
        agent = described_class.new(
          name: agent_name,
          agent: loop_agent,
          max_iterations: 3
        )
        
        events = agent.run_async("Test message", context: context).to_a
        
        # Count iteration events
        iteration_events = events.select { |e| e.content&.include?("Iteration") }
        expect(iteration_events.length).to eq(3)
      end
    end
    
    context "with custom loop condition" do
      it "loops while condition is true" do
        iteration_count = 0
        condition = proc do |_result, iteration|
          iteration_count = iteration
          iteration < 2
        end
        
        agent = described_class.new(
          name: agent_name,
          agent: loop_agent,
          loop_condition: condition
        )
        
        events = agent.run_async("Test", context: context).to_a
        
        # Should have run exactly 2 iterations (0 and 1)
        expect(iteration_count).to eq(2)
      end
      
      it "respects max_iterations even with condition" do
        always_true = proc { |_result, _iteration| true }
        
        agent = described_class.new(
          name: agent_name,
          agent: loop_agent,
          loop_condition: always_true,
          max_iterations: 2
        )
        
        events = agent.run_async("Test", context: context).to_a
        
        # Should stop at max_iterations
        iteration_events = events.select { |e| e.content&.include?("Iteration") }
        expect(iteration_events.length).to eq(2)
      end
    end
    
    context "with result transformation" do
      it "passes previous result as input to next iteration" do
        results = []
        
        # Create a test agent that captures inputs
        test_agent = Class.new(Google::ADK::BaseAgent) do
          define_method :run_async do |message, context: nil|
            results << message
            Enumerator.new do |y|
              y << Google::ADK::Event.new(
                invocation_id: context&.invocation_id || "test",
                author: name,
                content: "Result: #{message}"
              )
            end
          end
        end.new(name: "test", description: "Test agent")
        
        agent = described_class.new(
          name: agent_name,
          agent: test_agent,
          max_iterations: 3
        )
        
        agent.run_async("Initial", context: context).to_a
        
        # First iteration gets initial message
        expect(results[0]).to eq("Initial")
        # Subsequent iterations get previous results
        expect(results[1]).to include("Result:")
        expect(results[2]).to include("Result:")
      end
    end
    
    it "yields start and end events" do
      agent = described_class.new(
        name: agent_name,
        agent: loop_agent,
        max_iterations: 2
      )
      
      events = agent.run_async("Test", context: context).to_a
      
      first_event = events.first
      last_event = events.last
      
      expect(first_event.author).to eq(agent_name)
      expect(first_event.content).to include("Starting loop execution")
      
      expect(last_event.author).to eq(agent_name)
      expect(last_event.content).to include("Completed loop execution")
    end
    
    it "handles agent failures gracefully" do
      failing_agent = Google::ADK::BaseAgent.new(
        name: "failing",
        description: "Always fails"
      )
      
      agent = described_class.new(
        name: agent_name,
        agent: failing_agent,
        max_iterations: 2
      )
      
      events = agent.run_async("Test", context: context).to_a
      
      # Should have error events but complete
      expect(events).not_to be_empty
      error_events = events.select { |e| e.content&.include?("Error") }
      expect(error_events).not_to be_empty
    end
  end
  
  describe "integration with BaseAgent" do
    it "inherits from BaseAgent" do
      expect(described_class).to be < Google::ADK::BaseAgent
    end
  end
end