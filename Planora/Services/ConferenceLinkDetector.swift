import Foundation
import UIKit

/// Service for detecting and handling video conference links
class ConferenceLinkDetector: ObservableObject {
    
    /// Detect conference links in text and return structured data
    func detectLinks(in text: String) -> [ConferenceLink] {
        var links: [ConferenceLink] = []
        
        // Zoom patterns
        links.append(contentsOf: detectZoomLinks(in: text))
        
        // Google Meet patterns
        links.append(contentsOf: detectMeetLinks(in: text))
        
        // Microsoft Teams patterns
        links.append(contentsOf: detectTeamsLinks(in: text))
        
        // WebEx patterns
        links.append(contentsOf: detectWebExLinks(in: text))
        
        return links
    }
    
    /// Open conference link using deep link or fallback to web
    func openConferenceLink(_ link: ConferenceLink) {
        switch link.type {
        case .zoom:
            openZoomLink(link)
        case .googleMeet:
            openMeetLink(link)
        case .microsoftTeams:
            openTeamsLink(link)
        case .webex:
            openWebExLink(link)
        case .generic:
            openWebLink(link.originalURL)
        }
    }
    
    // MARK: - Zoom Detection and Handling
    
    private func detectZoomLinks(in text: String) -> [ConferenceLink] {
        let patterns = [
            #"https?://[\w\-\.]*zoom\.us/j/(\d+)(?:\?pwd=([A-Za-z0-9]+))?"#,
            #"https?://[\w\-\.]*zoom\.us/webinar/register/[\w/]+"#,
            #"https?://[\w\-\.]*zoom\.us/s/(\d+)(?:\?pwd=([A-Za-z0-9]+))?"#
        ]
        
        var links: [ConferenceLink] = []
        
        for pattern in patterns {
            let regex = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = regex.matches(in: text, range: range)
            
            for match in matches {
                if let urlRange = Range(match.range, in: text) {
                    let urlString = String(text[urlRange])
                    
                    var meetingId: String?
                    var password: String?
                    
                    if match.numberOfRanges > 1,
                       let idRange = Range(match.range(at: 1), in: text) {
                        meetingId = String(text[idRange])
                    }
                    
                    if match.numberOfRanges > 2,
                       let pwdRange = Range(match.range(at: 2), in: text) {
                        password = String(text[pwdRange])
                    }
                    
                    let link = ConferenceLink(
                        type: .zoom,
                        originalURL: urlString,
                        meetingId: meetingId,
                        password: password,
                        displayName: "Zoom Meeting"
                    )
                    
                    links.append(link)
                }
            }
        }
        
        return links
    }
    
    private func openZoomLink(_ link: ConferenceLink) {
        // Try Zoom app deep link first
        if let meetingId = link.meetingId {
            var deepLinkString = "zoomus://zoom.us/join?confno=\(meetingId)"
            
            if let password = link.password {
                deepLinkString += "&pwd=\(password)"
            }
            
            if let deepLinkURL = URL(string: deepLinkString),
               UIApplication.shared.canOpenURL(deepLinkURL) {
                UIApplication.shared.open(deepLinkURL)
                return
            }
        }
        
        // Fallback to web
        openWebLink(link.originalURL)
    }
    
    // MARK: - Google Meet Detection and Handling
    
    private func detectMeetLinks(in text: String) -> [ConferenceLink] {
        let patterns = [
            #"https?://meet\.google\.com/[\w\-]+"#,
            #"https?://[\w\-\.]*\.meet\.google\.com/[\w\-]+"#
        ]
        
        var links: [ConferenceLink] = []
        
        for pattern in patterns {
            let regex = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = regex.matches(in: text, range: range)
            
            for match in matches {
                if let urlRange = Range(match.range, in: text) {
                    let urlString = String(text[urlRange])
                    
                    // Extract meeting code from URL
                    let meetingCode = extractMeetingCode(from: urlString)
                    
                    let link = ConferenceLink(
                        type: .googleMeet,
                        originalURL: urlString,
                        meetingId: meetingCode,
                        password: nil,
                        displayName: "Google Meet"
                    )
                    
                    links.append(link)
                }
            }
        }
        
        return links
    }
    
    private func extractMeetingCode(from url: String) -> String? {
        guard let urlComponents = URLComponents(string: url) else { return nil }
        
        // Meeting code is typically the last path component
        let pathComponents = urlComponents.path.components(separatedBy: "/")
        return pathComponents.last?.isEmpty == false ? pathComponents.last : nil
    }
    
    private func openMeetLink(_ link: ConferenceLink) {
        // Try Google Meet app deep link
        if let meetingId = link.meetingId {
            let deepLinkString = "comgooglemeet://meet.google.com/\(meetingId)"
            
            if let deepLinkURL = URL(string: deepLinkString),
               UIApplication.shared.canOpenURL(deepLinkURL) {
                UIApplication.shared.open(deepLinkURL)
                return
            }
        }
        
        // Fallback to web
        openWebLink(link.originalURL)
    }
    
    // MARK: - Microsoft Teams Detection and Handling
    
    private func detectTeamsLinks(in text: String) -> [ConferenceLink] {
        let patterns = [
            #"https?://teams\.microsoft\.com/l/meetup-join/[\w%\-\.]+"#,
            #"https?://[\w\-\.]*\.teams\.microsoft\.com/[\w/\-\.]+"#
        ]
        
        var links: [ConferenceLink] = []
        
        for pattern in patterns {
            let regex = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = regex.matches(in: text, range: range)
            
            for match in matches {
                if let urlRange = Range(match.range, in: text) {
                    let urlString = String(text[urlRange])
                    
                    let link = ConferenceLink(
                        type: .microsoftTeams,
                        originalURL: urlString,
                        meetingId: nil,
                        password: nil,
                        displayName: "Microsoft Teams"
                    )
                    
                    links.append(link)
                }
            }
        }
        
        return links
    }
    
    private func openTeamsLink(_ link: ConferenceLink) {
        // Try Teams app deep link
        let deepLinkString = "msteams://\(link.originalURL)"
        
        if let deepLinkURL = URL(string: deepLinkString),
           UIApplication.shared.canOpenURL(deepLinkURL) {
            UIApplication.shared.open(deepLinkURL)
            return
        }
        
        // Fallback to web
        openWebLink(link.originalURL)
    }
    
    // MARK: - WebEx Detection and Handling
    
    private func detectWebExLinks(in text: String) -> [ConferenceLink] {
        let patterns = [
            #"https?://[\w\-\.]*\.webex\.com/[\w/\-\.]+"#,
            #"https?://[\w\-\.]*\.my\.webex\.com/[\w/\-\.]+"#
        ]
        
        var links: [ConferenceLink] = []
        
        for pattern in patterns {
            let regex = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = regex.matches(in: text, range: range)
            
            for match in matches {
                if let urlRange = Range(match.range, in: text) {
                    let urlString = String(text[urlRange])
                    
                    let link = ConferenceLink(
                        type: .webex,
                        originalURL: urlString,
                        meetingId: nil,
                        password: nil,
                        displayName: "WebEx Meeting"
                    )
                    
                    links.append(link)
                }
            }
        }
        
        return links
    }
    
    private func openWebExLink(_ link: ConferenceLink) {
        // WebEx typically opens in web browser
        openWebLink(link.originalURL)
    }
    
    // MARK: - Generic Link Handling
    
    private func openWebLink(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
    
    /// Extract all links from text for quick access buttons
    func extractQuickJoinLinks(from text: String) -> [ConferenceLink] {
        let links = detectLinks(in: text)
        
        // Deduplicate and sort by priority
        var uniqueLinks: [ConferenceLink] = []
        var seenURLs: Set<String> = []
        
        let priority: [ConferenceType] = [.zoom, .googleMeet, .microsoftTeams, .webex, .generic]
        
        for type in priority {
            for link in links where link.type == type {
                if !seenURLs.contains(link.originalURL) {
                    seenURLs.insert(link.originalURL)
                    uniqueLinks.append(link)
                }
            }
        }
        
        return uniqueLinks
    }
    
    /// Check if text contains any conference links
    func containsConferenceLinks(_ text: String) -> Bool {
        return !detectLinks(in: text).isEmpty
    }
    
    /// Get the primary conference link from text (first one found)
    func getPrimaryLink(from text: String) -> ConferenceLink? {
        return detectLinks(in: text).first
    }
}

// MARK: - Data Models

struct ConferenceLink {
    let type: ConferenceType
    let originalURL: String
    let meetingId: String?
    let password: String?
    let displayName: String
    
    var shortDisplayName: String {
        switch type {
        case .zoom:
            return "Zoom"
        case .googleMeet:
            return "Meet"
        case .microsoftTeams:
            return "Teams"
        case .webex:
            return "WebEx"
        case .generic:
            return "Join"
        }
    }
    
    var iconName: String {
        switch type {
        case .zoom:
            return "video.fill"
        case .googleMeet:
            return "video.fill"
        case .microsoftTeams:
            return "video.fill"
        case .webex:
            return "video.fill"
        case .generic:
            return "link"
        }
    }
}

enum ConferenceType: CaseIterable {
    case zoom
    case googleMeet
    case microsoftTeams
    case webex
    case generic
}
