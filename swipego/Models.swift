//
//  Models.swift
//  swipego
//
//  Created by apple on 8/31/26.
//

import Foundation
import CoreLocation
import Photos

enum MediaKind: String, CaseIterable, Identifiable, Codable {
    case videos = "Videos"
    case photos = "Photos"
    case livePhotos = "Live Photos"
    case screenshots = "Screenshots"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .videos: "play.rectangle.fill"
        case .photos: "photo.fill"
        case .livePhotos: "livephoto"
        case .screenshots: "rectangle.on.rectangle.angled"
        }
    }

    var tintName: String {
        switch self {
        case .videos: "teal"
        case .photos: "green"
        case .livePhotos: "mint"
        case .screenshots: "blue"
        }
    }
}

struct MediaCategorySummary: Identifiable, Equatable {
    let kind: MediaKind
    let count: Int
    let bytes: Int64

    var id: MediaKind { kind }
}

struct AlbumOverview: Equatable {
    var usedBytes: Int64 = 0
    var deviceBytes: Int64 = 0
    var topCategories: [MediaCategorySummary] = []

    static let empty = AlbumOverview()
}

struct MediaAsset: Identifiable, Hashable {
    let id: String
    let asset: PHAsset
    let kind: MediaKind
    let bytes: Int64
    let creationDate: Date?
    let duration: TimeInterval
    let location: CLLocation?

    var displayDate: Date { creationDate ?? .now }

    static func == (lhs: MediaAsset, rhs: MediaAsset) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum SwipeGroupKind: String, CaseIterable, Identifiable {
    case random = "Random"
    case videos = "Videos"
    case memories = "Memories"
    case screenshots = "Screenshots"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .random: "A tidy daily stack"
        case .videos: "Largest moments first"
        case .memories: "Past days worth revisiting"
        case .screenshots: "Quick captures to clear"
        }
    }

    var iconName: String {
        switch self {
        case .random: "shuffle"
        case .videos: "film.stack"
        case .memories: "sparkles"
        case .screenshots: "rectangle.dashed"
        }
    }

    var groupTitle: String {
        switch self {
        case .random: "Blind Box"
        case .videos: "Big Videos"
        case .memories: "Memories"
        case .screenshots: "Screenshots"
        }
    }
}

struct SwipeGroup: Identifiable, Hashable {
    let id = UUID()
    let kind: SwipeGroupKind
    let title: String
    let assets: [MediaAsset]

    var coverAsset: MediaAsset? { assets.first }

    static func == (lhs: SwipeGroup, rhs: SwipeGroup) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct DailyCleanupStats: Equatable, Codable {
    var browsedByKind: [MediaKind: Int] = [:]
    var deletedByKind: [MediaKind: Int] = [:]
    var savedBytesByKind: [MediaKind: Int64] = [:]
    var activityByDay: [Date: DailyCleanupActivity] = [:]
    var savedBytes: Int64 = 0
    var browsedAssetIDs: Set<String> = []

    init() { }

    private enum CodingKeys: String, CodingKey {
        case browsedByKind
        case deletedByKind
        case savedBytesByKind
        case activityByDay
        case savedBytes
        case browsedAssetIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        browsedByKind = try container.decodeIfPresent([MediaKind: Int].self, forKey: .browsedByKind) ?? [:]
        deletedByKind = try container.decodeIfPresent([MediaKind: Int].self, forKey: .deletedByKind) ?? [:]
        savedBytesByKind = try container.decodeIfPresent([MediaKind: Int64].self, forKey: .savedBytesByKind) ?? [:]
        activityByDay = try container.decodeIfPresent([Date: DailyCleanupActivity].self, forKey: .activityByDay) ?? [:]
        savedBytes = try container.decodeIfPresent(Int64.self, forKey: .savedBytes) ?? 0
        browsedAssetIDs = try container.decodeIfPresent(Set<String>.self, forKey: .browsedAssetIDs) ?? []
    }

    var browsedTotal: Int {
        browsedByKind.values.reduce(0, +)
    }

    var deletedTotal: Int {
        deletedByKind.values.reduce(0, +)
    }
}

struct DailyCleanupActivity: Equatable, Codable {
    var browsed = 0
    var deleted = 0
    var savedBytes: Int64 = 0
}

struct SystemAlbumSummary: Identifiable, Hashable {
    let id: String
    let title: String
    let assetIDs: Set<String>

    var count: Int { assetIDs.count }
}
