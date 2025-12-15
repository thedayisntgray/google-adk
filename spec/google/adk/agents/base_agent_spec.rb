# frozen_string_literal: true

require "spec_helper"

RSpec.describe Google::ADK::BaseAgent do
  let(:agent_name) { "test_agent" }
  let(:agent_description) { "A test agent" }
  let(:agent) { described_class.new(name: agent_name, description: agent_description) }

  describe "#initialize" do
    it "creates an agent with a name" do
      expect(agent.name).to eq(agent_name)
    end

    it "creates an agent with a description" do
      expect(agent.description).to eq(agent_description)
    end

    it "validates agent name format" do
      expect do
        described_class.new(name: "invalid name!", description: "test")
      end.to raise_error(Google::ADK::ConfigurationError, /Agent name must match/)
    end

    it "requires a name" do
      expect do
        described_class.new(description: "test")
      end.to raise_error(ArgumentError)
    end

    it "initializes with no parent agent" do
      expect(agent.parent_agent).to be_nil
    end

    it "initializes with empty sub_agents array" do
      expect(agent.sub_agents).to eq([])
    end
  end

  describe "#sub_agents" do
    let(:sub_agent1) { described_class.new(name: "sub_agent_1", description: "First sub-agent") }
    let(:sub_agent2) { described_class.new(name: "sub_agent_2", description: "Second sub-agent") }

    it "can add sub-agents" do
      agent = described_class.new(name: agent_name, description: agent_description, sub_agents: [sub_agent1])
      expect(agent.sub_agents).to eq([sub_agent1])
      expect(sub_agent1.parent_agent).to eq(agent)
    end

    it "validates unique sub-agent names" do
      expect do
        described_class.new(
          name: agent_name,
          description: agent_description,
          sub_agents: [sub_agent1, sub_agent1]
        )
      end.to raise_error(Google::ADK::ConfigurationError, /Sub-agent names must be unique/)
    end

    it "sets parent_agent on sub-agents" do
      agent = described_class.new(
        name: agent_name,
        description: agent_description,
        sub_agents: [sub_agent1, sub_agent2]
      )
      expect(sub_agent1.parent_agent).to eq(agent)
      expect(sub_agent2.parent_agent).to eq(agent)
    end
  end

  describe "#clone" do
    let(:sub_agent) { described_class.new(name: "sub_agent", description: "Sub-agent") }
    let(:agent_with_sub) do
      described_class.new(
        name: agent_name,
        description: agent_description,
        sub_agents: [sub_agent]
      )
    end

    it "creates a copy of the agent" do
      cloned = agent.clone
      expect(cloned.name).to eq(agent.name)
      expect(cloned.description).to eq(agent.description)
      expect(cloned).not_to eq(agent)
    end

    it "allows updating attributes during clone" do
      cloned = agent.clone(name: "new_name")
      expect(cloned.name).to eq("new_name")
      expect(cloned.description).to eq(agent.description)
    end

    it "deep clones sub-agents" do
      cloned = agent_with_sub.clone
      expect(cloned.sub_agents.length).to eq(1)
      expect(cloned.sub_agents.first).not_to eq(sub_agent)
      expect(cloned.sub_agents.first.name).to eq(sub_agent.name)
    end
  end

  describe "#find_agent" do
    let(:sub_agent1) { described_class.new(name: "sub_agent_1", description: "First") }
    let(:sub_agent2) { described_class.new(name: "sub_agent_2", description: "Second") }
    let(:nested_agent) { described_class.new(name: "nested", description: "Nested") }
    let(:agent_tree) do
      sub1_with_nested = sub_agent1.clone(sub_agents: [nested_agent])
      described_class.new(
        name: agent_name,
        description: agent_description,
        sub_agents: [sub1_with_nested, sub_agent2]
      )
    end

    it "finds self by name" do
      expect(agent_tree.find_agent(agent_name)).to eq(agent_tree)
    end

    it "finds direct sub-agent" do
      found = agent_tree.find_agent("sub_agent_1")
      expect(found.name).to eq("sub_agent_1")
    end

    it "finds nested sub-agent" do
      found = agent_tree.find_agent("nested")
      expect(found.name).to eq("nested")
    end

    it "returns nil for non-existent agent" do
      expect(agent_tree.find_agent("non_existent")).to be_nil
    end
  end

  describe "#find_sub_agent" do
    let(:sub_agent) { described_class.new(name: "sub_agent", description: "Sub") }
    let(:agent_with_sub) do
      described_class.new(
        name: agent_name,
        description: agent_description,
        sub_agents: [sub_agent]
      )
    end

    it "finds direct sub-agent by name" do
      expect(agent_with_sub.find_sub_agent("sub_agent")).to eq(sub_agent)
    end

    it "returns nil if sub-agent not found" do
      expect(agent_with_sub.find_sub_agent("non_existent")).to be_nil
    end

    it "only searches direct children" do
      nested = described_class.new(name: "nested", description: "Nested")
      sub_with_nested = sub_agent.clone(sub_agents: [nested])
      parent = described_class.new(
        name: "parent",
        description: "Parent",
        sub_agents: [sub_with_nested]
      )
      expect(parent.find_sub_agent("nested")).to be_nil
    end
  end

  describe "#run_async" do
    it "raises NotImplementedError for base class" do
      expect do
        agent.run_async("test message")
      end.to raise_error(NotImplementedError, /Subclasses must implement/)
    end
  end

  describe "#run_live" do
    it "raises NotImplementedError for base class" do
      expect do
        agent.run_live
      end.to raise_error(NotImplementedError, /Subclasses must implement/)
    end
  end

  describe "callbacks" do
    it "accepts before_agent_callback" do
      callback = proc { |agent, _message| puts "Before: #{agent.name}" }
      agent = described_class.new(
        name: agent_name,
        description: agent_description,
        before_agent_callback: callback
      )
      expect(agent.before_agent_callback).to eq(callback)
    end

    it "accepts after_agent_callback" do
      callback = proc { |agent, _result| puts "After: #{agent.name}" }
      agent = described_class.new(
        name: agent_name,
        description: agent_description,
        after_agent_callback: callback
      )
      expect(agent.after_agent_callback).to eq(callback)
    end

    it "initializes callbacks as nil by default" do
      expect(agent.before_agent_callback).to be_nil
      expect(agent.after_agent_callback).to be_nil
    end
  end

  describe ".from_config" do
    let(:config) do
      {
        name: "configured_agent",
        description: "Agent from config",
        sub_agents: [
          {
            name: "sub_from_config",
            description: "Sub-agent from config"
          }
        ]
      }
    end

    it "creates agent from configuration hash" do
      agent = described_class.from_config(config)
      expect(agent.name).to eq("configured_agent")
      expect(agent.description).to eq("Agent from config")
      expect(agent.sub_agents.length).to eq(1)
      expect(agent.sub_agents.first.name).to eq("sub_from_config")
    end

    it "handles deeply nested configurations" do
      config[:sub_agents].first[:sub_agents] = [
        { name: "deeply_nested", description: "Deep agent" }
      ]
      agent = described_class.from_config(config)
      nested = agent.find_agent("deeply_nested")
      expect(nested).not_to be_nil
      expect(nested.name).to eq("deeply_nested")
    end
  end
end
