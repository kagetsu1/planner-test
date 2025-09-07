//
// MeetingLinkStore.swift
// Fast MVP: store Zoom/Meet links per Class without changing Core Data (UserDefaults-based).

import Foundation
import SwiftUI
import CoreData

final class MeetingLinkStore: ObservableObject {
    static let shared = MeetingLinkStore()
    @AppStorage("meetingLinks") private var meetingLinksJSON: String = "{}"
    @Published private(set) var links: [String: String] = [:] // key: class URI string, value: URL string

    init() {
        if let data = meetingLinksJSON.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            self.links = dict
        }
    }

    func link(for course: Course) -> URL? {
        let key = course.objectID.uriRepresentation().absoluteString
        guard let s = links[key], let url = URL(string: s) else { return nil }
        return url
    }

    func setLink(_ urlString: String?, for course: Course) {
        let key = course.objectID.uriRepresentation().absoluteString
        if let u = urlString, !u.isEmpty {
            links[key] = u
        } else {
            links.removeValue(forKey: key)
        }
        persist()
    }

    private func persist() {
        if let data = try? JSONSerialization.data(withJSONObject: links, options: []),
           let s = String(data: data, encoding: .utf8) {
            meetingLinksJSON = s
        }
    }
}
