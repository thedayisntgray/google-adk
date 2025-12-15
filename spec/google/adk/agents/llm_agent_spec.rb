# frozen_string_literal: true

require "spec_helper"

RSpec.describe Google::ADK::LlmAgent do
  let(:agent_name) { "test_llm_agent" }
  let(:model) { "gemini-2.0-flash" }
  let(:instructions) { "You are a helpful assistant" }

  describe "#initialize" do
    it "creates an LLM agent with model and instructions" do
      agent = described_class.new(
        name: agent_name,
        model: model,
        instructions: instructions
      )

      expect(agent.name).to eq(agent_name)
      expect(agent.model).to eq(model)
      expect(agent.instructions).to eq(instructions)
    end

    it "requires a model" do
      expect {
        described_class.new(name: agent_name)
      }.to raise_error(ArgumentError, /model is required/)
    end

    it "accepts tools array" do
      tool = double("Tool")
      agent = described_class.new(
        name: agent_name,
        model: model,
        tools: [tool]
      )

      expect(agent.tools).to eq([tool])
    end

    it "accepts callbacks" do
      before_model = proc { |context, request| puts "Before model" }
      after_model = proc { |context, response| puts "After model" }

      agent = described_class.new(
        name: agent_name,
        model: model,
        before_model_callback: before_model,
        after_model_callback: after_model
      )

      expect(agent.before_model_callback).to eq(before_model)
      expect(agent.after_model_callback).to eq(after_model)
    end

    it "initializes with empty tools if not provided" do
      agent = described_class.new(name: agent_name, model: model)
      expect(agent.tools).to eq([])
    end

    it "accepts include_from_children parameter" do
      agent = described_class.new(
        name: agent_name,
        model: model,
        include_from_children: ["content", "tool_calls"]
      )

      expect(agent.include_from_children).to eq(["content", "tool_calls"])
    end
  end

  describe "#canonical_model" do
    it "returns the agent's model if set" do
      agent = described_class.new(name: agent_name, model: model)
      expect(agent.canonical_model).to eq(model)
    end

    it "inherits model from parent if not set" do
      parent = described_class.new(name: "parent", model: "parent-model")
      child = described_class.new(
        name: "child",
        model: nil,
        inherit_parent_model: true
      )
      child.instance_variable_set(:@parent_agent, parent)

      expect(child.canonical_model).to eq("parent-model")
    end

    it "raises error if no model available" do
      agent = described_class.new(
        name: agent_name,
        model: nil,
        inherit_parent_model: true
      )
      expect {
        agent.canonical_model
      }.to raise_error(Google::ADK::ConfigurationError, /No model specified/)
    end
  end

  describe "#canonical_instructions" do
    it "returns static instructions" do
      agent = described_class.new(
        name: agent_name,
        model: model,
        instructions: instructions
      )

      context = double("Context", state: {})
      expect(agent.canonical_instructions(context)).to eq(instructions)
    end

    it "interpolates dynamic instructions from state" do
      agent = described_class.new(
        name: agent_name,
        model: model,
        instructions: "Hello {user_name}, you are in {location}"
      )

      context = double("Context", state: { "user_name" => "Alice", "location" => "Seattle" })
      expect(agent.canonical_instructions(context)).to eq("Hello Alice, you are in Seattle")
    end

    it "handles missing state values gracefully" do
      agent = described_class.new(
        name: agent_name,
        model: model,
        instructions: "Hello {user_name}"
      )

      context = double("Context", state: {})
      expect(agent.canonical_instructions(context)).to eq("Hello {user_name}")
    end
  end

  describe "#canonical_tools" do
    it "returns tools as-is if they're already tools" do
      tool = Google::ADK::FunctionTool.new(
        name: "test_tool",
        callable: proc { "test" }
      )

      agent = described_class.new(
        name: agent_name,
        model: model,
        tools: [tool]
      )

      expect(agent.canonical_tools).to eq([tool])
    end

    it "wraps callable objects as FunctionTools" do
      callable = proc { |x| x * 2 }
      agent = described_class.new(
        name: agent_name,
        model: model,
        tools: [callable]
      )

      tools = agent.canonical_tools
      expect(tools.length).to eq(1)
      expect(tools.first).to be_a(Google::ADK::FunctionTool)
    end

    it "wraps sub-agents as AgentTools" do
      sub_agent = described_class.new(name: "sub", model: model)
      agent = described_class.new(
        name: agent_name,
        model: model,
        tools: [sub_agent]
      )

      tools = agent.canonical_tools
      expect(tools.length).to eq(1)
      expect(tools.first).to be_a(Google::ADK::AgentTool)
    end
  end

  describe "#run_async" do
    it "implements the abstract method" do
      agent = described_class.new(name: agent_name, model: model)
      context = double("Context")

      expect {
        agent.run_async("test", context: context)
      }.not_to raise_error(NotImplementedError)
    end
  end

  describe "integration with BaseAgent" do
    it "inherits from BaseAgent" do
      expect(described_class).to be < Google::ADK::BaseAgent
    end

    it "supports sub-agents" do
      sub_agent = Google::ADK::BaseAgent.new(name: "sub", description: "Sub agent")
      agent = described_class.new(
        name: agent_name,
        model: model,
        sub_agents: [sub_agent]
      )

      expect(agent.sub_agents).to eq([sub_agent])
      expect(sub_agent.parent_agent).to eq(agent)
    end
  end
end

# Specs for supporting classes
RSpec.describe Google::ADK::BaseTool do
  describe "interface" do
    let(:tool) { described_class.new }

    it "raises NotImplementedError for call" do
      expect { tool.call({}) }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for schema" do
      expect { tool.schema }.to raise_error(NotImplementedError)
    end
  end
end

RSpec.describe Google::ADK::FunctionTool do
  describe "#initialize" do
    it "wraps a callable" do
      func = proc { |x| x * 2 }
      tool = described_class.new(
        name: "double",
        description: "Doubles a number",
        callable: func
      )

      expect(tool.name).to eq("double")
      expect(tool.description).to eq("Doubles a number")
      expect(tool.callable).to eq(func)
    end
  end

  describe "#call" do
    it "invokes the wrapped function" do
      func = proc { |x:| x * 2 }
      tool = described_class.new(name: "double", callable: func)

      result = tool.call(x: 5)
      expect(result).to eq(10)
    end
  end
end

RSpec.describe Google::ADK::AgentTool do
  let(:sub_agent) { Google::ADK::BaseAgent.new(name: "sub", description: "Helper agent") }

  describe "#initialize" do
    it "wraps an agent as a tool" do
      tool = described_class.new(agent: sub_agent)

      expect(tool.agent).to eq(sub_agent)
      expect(tool.name).to eq("sub")
      expect(tool.description).to eq("Helper agent")
    end
  end
end