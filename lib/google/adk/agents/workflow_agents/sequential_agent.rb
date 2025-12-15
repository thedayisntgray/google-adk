# frozen_string_literal: true

module Google
  module ADK
    # Agent that executes sub-agents sequentially
    class SequentialAgent < BaseAgent
      attr_reader :agents

      # Initialize a sequential agent
      #
      # @param name [String] Agent name
      # @param description [String] Agent description (optional)
      # @param agents [Array<BaseAgent>] Agents to execute in order
      # @param before_agent_callback [Proc] Callback before agent execution
      # @param after_agent_callback [Proc] Callback after agent execution
      # @raise [ArgumentError] If no agents provided
      def initialize(name:, agents:, description: nil,
                     before_agent_callback: nil, after_agent_callback: nil)
        raise ArgumentError, "Sequential agent requires at least one agent" if agents.empty?

        super(
          name: name,
          description: description || "Executes #{agents.length} agents sequentially",
          sub_agents: agents,
          before_agent_callback: before_agent_callback,
          after_agent_callback: after_agent_callback
        )

        @agents = agents
      end

      # Run agents sequentially
      #
      # @param message [String] Initial message
      # @param context [InvocationContext] Invocation context
      # @yield [Event] Events during execution
      def run_async(message, context: nil)
        Enumerator.new do |yielder|
          invocation_id = context&.invocation_id || "seq-#{SecureRandom.uuid}"

          # Yield start event
          start_event = Event.new(
            invocation_id: invocation_id,
            author: @name,
            content: "Starting sequential execution with #{@agents.length} agents"
          )
          yielder << start_event

          # Execute each agent in sequence
          current_input = message
          @agents.each_with_index do |agent, index|
            begin
              # Yield progress event
              progress_event = Event.new(
                invocation_id: invocation_id,
                author: @name,
                content: "Executing agent #{index + 1}/#{@agents.length}: #{agent.name}"
              )
              yielder << progress_event

              # Run the agent
              agent_output = nil
              if agent.respond_to?(:run_async)
                agent.run_async(current_input, context: context).each do |event|
                  yielder << event
                  # Capture last content as output for next agent
                  agent_output = event.content if event.content
                end
              else
                # For agents that don't implement run_async
                error_event = Event.new(
                  invocation_id: invocation_id,
                  author: @name,
                  content: "Agent #{agent.name} does not implement run_async"
                )
                yielder << error_event
                agent_output = current_input
              end

              # Use this agent's output as next agent's input
              current_input = agent_output || current_input

            rescue StandardError => e
              # Handle errors gracefully
              error_event = Event.new(
                invocation_id: invocation_id,
                author: @name,
                content: "Error in agent #{agent.name}: #{e.message}"
              )
              yielder << error_event
              
              # Continue with original input if agent failed
              current_input = message
            end
          end

          # Yield completion event
          end_event = Event.new(
            invocation_id: invocation_id,
            author: @name,
            content: "Completed sequential execution. Final output: #{current_input}"
          )
          yielder << end_event
        end
      end
    end
  end
end