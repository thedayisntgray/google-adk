# frozen_string_literal: true

require "concurrent-ruby"

module Google
  module ADK
    # Agent that executes sub-agents in parallel
    class ParallelAgent < BaseAgent
      attr_reader :agents, :aggregation_strategy

      # Initialize a parallel agent
      #
      # @param name [String] Agent name
      # @param description [String] Agent description (optional)
      # @param agents [Array<BaseAgent>] Agents to execute in parallel
      # @param aggregation_strategy [Symbol] How to aggregate results (:all, :first, :majority)
      # @param before_agent_callback [Proc] Callback before agent execution
      # @param after_agent_callback [Proc] Callback after agent execution
      # @raise [ArgumentError] If no agents provided
      def initialize(name:, agents:, description: nil, aggregation_strategy: :all,
                     before_agent_callback: nil, after_agent_callback: nil)
        raise ArgumentError, "Parallel agent requires at least one agent" if agents.empty?

        super(
          name: name,
          description: description || "Executes #{agents.length} agents in parallel",
          sub_agents: agents,
          before_agent_callback: before_agent_callback,
          after_agent_callback: after_agent_callback
        )

        @agents = agents
        @aggregation_strategy = aggregation_strategy
      end

      # Run agents in parallel
      #
      # @param message [String] Message to send to all agents
      # @param context [InvocationContext] Invocation context
      # @yield [Event] Events during execution
      def run_async(message, context: nil)
        Enumerator.new do |yielder|
          invocation_id = context&.invocation_id || "par-#{SecureRandom.uuid}"

          # Yield start event
          start_event = Event.new(
            invocation_id: invocation_id,
            author: @name,
            content: "Starting parallel execution with #{@agents.length} agents"
          )
          yielder << start_event

          # Collect results from all agents
          agent_results = {}
          failed_agents = []

          # In a real async implementation, these would run concurrently
          # For this simplified version, we'll run them sequentially
          # but collect all results before aggregating
          @agents.each do |agent|
            begin
              agent_events = []
              
              if agent.respond_to?(:run_async)
                agent.run_async(message, context: context).each do |event|
                  yielder << event
                  agent_events << event
                end
              else
                # For agents that don't implement run_async
                error_event = Event.new(
                  invocation_id: invocation_id,
                  author: @name,
                  content: "Agent #{agent.name} does not implement run_async"
                )
                yielder << error_event
              end

              # Store the last content event as the result
              last_content = agent_events.reverse.find { |e| e.content }&.content
              agent_results[agent.name] = last_content if last_content

            rescue StandardError => e
              # Track failed agents
              failed_agents << agent.name
              error_event = Event.new(
                invocation_id: invocation_id,
                author: @name,
                content: "Agent #{agent.name} failed: #{e.message}"
              )
              yielder << error_event
            end
          end

          # Aggregate results based on strategy
          final_result = aggregate_results(agent_results, failed_agents)

          # Yield completion event
          end_event = Event.new(
            invocation_id: invocation_id,
            author: @name,
            content: final_result
          )
          yielder << end_event
        end
      end

      private

      # Aggregate results from parallel execution
      #
      # @param results [Hash] Agent name => result mapping
      # @param failed [Array] Names of failed agents
      # @return [String] Aggregated result
      def aggregate_results(results, failed)
        case @aggregation_strategy
        when :first
          if results.any?
            agent_name = results.keys.first
            "Completed parallel execution using first agent result (#{agent_name}): #{results.values.first}"
          else
            "Completed parallel execution but no agents returned results"
          end
        when :all
          if results.any?
            result_summary = results.map { |name, result| "#{name}: #{result}" }.join("; ")
            failed_summary = failed.any? ? " (#{failed.length} agents failed)" : ""
            "Completed parallel execution. Results from #{results.length} agents: #{result_summary}#{failed_summary}"
          else
            "Completed parallel execution but no agents returned results"
          end
        else
          "Completed parallel execution with #{results.length} results"
        end
      end
    end
  end
end