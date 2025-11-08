import Foundation

/// AI-powered terminal assistant
class AIAssistant {
    // MARK: - Types

    enum AIProvider {
        case openai
        case anthropic
        case local  // Ollama or similar
    }

    struct AIConfiguration {
        var provider: AIProvider = .openai
        var apiKey: String = ""
        var model: String = "gpt-4"
        var temperature: Float = 0.7
        var maxTokens: Int = 1000

        // Local model settings
        var localModelURL: String = "http://localhost:11434"  // Ollama default
        var localModelName: String = "llama2"
    }

    struct CommandSuggestion {
        let command: String
        let description: String
        let confidence: Float
    }

    struct ErrorExplanation {
        let error: String
        let explanation: String
        let suggestedFix: String
    }

    // MARK: - Properties

    private var configuration: AIConfiguration
    private let httpClient: HTTPClient

    private var conversationHistory: [ConversationMessage] = []

    struct ConversationMessage: Codable {
        let role: String  // "user" or "assistant"
        let content: String
    }

    // MARK: - Initialization

    init(configuration: AIConfiguration = AIConfiguration()) {
        self.configuration = configuration
        self.httpClient = HTTPClient()
    }

    // MARK: - Command Suggestions

    /// Get command suggestions based on natural language
    func suggestCommand(for query: String) async throws -> [CommandSuggestion] {
        let prompt = """
        User wants to: \(query)

        Suggest appropriate terminal commands for this task. Return up to 3 suggestions.
        Format each as: COMMAND | DESCRIPTION

        Examples:
        find . -name "*.txt" | Find all text files in current directory
        grep -r "pattern" . | Search for pattern in all files recursively
        """

        let response = try await sendPrompt(prompt)

        return parseCommandSuggestions(response)
    }

    private func parseCommandSuggestions(_ response: String) -> [CommandSuggestion] {
        var suggestions: [CommandSuggestion] = []

        for line in response.components(separatedBy: "\n") {
            let parts = line.components(separatedBy: "|")
            guard parts.count == 2 else { continue }

            let command = parts[0].trimmingCharacters(in: .whitespaces)
            let description = parts[1].trimmingCharacters(in: .whitespaces)

            suggestions.append(CommandSuggestion(
                command: command,
                description: description,
                confidence: 0.8
            ))
        }

        return suggestions
    }

    // MARK: - Error Explanation

    /// Explain an error and suggest a fix
    func explainError(_ errorOutput: String, command: String) async throws -> ErrorExplanation {
        let prompt = """
        Command executed: \(command)

        Error output:
        \(errorOutput)

        Please explain what this error means and suggest how to fix it.
        Format: EXPLANATION | SUGGESTED FIX
        """

        let response = try await sendPrompt(prompt)

        let parts = response.components(separatedBy: "|")
        if parts.count >= 2 {
            return ErrorExplanation(
                error: errorOutput,
                explanation: parts[0].trimmingCharacters(in: .whitespaces),
                suggestedFix: parts[1].trimmingCharacters(in: .whitespaces)
            )
        }

        return ErrorExplanation(
            error: errorOutput,
            explanation: response,
            suggestedFix: "No specific fix suggested"
        )
    }

    // MARK: - Output Summarization

    /// Summarize long terminal output
    func summarizeOutput(_ output: String, maxLength: Int = 200) async throws -> String {
        guard output.count > maxLength else { return output }

        let prompt = """
        Summarize this terminal output in a few sentences:

        \(output.prefix(5000))
        """

        return try await sendPrompt(prompt)
    }

    // MARK: - Interactive Assistant

    /// Chat with AI assistant
    func chat(_ message: String) async throws -> String {
        // Add user message to history
        conversationHistory.append(ConversationMessage(role: "user", content: message))

        let response = try await sendPromptWithHistory(message)

        // Add assistant response to history
        conversationHistory.append(ConversationMessage(role: "assistant", content: response))

        return response
    }

    /// Clear conversation history
    func clearHistory() {
        conversationHistory = []
    }

    // MARK: - LLM Communication

    private func sendPrompt(_ prompt: String) async throws -> String {
        switch configuration.provider {
        case .openai:
            return try await sendToOpenAI(prompt)
        case .anthropic:
            return try await sendToAnthropic(prompt)
        case .local:
            return try await sendToLocal(prompt)
        }
    }

    private func sendPromptWithHistory(_ prompt: String) async throws -> String {
        // Include conversation history for context-aware responses
        let messages = conversationHistory + [ConversationMessage(role: "user", content: prompt)]

        switch configuration.provider {
        case .openai:
            return try await sendToOpenAIWithHistory(messages)
        case .anthropic:
            return try await sendToAnthropicWithHistory(messages)
        case .local:
            return try await sendToLocalWithHistory(messages)
        }
    }

    // MARK: - OpenAI Integration

    private func sendToOpenAI(_ prompt: String) async throws -> String {
        guard !configuration.apiKey.isEmpty else {
            throw AIError.noAPIKey
        }

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!

        let body: [String: Any] = [
            "model": configuration.model,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": configuration.temperature,
            "max_tokens": configuration.maxTokens
        ]

        let headers = [
            "Authorization": "Bearer \(configuration.apiKey)",
            "Content-Type": "application/json"
        ]

        let response = try await httpClient.post(url: url, body: body, headers: headers)

        // Parse OpenAI response
        if let choices = response["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }

        throw AIError.invalidResponse
    }

    private func sendToOpenAIWithHistory(_ messages: [ConversationMessage]) async throws -> String {
        guard !configuration.apiKey.isEmpty else {
            throw AIError.noAPIKey
        }

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!

        let messagesDicts = messages.map { ["role": $0.role, "content": $0.content] }

        let body: [String: Any] = [
            "model": configuration.model,
            "messages": messagesDicts,
            "temperature": configuration.temperature,
            "max_tokens": configuration.maxTokens
        ]

        let headers = [
            "Authorization": "Bearer \(configuration.apiKey)",
            "Content-Type": "application/json"
        ]

        let response = try await httpClient.post(url: url, body: body, headers: headers)

        if let choices = response["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }

        throw AIError.invalidResponse
    }

    // MARK: - Anthropic Integration

    private func sendToAnthropic(_ prompt: String) async throws -> String {
        // Similar to OpenAI but for Claude API
        // Implementation would follow Anthropic's API spec
        throw AIError.notImplemented
    }

    private func sendToAnthropicWithHistory(_ messages: [ConversationMessage]) async throws -> String {
        throw AIError.notImplemented
    }

    // MARK: - Local Model Integration (Ollama)

    private func sendToLocal(_ prompt: String) async throws -> String {
        let url = URL(string: "\(configuration.localModelURL)/api/generate")!

        let body: [String: Any] = [
            "model": configuration.localModelName,
            "prompt": prompt
        ]

        let response = try await httpClient.post(url: url, body: body, headers: [:])

        if let responseText = response["response"] as? String {
            return responseText
        }

        throw AIError.invalidResponse
    }

    private func sendToLocalWithHistory(_ messages: [ConversationMessage]) async throws -> String {
        // Ollama chat format
        let url = URL(string: "\(configuration.localModelURL)/api/chat")!

        let messagesDicts = messages.map { ["role": $0.role, "content": $0.content] }

        let body: [String: Any] = [
            "model": configuration.localModelName,
            "messages": messagesDicts
        ]

        let response = try await httpClient.post(url: url, body: body, headers: [:])

        if let message = response["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }

        throw AIError.invalidResponse
    }

    // MARK: - Errors

    enum AIError: Error {
        case noAPIKey
        case invalidResponse
        case networkError
        case notImplemented
    }
}

// MARK: - HTTP Client

class HTTPClient {
    func post(url: URL, body: [String: Any], headers: [String: String]) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AIAssistant.AIError.networkError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIAssistant.AIError.invalidResponse
        }

        return json
    }
}
