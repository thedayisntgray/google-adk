# frozen_string_literal: true

module Google
  module ADK
    class BaseAgent
      AGENT_NAME_REGEX = /^[a-zA-Z][a-zA-Z0-9_-]*$/

      attr_reader :name, :description, :parent_agent, :sub_agents,
                  :before_agent_callback, :after_agent_callback

      # Initialize a new BaseAgent
      #
      # @param name [String] Unique name for the agent
      # @param description [String] Description of the agent's capabilities (optional)
      # @param sub_agents [Array<BaseAgent>] Child agents (optional)
      # @param before_agent_callback [Proc] Callback before agent execution (optional)
      # @param after_agent_callback [Proc] Callback after agent execution (optional)
      # @raise [ArgumentError] If name is not provided
      # @raise [ConfigurationError] If name format is invalid or sub-agent names are not unique
      def initialize(name:, description: nil, sub_agents: [], before_agent_callback: nil, after_agent_callback: nil)
        raise ArgumentError, "name is required" if name.nil?

        validate_agent_name!(name)

        @name = name
        @description = description
        @parent_agent = nil
        @sub_agents = []
        @before_agent_callback = before_agent_callback
        @after_agent_callback = after_agent_callback

        # Set up sub-agents with validation
        self.sub_agents = sub_agents
      end

      # Run the agent asynchronously with a text message
      #
      # @param message [String] The input message
      # @raise [NotImplementedError] Must be implemented by subclasses
      def run_async(message)
        raise NotImplementedError, "Subclasses must implement #run_async"
      end

      # Run the agent in live mode (video/audio)
      #
      # @raise [NotImplementedError] Must be implemented by subclasses
      def run_live
        raise NotImplementedError, "Subclasses must implement #run_live"
      end

      # Create a copy of the agent with optional updates
      #
      # @param attributes [Hash] Attributes to update in the clone
      # @return [BaseAgent] A new agent instance
      def clone(**attributes)
        # Deep clone sub_agents if present
        cloned_sub_agents = if attributes.key?(:sub_agents)
                              attributes[:sub_agents]
                            else
                              @sub_agents.map(&:clone)
                            end

        self.class.new(
          name: attributes.fetch(:name, @name),
          description: attributes.fetch(:description, @description),
          sub_agents: cloned_sub_agents,
          before_agent_callback: attributes.fetch(:before_agent_callback, @before_agent_callback),
          after_agent_callback: attributes.fetch(:after_agent_callback, @after_agent_callback)
        )
      end

      # Find an agent by name in the agent tree
      #
      # @param agent_name [String] Name of the agent to find
      # @return [BaseAgent, nil] The found agent or nil
      def find_agent(agent_name)
        return self if @name == agent_name

        @sub_agents.each do |sub_agent|
          found = sub_agent.find_agent(agent_name)
          return found if found
        end

        nil
      end

      # Find a direct sub-agent by name
      #
      # @param agent_name [String] Name of the sub-agent to find
      # @return [BaseAgent, nil] The found sub-agent or nil
      def find_sub_agent(agent_name)
        @sub_agents.find { |agent| agent.name == agent_name }
      end

      # Create an agent from configuration
      #
      # @param config [Hash] Configuration hash
      # @return [BaseAgent] New agent instance
      def self.from_config(config)
        config = config.transform_keys(&:to_sym)

        # Recursively create sub-agents if present
        sub_agents = if config[:sub_agents]
                       config[:sub_agents].map { |sub_config| from_config(sub_config) }
                     else
                       []
                     end

        new(
          name: config[:name],
          description: config[:description],
          sub_agents: sub_agents,
          before_agent_callback: config[:before_agent_callback],
          after_agent_callback: config[:after_agent_callback]
        )
      end

      private

      # Validate agent name format
      #
      # @param name [String] Agent name to validate
      # @raise [ConfigurationError] If name format is invalid
      def validate_agent_name!(name)
        return if name.match?(AGENT_NAME_REGEX)

        raise ConfigurationError,
              "Agent name must match #{AGENT_NAME_REGEX.inspect}. Got: #{name.inspect}"
      end

      # Set sub-agents with validation
      #
      # @param agents [Array<BaseAgent>] Sub-agents to set
      # @raise [ConfigurationError] If sub-agent names are not unique
      def sub_agents=(agents)
        # Validate unique names
        agent_names = agents.map(&:name)
        raise ConfigurationError, "Sub-agent names must be unique" if agent_names.size != agent_names.uniq.size

        # Clear existing parent references
        @sub_agents.each { |agent| agent.instance_variable_set(:@parent_agent, nil) }

        # Set new sub-agents and parent references
        @sub_agents = agents
        @sub_agents.each { |agent| agent.instance_variable_set(:@parent_agent, self) }
      end
    end
  end
end
