//
//  PhotoLibraryService.swift
//  swipego
//
//  Created by apple on 8/31/26.
//

import Foundation
import AVFoundation
import Photos
import PhotosUI
import UIKit

enum PhotoLibraryError: LocalizedError {
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .accessDenied: "SwipeGo needs full photo library access to organize and delete media."
        }
    }
}

@MainActor
final class PhotoLibraryService {
    private let imageManager = PHCachingImageManager()

    func requestAccess() async -> Bool {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if current == .authorized || current == .limited {
            return true
        }

        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status == .authorized || status == .limited)
            }
        }
    }

    func loadLibrary(browsedAssetIDs: Set<String>) async throws -> (overview: AlbumOverview, assets: [MediaAsset], groups: [SwipeGroup], systemAlbums: [SystemAlbumSummary]) {
        guard await requestAccess() else {
            throw PhotoLibraryError.accessDenied
        }

        let assets = fetchAssets()
        let overview = makeOverview(from: assets)
        let groups = makeSwipeGroups(from: assets, browsedAssetIDs: browsedAssetIDs)
        let systemAlbums = fetchSystemAlbums()
        return (overview, assets, groups, systemAlbums)
    }

    func requestImage(for asset: PHAsset, targetSize: CGSize) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true

            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !degraded {
                    continuation.resume(returning: image)
                }
            }
        }
    }

    func requestPlayerItem(for asset: PHAsset) async -> AVPlayerItem? {
        await withCheckedContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.deliveryMode = .automatic
            options.isNetworkAccessAllowed = true

            imageManager.requestPlayerItem(forVideo: asset, options: options) { playerItem, _ in
                continuation.resume(returning: playerItem)
            }
        }
    }

    func requestLivePhoto(for asset: PHAsset, targetSize: CGSize) async -> PHLivePhoto? {
        await withCheckedContinuation { continuation in
            let options = PHLivePhotoRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true

            imageManager.requestLivePhoto(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { livePhoto, info in
                let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !degraded {
                    continuation.resume(returning: livePhoto)
                }
            }
        }
    }

    func delete(_ mediaAssets: [MediaAsset]) async throws {
        let assets = mediaAssets.map(\.asset) as NSArray
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets)
        }
    }

    func followUpGroup(after kind: SwipeGroupKind, from assets: [MediaAsset], browsedAssetIDs: Set<String>) -> SwipeGroup? {
        if let sameKindGroup = makeSwipeGroup(kind: kind, from: assets, browsedAssetIDs: browsedAssetIDs, requiresUnseen: true) {
            return sameKindGroup
        }

        for candidateKind in [SwipeGroupKind.random, .videos, .memories, .screenshots] where candidateKind != kind {
            if let group = makeSwipeGroup(kind: candidateKind, from: assets, browsedAssetIDs: browsedAssetIDs, requiresUnseen: true) {
                return group
            }
        }

        for candidateKind in [SwipeGroupKind.random, .videos, .memories, .screenshots] {
            if let group = makeSwipeGroup(kind: candidateKind, from: assets, browsedAssetIDs: browsedAssetIDs, requiresUnseen: false) {
                return group
            }
        }

        return nil
    }

    private func fetchAssets() -> [MediaAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let result = PHAsset.fetchAssets(with: options)
        var items: [MediaAsset] = []
        items.reserveCapacity(result.count)

        result.enumerateObjects { asset, _, _ in
            guard let kind = Self.kind(for: asset) else { return }
            items.append(
                MediaAsset(
                    id: asset.localIdentifier,
                    asset: asset,
                    kind: kind,
                    bytes: Self.estimatedBytes(for: asset),
                    creationDate: asset.creationDate,
                    duration: asset.duration,
                    location: asset.location
                )
            )
        }

        return items
    }

    private func makeOverview(from assets: [MediaAsset]) -> AlbumOverview {
        let categories = MediaKind.allCases.map { kind in
            let matching = assets.filter { $0.kind == kind }
            return MediaCategorySummary(
                kind: kind,
                count: matching.count,
                bytes: matching.map(\.bytes).reduce(0, +)
            )
        }
        .sorted { lhs, rhs in
            if lhs.bytes == rhs.bytes {
                return lhs.count > rhs.count
            }
            return lhs.bytes > rhs.bytes
        }

        return AlbumOverview(
            usedBytes: categories.map(\.bytes).reduce(0, +),
            deviceBytes: Self.deviceCapacityBytes(),
            topCategories: Array(categories.prefix(4))
        )
    }

    private func makeSwipeGroups(from assets: [MediaAsset], browsedAssetIDs: Set<String>) -> [SwipeGroup] {
        return [
            makeSwipeGroup(kind: .random, from: assets, browsedAssetIDs: browsedAssetIDs, requiresUnseen: false),
            makeSwipeGroup(kind: .videos, from: assets, browsedAssetIDs: browsedAssetIDs, requiresUnseen: false),
            makeSwipeGroup(kind: .memories, from: assets, browsedAssetIDs: browsedAssetIDs, requiresUnseen: false),
            makeSwipeGroup(kind: .screenshots, from: assets, browsedAssetIDs: browsedAssetIDs, requiresUnseen: false)
        ].compactMap { $0 }
    }

    private func makeSwipeGroup(kind: SwipeGroupKind, from assets: [MediaAsset], browsedAssetIDs: Set<String>, requiresUnseen: Bool) -> SwipeGroup? {
        let groupAssets = swipeAssets(for: kind, from: assets, browsedAssetIDs: browsedAssetIDs)
        guard !groupAssets.isEmpty else { return nil }
        if requiresUnseen && !groupAssets.contains(where: { !browsedAssetIDs.contains($0.id) }) {
            return nil
        }

        let limit = kind == .videos ? 8 : 16
        let selected = Array(groupAssets.prefix(limit))
        guard !selected.isEmpty else { return nil }
        return SwipeGroup(kind: kind, title: kind.groupTitle, assets: selected)
    }

    private func swipeAssets(for kind: SwipeGroupKind, from assets: [MediaAsset], browsedAssetIDs: Set<String>) -> [MediaAsset] {
        switch kind {
        case .random:
            return prioritizedShuffle(assets.filter { $0.kind != .videos }, browsedAssetIDs: browsedAssetIDs)
        case .videos:
            return assets
                .filter { $0.kind == .videos }
                .sorted { lhs, rhs in
                    let lhsBrowsed = browsedAssetIDs.contains(lhs.id)
                    let rhsBrowsed = browsedAssetIDs.contains(rhs.id)
                    if lhsBrowsed != rhsBrowsed {
                        return !lhsBrowsed
                    }
                    if lhs.bytes == rhs.bytes {
                        return lhs.duration > rhs.duration
                    }
                    return lhs.bytes > rhs.bytes
                }
        case .memories:
            let calendar = Calendar.current
            let memoryCandidates = assets.filter { asset in
                guard let date = asset.creationDate else { return false }
                return calendar.component(.year, from: date) < calendar.component(.year, from: .now)
            }
            let prioritizedMemories = prioritizedShuffle(memoryCandidates, browsedAssetIDs: browsedAssetIDs)
            return prioritizedMemories.isEmpty ? prioritizedShuffle(assets, browsedAssetIDs: browsedAssetIDs) : prioritizedMemories
        case .screenshots:
            return prioritizedShuffle(assets.filter { $0.kind == .screenshots }, browsedAssetIDs: browsedAssetIDs)
        }
    }

    private func prioritizedShuffle(_ assets: [MediaAsset], browsedAssetIDs: Set<String>) -> [MediaAsset] {
        let unseen = assets.filter { !browsedAssetIDs.contains($0.id) }.shuffled()
        let seen = assets.filter { browsedAssetIDs.contains($0.id) }.shuffled()
        return unseen + seen
    }

    private func fetchSystemAlbums() -> [SystemAlbumSummary] {
        let subtypes: [PHAssetCollectionSubtype] = [
            .smartAlbumUserLibrary,
            .smartAlbumFavorites,
            .smartAlbumRecentlyAdded,
            .smartAlbumVideos,
            .smartAlbumLivePhotos,
            .smartAlbumScreenshots,
            .smartAlbumSelfPortraits,
            .smartAlbumPanoramas,
            .smartAlbumBursts,
            .smartAlbumDepthEffect,
            .smartAlbumLongExposures,
            .smartAlbumAnimated,
            .smartAlbumSlomoVideos,
            .smartAlbumTimelapses,
            .smartAlbumCinematic,
            .smartAlbumRAW,
            .smartAlbumUnableToUpload
        ]

        return subtypes.compactMap { subtype in
            let collections = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: subtype, options: nil)
            guard let collection = collections.firstObject else { return nil }
            let assets = PHAsset.fetchAssets(in: collection, options: nil)
            guard assets.count > 0 else { return nil }

            var ids = Set<String>()
            assets.enumerateObjects { asset, _, _ in
                ids.insert(asset.localIdentifier)
            }

            return SystemAlbumSummary(
                id: collection.localIdentifier,
                title: Self.normalizedTitle(collection.localizedTitle ?? Self.fallbackTitle(for: subtype)),
                assetIDs: ids
            )
        }
    }

    private static func kind(for asset: PHAsset) -> MediaKind? {
        if asset.mediaType == .video {
            return .videos
        }
        if asset.mediaSubtypes.contains(.photoScreenshot) {
            return .screenshots
        }
        if asset.mediaSubtypes.contains(.photoLive) {
            return .livePhotos
        }
        if asset.mediaType == .image {
            return .photos
        }
        return nil
    }

    private static func estimatedBytes(for asset: PHAsset) -> Int64 {
        PHAssetResource.assetResources(for: asset).reduce(Int64(0)) { total, resource in
            let fileSize = resource.value(forKey: "fileSize") as? CLongLong
            return total + Int64(fileSize ?? 0)
        }
    }

    private static func deviceCapacityBytes() -> Int64 {
        let attributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
        return attributes?[.systemSize] as? Int64 ?? 0
    }

    private static func fallbackTitle(for subtype: PHAssetCollectionSubtype) -> String {
        switch subtype {
        case .smartAlbumUserLibrary: "Recents"
        case .smartAlbumFavorites: "Favorites"
        case .smartAlbumRecentlyAdded: "Recently Added"
        case .smartAlbumVideos: "Videos"
        case .smartAlbumLivePhotos: "Live Photos"
        case .smartAlbumScreenshots: "Screenshots"
        case .smartAlbumSelfPortraits: "Selfies"
        case .smartAlbumPanoramas: "Panoramas"
        case .smartAlbumBursts: "Bursts"
        case .smartAlbumDepthEffect: "Depth Effect"
        case .smartAlbumLongExposures: "Long Exposures"
        case .smartAlbumAnimated: "Animated"
        case .smartAlbumSlomoVideos: "Slo-mo"
        case .smartAlbumTimelapses: "Time-lapse"
        case .smartAlbumCinematic: "Cinematic"
        case .smartAlbumRAW: "RAW"
        case .smartAlbumUnableToUpload: "Unable to Upload"
        default: "Album"
        }
    }

    private static func normalizedTitle(_ title: String) -> String {
        title.replacingOccurrences(of: "Screen-shots", with: "Screenshots")
    }
}
