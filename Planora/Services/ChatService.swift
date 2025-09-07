import Foundation
import CoreData
import MessageUI

/// Protocol for different chat transport implementations
protocol ChatTransport {
    var isAvailable: Bool { get async }
    var displayName: String { get }
    
    func getConversations() async throws -> [ChatConversation]
    func getMessages(for conversationId: String) async throws -> [ChatMessage]
    func sendMessage(_ text: String, to conversationId: String) async throws -> ChatMessage
    func createConversation(with userIds: [String], title: String?) async throws -> ChatConversation
    func sendAttachment(_ data: Data, fileName: String, mimeType: String, to conversationId: String) async throws -> ChatMessage?
}

/// Main chat service that chooses transport based on availability
class ChatService: ObservableObject {
    @Published var conversations: [ChatConversation] = []
    @Published var isLoading = false
    @Published var currentTransport: ChatTransport?
    @Published var errorMessage: String?
    
    private var moodleTransport: MoodleMessagingTransport?
    private var emailTransport = EmailBridgeTransport()
    private var pollingTimer: Timer?
    private var isPolling = false
    
    private var ctx: NSManagedObjectContext {
        DataController.shared.container.viewContext
    }
    
    init() {
        setupTransports()
        loadCachedConversations()
    }
    
    deinit {
        stopPolling()
    }
    
    /// Setup available transports
    private func setupTransports() {
        // Initialize Moodle transport if available
        let authService = MoodleAuthService()
        if authService.isAuthenticated {
            _Concurrency.Task { @MainActor in
                moodleTransport = MoodleMessagingTransport(authService: authService)
            }
        }
        
        // Probe for best available transport
        _Concurrency.Task {
            await probeTransports()
        }
    }
    
    /// Probe transports and select the best available one
    private func probeTransports() async {
        // Try Moodle messaging first
        if let moodleTransport = moodleTransport,
           await moodleTransport.isAvailable {
            await MainActor.run {
                self.currentTransport = moodleTransport
            }
            return
        }
        
        // Fallback to email bridge
        await MainActor.run {
            self.currentTransport = self.emailTransport
        }
    }
    
    /// Load conversations from cache and refresh
    func loadConversations() async {
        guard let transport = currentTransport else { return }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let conversations = try await transport.getConversations()
            
            await MainActor.run {
                self.conversations = conversations
                self.cacheConversations(conversations)
                self.isLoading = false
            }
            
            // Start polling for new messages
            startPolling()
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    /// Get messages for a conversation
    func getMessages(for conversationId: String) async -> [ChatMessage] {
        guard let transport = currentTransport else { return [] }
        
        do {
            let messages = try await transport.getMessages(for: conversationId)
            cacheMessages(messages, for: conversationId)
            return messages
        } catch {
            print("Error fetching messages: \(error)")
            return getCachedMessages(for: conversationId)
        }
    }
    
    /// Send a message
    func sendMessage(_ text: String, to conversationId: String) async throws -> ChatMessage {
        guard let transport = currentTransport else {
            throw ChatError.noTransportAvailable
        }
        
        let message = try await transport.sendMessage(text, to: conversationId)
        cacheMessage(message, for: conversationId)
        return message
    }
    
    /// Send an attachment
    func sendAttachment(_ data: Data, fileName: String, mimeType: String, to conversationId: String) async throws -> ChatMessage? {
        guard let transport = currentTransport else {
            throw ChatError.noTransportAvailable
        }
        
        if let message = try await transport.sendAttachment(data, fileName: fileName, mimeType: mimeType, to: conversationId) {
            cacheMessage(message, for: conversationId)
            return message
        }
        
        return nil
    }
    
    /// Create a new conversation
    func createConversation(with userIds: [String], title: String?) async throws -> ChatConversation {
        guard let transport = currentTransport else {
            throw ChatError.noTransportAvailable
        }
        
        let conversation = try await transport.createConversation(with: userIds, title: title)
        conversations.append(conversation)
        cacheConversation(conversation)
        return conversation
    }
    
    // MARK: - Polling
    
    private func startPolling() {
        guard !isPolling else { return }
        isPolling = true
        
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            _Concurrency.Task {
                await self?.pollForUpdates()
            }
        }
    }
    
    private func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        isPolling = false
    }
    
    private func pollForUpdates() async {
        // Poll for conversation updates (less frequent for background conversations)
        // This is a simplified implementation
        guard let transport = currentTransport else { return }
        
        do {
            let updatedConversations = try await transport.getConversations()
            
            await MainActor.run {
                self.conversations = updatedConversations
                self.cacheConversations(updatedConversations)
            }
        } catch {
            // Fail silently for background polling
        }
    }
    
    // MARK: - Caching
    
    private func loadCachedConversations() {
        let request: NSFetchRequest<ChatConversationCache> = ChatConversationCache.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ChatConversationCache.updatedAt, ascending: false)]
        
        do {
            let cached = try ctx.fetch(request)
            conversations = cached.compactMap { cache in
                guard let id = cache.id,
                      let title = cache.title,
                      let updatedAt = cache.updatedAt else { return nil }
                
                return ChatConversation(
                    id: id,
                    title: title,
                    isGroup: cache.isGroup,
                    lastMessage: nil,
                    lastMessageTime: updatedAt,
                    unreadCount: 0,
                    participants: []
                )
            }
        } catch {
            print("Error loading cached conversations: \(error)")
        }
    }
    
    private func cacheConversations(_ conversations: [ChatConversation]) {
        for conversation in conversations {
            cacheConversation(conversation)
        }
        
        try? ctx.save()
    }
    
    private func cacheConversation(_ conversation: ChatConversation) {
        let request: NSFetchRequest<ChatConversationCache> = ChatConversationCache.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", conversation.id)
        request.fetchLimit = 1
        
        do {
            let cached = try ctx.fetch(request).first ?? ChatConversationCache(context: ctx)
            cached.id = conversation.id
            cached.title = conversation.title
            cached.isGroup = conversation.isGroup
            cached.updatedAt = conversation.lastMessageTime
        } catch {
            print("Error caching conversation: \(error)")
        }
    }
    
    private func getCachedMessages(for conversationId: String) -> [ChatMessage] {
        let request: NSFetchRequest<ChatMessageCache> = ChatMessageCache.fetchRequest()
        request.predicate = NSPredicate(format: "conversationId == %@", conversationId)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ChatMessageCache.sentAt, ascending: true)]
        
        do {
            let cached = try ctx.fetch(request)
            return cached.compactMap { cache in
                guard let id = cache.id,
                      let senderId = cache.senderId,
                      let senderName = cache.senderName,
                      let text = cache.text,
                      let sentAt = cache.sentAt else { return nil }
                
                return ChatMessage(
                    id: id,
                    text: text,
                    senderId: senderId,
                    senderName: senderName,
                    sentAt: sentAt,
                    isMine: cache.isMine,
                    attachments: []
                )
            }
        } catch {
            print("Error loading cached messages: \(error)")
            return []
        }
    }
    
    private func cacheMessages(_ messages: [ChatMessage], for conversationId: String) {
        for message in messages {
            cacheMessage(message, for: conversationId)
        }
        
        try? ctx.save()
    }
    
    private func cacheMessage(_ message: ChatMessage, for conversationId: String) {
        let request: NSFetchRequest<ChatMessageCache> = ChatMessageCache.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", message.id)
        request.fetchLimit = 1
        
        do {
            let cached = try ctx.fetch(request).first ?? ChatMessageCache(context: ctx)
            cached.id = message.id
            cached.conversationId = conversationId
            cached.senderId = message.senderId
            cached.senderName = message.senderName
            cached.text = message.text
            cached.sentAt = message.sentAt
            cached.isMine = message.isMine
        } catch {
            print("Error caching message: \(error)")
        }
    }
}

// MARK: - Moodle Messaging Transport

@MainActor
class MoodleMessagingTransport: ChatTransport {
    let displayName = "Moodle Messaging"
    private let authService: MoodleAuthService
    private let moodleService = MoodleService()
    
    init(authService: MoodleAuthService) {
        self.authService = authService
    }
    
    var isAvailable: Bool {
        get async {
            return authService.isAuthenticated &&
                   moodleService.isCapabilityAvailable("core_message_get_conversations")
        }
    }
    
    func getConversations() async throws -> [ChatConversation] {
        guard let config = createMoodleConfig() else {
            throw ChatError.notAuthenticated
        }
        
        let result = try await callMoodleAPI(config: config, function: "core_message_get_conversations", params: [:])
        
        guard let conversations = result as? [[String: Any]] else {
            throw ChatError.invalidResponse
        }
        
        return conversations.compactMap { data in
            guard let id = data["id"] as? Int,
                  let name = data["name"] as? String else { return nil }
            
            let isGroup = (data["type"] as? Int) == 2
            let lastMessageTime = (data["timecreated"] as? Double).map { Date(timeIntervalSince1970: $0) } ?? Date()
            
            return ChatConversation(
                id: String(id),
                title: name,
                isGroup: isGroup,
                lastMessage: data["lastmessage"] as? String,
                lastMessageTime: lastMessageTime,
                unreadCount: data["unreadcount"] as? Int ?? 0,
                participants: []
            )
        }
    }
    
    func getMessages(for conversationId: String) async throws -> [ChatMessage] {
        guard let config = createMoodleConfig() else {
            throw ChatError.notAuthenticated
        }
        
        let result = try await callMoodleAPI(config: config, function: "core_message_get_conversation_messages", params: [
            "conversationid": conversationId,
            "limitfrom": "0",
            "limitnum": "100"
        ])
        
        guard let response = result as? [String: Any],
              let messages = response["messages"] as? [[String: Any]] else {
            throw ChatError.invalidResponse
        }
        
        return messages.compactMap { data in
            guard let id = data["id"] as? Int,
                  let text = data["text"] as? String,
                  let userfromid = data["userfromid"] as? Int,
                  let userfromfullname = data["userfromfullname"] as? String,
                  let timecreated = data["timecreated"] as? Double else { return nil }
            
            return ChatMessage(
                id: String(id),
                text: text,
                senderId: String(userfromid),
                senderName: userfromfullname,
                sentAt: Date(timeIntervalSince1970: timecreated),
                isMine: data["useridfrom"] as? String == "me", // Simplified
                attachments: []
            )
        }
    }
    
    func sendMessage(_ text: String, to conversationId: String) async throws -> ChatMessage {
        guard let config = createMoodleConfig() else {
            throw ChatError.notAuthenticated
        }
        
        _ = try await callMoodleAPI(config: config, function: "core_message_send_messages_to_conversation", params: [
            "conversationid": conversationId,
            "messages[0][text]": text
        ])
        
        // Create message object from result
        let messageId = UUID().uuidString
        return ChatMessage(
            id: messageId,
            text: text,
            senderId: "me",
            senderName: "You",
            sentAt: Date(),
            isMine: true,
            attachments: []
        )
    }
    
    func createConversation(with userIds: [String], title: String?) async throws -> ChatConversation {
        // Implementation would depend on Moodle API capabilities
        throw ChatError.operationNotSupported
    }
    
    func sendAttachment(_ data: Data, fileName: String, mimeType: String, to conversationId: String) async throws -> ChatMessage? {
        // Would require file upload to Moodle draft area first
        // For now, fallback to inserting file link in message
        let fileLink = "📎 \(fileName)"
        return try await sendMessage(fileLink, to: conversationId)
    }
    
    private func createMoodleConfig() -> MoodleConfig? {
        guard let baseURLString = authService.baseURL,
              let baseURL = URL(string: baseURLString),
              let token = authService.token else {
            return nil
        }
        
        return MoodleConfig(baseURL: baseURL, token: token)
    }
    
    private func callMoodleAPI(config: MoodleConfig, function: String, params: [String: String]) async throws -> Any {
        var components = URLComponents(url: config.baseURL.appendingPathComponent("/webservice/rest/server.php"), resolvingAgainstBaseURL: false)!
        
        var queryItems = [
            URLQueryItem(name: "wstoken", value: config.token),
            URLQueryItem(name: "moodlewsrestformat", value: "json"),
            URLQueryItem(name: "wsfunction", value: function)
        ]
        
        for (key, value) in params {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        
        components.queryItems = queryItems
        
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        return try JSONSerialization.jsonObject(with: data)
    }
}

// MARK: - Email Bridge Transport

class EmailBridgeTransport: NSObject, ChatTransport {
    let displayName = "Email"
    
    var isAvailable: Bool {
        get {
            return MFMailComposeViewController.canSendMail()
        }
    }
    
    func getConversations() async throws -> [ChatConversation] {
        // Email bridge shows a single "Email" conversation
        return [
            ChatConversation(
                id: "email-bridge",
                title: "Email",
                isGroup: false,
                lastMessage: "Tap to compose email",
                lastMessageTime: Date(),
                unreadCount: 0,
                participants: []
            )
        ]
    }
    
    func getMessages(for conversationId: String) async throws -> [ChatMessage] {
        // Email bridge doesn't show message history
        return [
            ChatMessage(
                id: "email-info",
                text: "This will open your default email app. Messages sent via email won't appear here.",
                senderId: "system",
                senderName: "System",
                sentAt: Date(),
                isMine: false,
                attachments: []
            )
        ]
    }
    
    func sendMessage(_ text: String, to conversationId: String) async throws -> ChatMessage {
        // This would trigger email compose in the UI
        throw ChatError.needsUIPresentation
    }
    
    func createConversation(with userIds: [String], title: String?) async throws -> ChatConversation {
        throw ChatError.operationNotSupported
    }
    
    func sendAttachment(_ data: Data, fileName: String, mimeType: String, to conversationId: String) async throws -> ChatMessage? {
        throw ChatError.needsUIPresentation
    }
}

// MARK: - Data Models

struct ChatConversation {
    let id: String
    let title: String
    let isGroup: Bool
    let lastMessage: String?
    let lastMessageTime: Date
    let unreadCount: Int
    let participants: [ChatParticipant]
}

struct ChatMessage {
    let id: String
    let text: String
    let senderId: String
    let senderName: String
    let sentAt: Date
    let isMine: Bool
    let attachments: [ChatAttachment]
}

struct ChatParticipant {
    let id: String
    let name: String
    let avatarURL: String?
}

struct ChatAttachment {
    let id: String
    let fileName: String
    let fileSize: Int64
    let mimeType: String
    let url: String?
}

enum ChatError: LocalizedError {
    case noTransportAvailable
    case notAuthenticated
    case invalidResponse
    case operationNotSupported
    case needsUIPresentation
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .noTransportAvailable:
            return "No chat service available"
        case .notAuthenticated:
            return "Not authenticated"
        case .invalidResponse:
            return "Invalid response from server"
        case .operationNotSupported:
            return "Operation not supported"
        case .needsUIPresentation:
            return "This action requires UI presentation"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
