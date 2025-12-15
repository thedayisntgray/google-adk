# frozen_string_literal: true

require_relative "../clients/gemini_client"
require "securerandom"

module Google
  module ADK
    # Simplified LLM agent with actual Gemini integration
    class SimpleLlmAgent
      attr_reader :model, :name, :instructions, :tools

      def initialize(model:, name:, instructions: nil, tools: [])
        @model = model
        @name = name
        @instructions = instructions
        @tools = tools
        @client = GeminiClient.new
      end

      # Simple synchronous call to Gemini
      def call(message)
        begin
          # Simple call without tools for now
          response = @client.generate_content(
            model: @model,
            messages: [{ role: "user", content: message }],
            system_instruction: @instructions
          )
          
          if response.dig("candidates", 0, "content", "parts", 0, "text")
            response["candidates"][0]["content"]["parts"][0]["text"]
          else
            "I apologize, but I couldn't generate a response."
          end
        rescue => e
          "Error: #{e.message}"
        end
      end

      # Generate events for the runner
      def run_async(message, context: nil)
        Enumerator.new do |yielder|
          begin
            response_text = call(message)
            
            event = Event.new(
              invocation_id: context&.invocation_id || "inv-#{SecureRandom.uuid}",
              author: @name,
              content: response_text
            )
            
            yielder << event
            context&.add_event(event) if context
            
          rescue => e
            error_event = Event.new(
              invocation_id: context&.invocation_id || "inv-#{SecureRandom.uuid}",
              author: @name,
              content: "Error: #{e.message}"
            )
            yielder << error_event
          end
        end
      end
    end
  end
end