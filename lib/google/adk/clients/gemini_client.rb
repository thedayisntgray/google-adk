# frozen_string_literal: true

require "faraday"
require "json"

module Google
  module ADK
    # Client for interacting with Google's Gemini API
    class GeminiClient
      API_BASE_URL = "https://generativelanguage.googleapis.com"
      
      attr_reader :api_key

      def initialize(api_key: nil)
        @api_key = api_key || ENV["GEMINI_API_KEY"] || ENV["GOOGLE_API_KEY"]
        raise ConfigurationError, "GEMINI_API_KEY or GOOGLE_API_KEY not set" unless @api_key
        
        @client = Faraday.new(API_BASE_URL) do |conn|
          conn.request :json
          conn.response :json
          conn.adapter Faraday.default_adapter
        end
      end

      # Generate content using Gemini API
      #
      # @param model [String] Model name (e.g., "gemini-2.0-flash")
      # @param messages [Array<Hash>] Conversation messages
      # @param tools [Array<Hash>] Available tools (optional)
      # @param system_instruction [String] System instruction (optional)
      # @return [Hash] API response
      def generate_content(model:, messages:, tools: nil, system_instruction: nil)
        url = "/v1beta/models/#{model}:generateContent"
        
        payload = {
          contents: format_messages(messages),
          generationConfig: {
            temperature: 0.7,
            topK: 40,
            topP: 0.95,
            maxOutputTokens: 8192
          }
        }
        
        payload[:systemInstruction] = { parts: [{ text: system_instruction }] } if system_instruction
        payload[:tools] = [{ functionDeclarations: tools }] if tools && !tools.empty?
        
        response = @client.post("#{url}?key=#{@api_key}") do |req|
          req.body = payload
        end
        
        handle_response(response)
      end

      private

      # Format messages for Gemini API
      def format_messages(messages)
        messages.map do |msg|
          if msg[:parts]
            # Already formatted
            msg
          else
            # Convert simple text messages
            {
              role: msg[:role] == "assistant" ? "model" : msg[:role],
              parts: [{ text: msg[:content] }]
            }
          end
        end
      end

      # Handle API response
      def handle_response(response)
        case response.status
        when 200
          response.body
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
    end
  end
end