# frozen_string_literal: true

require "faraday"
require "json"
require "securerandom"

module Google
  module ADK
    # Client for interacting with OpenRouter's OpenAI-compatible API
    class OpenRouterClient
      API_BASE_URL = "https://openrouter.ai/api/v1"
      DEFAULT_MODEL = "openrouter/auto"
      
      attr_reader :api_key

      def initialize(api_key: nil)
        @api_key = api_key || ENV["OPENROUTER_API_KEY"]
        raise ConfigurationError, "OPENROUTER_API_KEY not set" unless @api_key
        
        @client = Faraday.new(API_BASE_URL) do |conn|
          conn.request :json
          conn.response :json
          conn.adapter Faraday.default_adapter
        end
      end

      # Generate content using OpenRouter API
      #
      # @param model [String] Model name (e.g., "openrouter/auto", "anthropic/claude-3-haiku")
      # @param messages [Array<Hash>] Conversation messages
      # @param tools [Array<Hash>] Available tools (optional)
      # @param system_instruction [String] System instruction (optional)
      # @return [Hash] API response formatted to match Gemini response structure
      def generate_content(model:, messages:, tools: nil, system_instruction: nil)
        url = "/chat/completions"
        
        # Convert messages to OpenAI format
        openai_messages = format_messages(messages)
        
        # Add system message if provided
        if system_instruction
          openai_messages.unshift({
            role: "system",
            content: system_instruction
          })
        end
        
        payload = {
          model: model || DEFAULT_MODEL,
          messages: openai_messages,
          max_tokens: 8192,
          temperature: 0.7,
          top_p: 0.95
        }
        
        # Add tools if provided
        if tools && !tools.empty?
          payload[:tools] = format_tools(tools)
          payload[:tool_choice] = "auto"
        end
        
        response = @client.post(url) do |req|
          req.headers["Authorization"] = "Bearer #{@api_key}"
          req.headers["Content-Type"] = "application/json"
          req.headers["HTTP-Referer"] = "https://github.com/google-adk"
          req.headers["X-Title"] = "Google ADK Client"
          req.body = payload
        end
        
        handle_response(response)
      end

      private

      # Format messages for OpenRouter/OpenAI API
      def format_messages(messages)
        messages.map do |msg|
          if msg[:parts]
            # Handle Gemini-formatted messages
            convert_gemini_message(msg)
          else
            # Simple text messages
            {
              role: normalize_role(msg[:role]),
              content: msg[:content]
            }
          end
        end.flatten.compact
      end

      # Convert Gemini-formatted message to OpenAI format
      def convert_gemini_message(msg)
        role = msg[:role] == "model" ? "assistant" : normalize_role(msg[:role])
        
        # Handle different part types
        msg[:parts].map do |part|
          if part[:text]
            # Text part
            { role: role, content: part[:text] }
          elsif part[:functionCall]
            # Tool call - OpenAI format uses tool_calls array
            {
              role: "assistant",
              content: nil,
              tool_calls: [{
                id: "call_#{SecureRandom.hex(8)}",
                type: "function",
                function: {
                  name: part[:functionCall][:name],
                  arguments: JSON.generate(part[:functionCall][:args] || {})
                }
              }]
            }
          elsif part[:functionResponse]
            # Tool response
            {
              role: "tool",
              content: JSON.generate(part[:functionResponse][:response]),
              tool_call_id: "call_#{SecureRandom.hex(8)}" # Would need to track this properly
            }
          else
            # Default to text
            { role: role, content: part.to_s }
          end
        end
      end

      # Normalize role names
      def normalize_role(role)
        case role.to_s
        when "model", "assistant"
          "assistant"
        when "function"
          "tool"
        else
          role.to_s
        end
      end

      # Format tools for OpenRouter/OpenAI API
      def format_tools(tools)
        tools.map do |tool|
          {
            type: "function",
            function: {
              name: tool["name"],
              description: tool["description"],
              parameters: tool["parameters"] || {
                type: "object",
                properties: {},
                required: []
              }
            }
          }
        end
      end

      # Handle API response and convert to Gemini format
      def handle_response(response)
        case response.status
        when 200
          convert_to_gemini_format(response.body)
        when 400
          error_msg = response.body.dig("error", "message") || response.body["error"] || response.body
          raise Error, "Bad request: #{error_msg}"
        when 401
          raise ConfigurationError, "Invalid API key"
        when 402
          raise Error, "Insufficient credits. Please add credits to your OpenRouter account."
        when 429
          raise Error, "Rate limit exceeded"
        when 503
          raise Error, "Model provider temporarily unavailable"
        else
          error_msg = response.body.dig("error", "message") || response.body["error"] || response.body
          raise Error, "API error (#{response.status}): #{error_msg}"
        end
      end

      # Convert OpenRouter/OpenAI response to Gemini format for compatibility
      def convert_to_gemini_format(openai_response)
        # Get the first choice (OpenAI returns array of choices)
        choice = openai_response["choices"]&.first
        return empty_response unless choice
        
        message = choice["message"]
        parts = []
        
        # Handle text content
        if message["content"]
          parts << { "text" => message["content"] }
        end
        
        # Handle tool calls
        if message["tool_calls"]
          message["tool_calls"].each do |tool_call|
            if tool_call["type"] == "function"
              parts << {
                "functionCall" => {
                  "name" => tool_call["function"]["name"],
                  "args" => JSON.parse(tool_call["function"]["arguments"])
                }
              }
            end
          end
        end
        
        # Format as Gemini response
        {
          "candidates" => [
            {
              "content" => {
                "parts" => parts,
                "role" => "model"
              }
            }
          ]
        }
      end

      def empty_response
        {
          "candidates" => [
            {
              "content" => {
                "parts" => [{ "text" => "" }],
                "role" => "model"
              }
            }
          ]
        }
      end
    end
  end
end