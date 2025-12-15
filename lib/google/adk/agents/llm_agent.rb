# frozen_string_literal: true

require "securerandom"
require_relative "../tools/base_tool"
require_relative "../tools/function_tool"
require_relative "../tools/agent_tool"
require_relative "../clients/gemini_client"

module Google
  module ADK
    # LLM-powered agent that can use tools and interact with language models
    class LlmAgent < BaseAgent
      attr_reader :model, :instructions, :tools, :include_from_children,
                  :inherit_parent_model, :before_model_callback, :after_model_callback,
                  :before_tool_callback, :after_tool_callback, :code_executor, :planner

      # Initialize an LLM agent
      #
      # @param name [String] Agent name
      # @param model [String, nil] Model name (e.g., "gemini-2.0-flash")
      # @param instructions [String] System instructions (can include {variables})
      # @param description [String] Agent description
      # @param tools [Array] Tools available to the agent
      # @param sub_agents [Array<BaseAgent>] Child agents
      # @param include_from_children [Array<String>] What to include from children
      # @param inherit_parent_model [Boolean] Whether to inherit parent's model
      # @param before_model_callback [Proc] Called before model invocation
      # @param after_model_callback [Proc] Called after model invocation
      # @param before_tool_callback [Proc] Called before tool execution
      # @param after_tool_callback [Proc] Called after tool execution
      # @param code_executor [Object] Optional code executor
      # @param planner [Object] Optional planner
      # @raise [ArgumentError] If model is required but not provided
      def initialize(name:, model: nil, instructions: nil, description: nil,
                     tools: [], sub_agents: [], include_from_children: [],
                     inherit_parent_model: false,
                     before_model_callback: nil, after_model_callback: nil,
                     before_tool_callback: nil, after_tool_callback: nil,
                     before_agent_callback: nil, after_agent_callback: nil,
                     code_executor: nil, planner: nil)
        super(
          name: name,
          description: description,
          sub_agents: sub_agents,
          before_agent_callback: before_agent_callback,
          after_agent_callback: after_agent_callback
        )

        raise ArgumentError, "model is required" if model.nil? && !inherit_parent_model

        @model = model
        @instructions = instructions
        @tools = tools
        @include_from_children = include_from_children
        @inherit_parent_model = inherit_parent_model
        @before_model_callback = before_model_callback
        @after_model_callback = after_model_callback
        @before_tool_callback = before_tool_callback
        @after_tool_callback = after_tool_callback
        @code_executor = code_executor
        @planner = planner
      end

      # Get the canonical model to use
      #
      # @return [String] Model name
      # @raise [ConfigurationError] If no model is available
      def canonical_model
        return @model if @model

        if @inherit_parent_model && @parent_agent&.respond_to?(:canonical_model)
          return @parent_agent.canonical_model
        end

        raise ConfigurationError, "No model specified for agent #{@name}"
      end

      # Get canonical instructions with variables interpolated
      #
      # @param context [Context] Current context
      # @return [String] Processed instructions
      def canonical_instructions(context)
        return "" unless @instructions

        # Simple variable interpolation from state
        processed = @instructions.dup
        context.state.each do |key, value|
          processed.gsub!("{#{key}}", value.to_s)
        end
        processed
      end

      # Get canonical tools (converted to proper tool objects)
      #
      # @return [Array<BaseTool>] Tool objects
      def canonical_tools
        @tools.map do |tool|
          case tool
          when BaseTool
            tool
          when BaseAgent
            AgentTool.new(agent: tool)
          else
            # Assume it's a callable (proc/method)
            FunctionTool.new(
              name: tool_name_from_callable(tool),
              description: "Function tool",
              callable: tool
            )
          end
        end
      end

      # Implementation of async run
      #
      # @param message [String] User message
      # @param context [InvocationContext] Invocation context
      # @yield [Event] Events during execution
      def run_async(message, context: nil)
        Enumerator.new do |yielder|
          begin
            # Initialize Gemini client
            client = GeminiClient.new
            
            # Build simple message for now
            messages = [{ role: "user", content: message }]
            
            # Get tools and convert to Gemini format
            tools = canonical_tools.map(&:to_gemini_schema)
            
            # Create more forceful system instruction for tools
            system_instruction = build_tool_aware_instructions(context, tools)
            
            # Call Gemini API with tools
            response = client.generate_content(
              model: canonical_model,
              messages: messages,
              tools: tools.empty? ? nil : tools,
              system_instruction: system_instruction
            )
            
            # Process response
            if response.dig("candidates", 0, "content", "parts")
              parts = response["candidates"][0]["content"]["parts"]
              
              parts.each do |part|
                if part["text"]
                  # Regular text response
                  event = Event.new(
                    invocation_id: context&.invocation_id || "inv-#{SecureRandom.uuid}",
                    author: @name,
                    content: part["text"]
                  )
                  yielder << event
                  context&.add_event(event) if context
                  
                elsif part["functionCall"]
                  # Tool call - execute and get result
                  function_call = part["functionCall"]
                  tool_name = function_call["name"]
                  tool_args = function_call["args"] || {}
                  
                  # Execute the tool
                  tool_result = execute_tool_call(tool_name, tool_args, yielder, context)
                  
                  # Call LLM again with tool result
                  tool_messages = messages + [
                    {
                      role: "model",
                      parts: [{ functionCall: function_call }]
                    },
                    {
                      role: "function", 
                      parts: [{
                        functionResponse: {
                          name: tool_name,
                          response: tool_result
                        }
                      }]
                    }
                  ]
                  
                  follow_up_response = client.generate_content(
                    model: canonical_model,
                    messages: tool_messages,
                    system_instruction: system_instruction
                  )
                  
                  if follow_up_response.dig("candidates", 0, "content", "parts", 0, "text")
                    final_text = follow_up_response["candidates"][0]["content"]["parts"][0]["text"]
                    event = Event.new(
                      invocation_id: context&.invocation_id || "inv-#{SecureRandom.uuid}",
                      author: @name,
                      content: final_text
                    )
                    yielder << event
                    context&.add_event(event) if context
                  end
                end
              end
            else
              # Fallback response
              event = Event.new(
                invocation_id: context&.invocation_id || "inv-#{SecureRandom.uuid}",
                author: @name,
                content: "I'm sorry, I couldn't process that request."
              )
              yielder << event
              context&.add_event(event) if context
            end
            
          rescue => e
            # Error handling
            puts "[DEBUG] Gemini error: #{e.message}" if ENV["DEBUG"]
            puts "[DEBUG] Backtrace: #{e.backtrace.first(3).join(', ')}" if ENV["DEBUG"]
            
            event = Event.new(
              invocation_id: context&.invocation_id || "inv-#{SecureRandom.uuid}",
              author: @name,
              content: "Error calling Gemini API: #{e.message}. Please check your GEMINI_API_KEY."
            )
            yielder << event
            context&.add_event(event) if context
          end
        end
      end

      private
      
      # Build tool-aware system instructions
      def build_tool_aware_instructions(context, tools)
        base_instructions = canonical_instructions(context) || ""
        
        if tools.empty?
          return base_instructions
        end
        
        tool_instructions = <<~TOOL_INSTRUCTIONS
          
          IMPORTANT: You have access to the following tools. You MUST use these tools when the user asks for information that requires them:
          
        TOOL_INSTRUCTIONS
        
        tools.each do |tool|
          tool_instructions += "- #{tool['name']}: #{tool['description']}\n"
        end
        
        tool_instructions += <<~GUIDELINES
          
          GUIDELINES FOR TOOL USAGE:
          1. When a user asks for currency conversion, exchange rates, or related information, you MUST use the appropriate currency tools
          2. When a user asks for weather information, you MUST use the appropriate weather tools  
          3. Always call the most relevant tool first, then provide a helpful response based on the results
          4. If a tool returns an error, explain what happened and suggest alternatives
          5. Format tool results in a user-friendly way
        GUIDELINES
        
        base_instructions + tool_instructions
      end

      # Build conversation history from context
      def build_conversation_history(context)
        return [] unless context&.session
        
        # Convert session events to message format
        messages = []
        context.session.events.each do |event|
          if event.author == "user"
            messages << { role: "user", content: event.content }
          elsif event.author == @name
            messages << { role: "assistant", content: event.content }
          end
        end
        messages
      end
      
      # Execute a tool call
      def execute_tool_call(tool_name, tool_args, yielder, context)
        puts "[DEBUG] Executing tool: #{tool_name} with args: #{tool_args}" if ENV["DEBUG"]
        
        # Find the tool
        tool = canonical_tools.find { |t| t.name == tool_name }
        unless tool
          return { error: "Tool not found: #{tool_name}" }
        end
        
        begin
          # Convert string keys to symbols and fix parameter name issues
          symbol_args = {}
          tool_args.each do |k, v|
            # Handle Gemini's parameter name quirks
            clean_key = k.to_s.gsub(/\d+_$/, '') # Remove trailing numbers and underscores
            symbol_args[clean_key.to_sym] = v
          end
          
          # Execute the tool
          result = tool.call(symbol_args)
          puts "[DEBUG] Tool result: #{result}" if ENV["DEBUG"]
          result
        rescue => e
          puts "[DEBUG] Tool error: #{e.message}" if ENV["DEBUG"]
          { error: "Tool error: #{e.message}" }
        end
      end

      # Extract a reasonable name from a callable
      #
      # @param callable [Proc, Method] Callable object
      # @return [String] Tool name
      def tool_name_from_callable(callable)
        case callable
        when Proc
          "function_#{callable.object_id}"
        when Method
          callable.name.to_s
        else
          "tool_#{callable.object_id}"
        end
      end
    end
  end
end