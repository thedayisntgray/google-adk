# frozen_string_literal: true

require "faraday"
require "json"
require "securerandom"

module Google
  module ADK
    # Client for interacting with Anthropic's Claude API
    class AnthropicClient
      API_BASE_URL = "https://api.anthropic.com"
      API_VERSION = "2023-06-01"
      DEFAULT_MODEL = "claude-3-5-sonnet-20241022"
      
      attr_reader :api_key

      def initialize(api_key: nil)
        @api_key = api_key || ENV["ANTHROPIC_API_KEY"]
        raise ConfigurationError, "ANTHROPIC_API_KEY not set" unless @api_key
        
        @client = Faraday.new(API_BASE_URL) do |conn|
          conn.request :json
          conn.response :json
          conn.adapter Faraday.default_adapter
        end
      end

      # Generate content using Anthropic API
      #
      # @param model [String] Model name (e.g., "claude-3-5-sonnet-20241022")
      # @param messages [Array<Hash>] Conversation messages
      # @param tools [Array<Hash>] Available tools (optional)
      # @param system_instruction [String] System instruction (optional)
      # @return [Hash] API response formatted to match Gemini response structure
      def generate_content(model:, messages:, tools: nil, system_instruction: nil)
        url = "/v1/messages"
        
        # Convert messages to Anthropic format
        anthropic_messages = format_messages(messages)
        
        # Adjust max_tokens based on model
        max_tokens = case model
        when /haiku/
          4096
        when /sonnet/
          4096
        when /opus/
          4096
        else
          4096  # Safe default for Claude models
        end
        
        payload = {
          model: model || DEFAULT_MODEL,
          messages: anthropic_messages,
          max_tokens: max_tokens,
          temperature: 0.7
        }
        
        # Add system instruction if provided
        payload[:system] = system_instruction if system_instruction
        
        # Add tools if provided
        if tools && !tools.empty?
          payload[:tools] = format_tools(tools)
        end
        
        response = @client.post(url) do |req|
          req.headers["x-api-key"] = @api_key
          req.headers["anthropic-version"] = API_VERSION
          req.headers["content-type"] = "application/json"
          req.body = payload
        end
        
        handle_response(response)
      end

      private

      # Format messages for Anthropic API
      def format_messages(messages)
        @tool_id_map ||= {}
        
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
        end
      end

      # Convert Gemini-formatted message to Anthropic format
      def convert_gemini_message(msg)
        role = msg[:role] == "model" ? "assistant" : normalize_role(msg[:role])
        
        # Handle different part types
        content = msg[:parts].map do |part|
          # Handle both symbol and string keys
          text = part[:text] || part["text"]
          function_call = part[:functionCall] || part["functionCall"]
          function_response = part[:functionResponse] || part["functionResponse"]
          
          if text
            # Text part
            { type: "text", text: text }
          elsif function_call
            # Tool use request - ensure name is a string and handle nested keys
            fc_name = function_call[:name] || function_call["name"]
            fc_args = function_call[:args] || function_call["args"] || {}
            
            # Generate and store tool ID
            tool_id = "tool_#{SecureRandom.hex(8)}"
            @tool_id_map[fc_name.to_s] = tool_id
            
            {
              type: "tool_use",
              id: tool_id,
              name: fc_name.to_s,
              input: fc_args
            }
          elsif function_response
            # Tool result
            fr_name = function_response[:name] || function_response["name"]
            fr_response = function_response[:response] || function_response["response"]
            
            # Retrieve the tool ID for this function
            tool_id = @tool_id_map[fr_name.to_s] || "tool_#{SecureRandom.hex(8)}"
            
            {
              type: "tool_result",
              tool_use_id: tool_id,
              content: JSON.generate(fr_response)
            }
          else
            # Default to text
            { type: "text", text: part.to_s }
          end
        end.flatten
        
        # Anthropic expects content as array for complex messages, string for simple
        content = content.first[:text] if content.length == 1 && content.first[:type] == "text"
        
        { role: role, content: content }
      end

      # Normalize role names
      def normalize_role(role)
        case role.to_s
        when "model", "assistant"
          "assistant"
        when "function", "tool"
          "user" # Anthropic treats tool responses as user messages
        else
          "user"
        end
      end

      # Format tools for Anthropic API
      def format_tools(tools)
        tools.map do |tool|
          {
            name: tool["name"],
            description: tool["description"],
            input_schema: tool["parameters"] || {
              type: "object",
              properties: {},
              required: []
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
          raise Error, "Bad request: #{response.body.dig('error', 'message') || response.body}"
        when 401
          raise ConfigurationError, "Invalid API key"
        when 429
          raise Error, "Rate limit exceeded"
        else
          raise Error, "API error (#{response.status}): #{response.body}"
        end
      end

      # Convert Anthropic response to Gemini format for compatibility
      def convert_to_gemini_format(anthropic_response)
        # Build parts from content
        parts = []
        
        content = anthropic_response["content"]
        content = [content] unless content.is_a?(Array)
        
        content.each do |item|
          if item.is_a?(String)
            # Simple text response
            parts << { "text" => item }
          elsif item.is_a?(Hash)
            case item["type"]
            when "text"
              parts << { "text" => item["text"] }
            when "tool_use"
              # Convert tool use to function call
              parts << {
                "functionCall" => {
                  "name" => item["name"].to_s,
                  "args" => item["input"]
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
    end
  end
end