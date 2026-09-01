//
//  PhotoLibraryStore.swift
//  swipego
//
//  Created by apple on 8/31/26.
//

import Foundation
import AVFoundation
import Combine
import Photos
import PhotosUI
import UIKit

@MainActor
final class PhotoLibraryStore: ObservableObject {
    @Published var overview: AlbumOverview = .empty
    @Published var assets: [MediaAsset] = []
    @Published var swipeGroups: [SwipeGroup] = []
    @Published var systemAlbums: [SystemAlbumSummary] = []
    @Published var dailyStats = DailyCleanupStats()
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = PhotoLibraryService()
    private let statsStoreKey = "SwipeGoDailyCleanupStats.v1"

    init() {
        dailyStats = Self.loadStats(key: statsStoreKey)
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let snapshot = try await service.loadLibrary(browsedAssetIDs: dailyStats.browsedAssetIDs)
            overview = snapshot.overview
            assets = snapshot.assets
            swipeGroups = snapshot.groups
            systemAlbums = snapshot.systemAlbums
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func image(for asset: PHAsset, targetSize: CGSize) async -> UIImage? {
        await service.requestImage(for: asset, targetSize: targetSize)
    }

    func playerItem(for asset: PHAsset) async -> AVPlayerItem? {
        await service.requestPlayerItem(for: asset)
    }

    func livePhoto(for asset: PHAsset, targetSize: CGSize) async -> PHLivePhoto? {
        await service.requestLivePhoto(for: asset, targetSize: targetSize)
    }

    func followUpGroup(after kind: SwipeGroupKind) -> SwipeGroup? {
        service.followUpGroup(after: kind, from: assets, browsedAssetIDs: dailyStats.browsedAssetIDs)
    }

    func markBrowsed(_ mediaAsset: MediaAsset) {
        dailyStats.browsedByKind[mediaAsset.kind, default: 0] += 1
        dailyStats.browsedAssetIDs.insert(mediaAsset.id)
        dailyStats.activityByDay[Self.today, default: DailyCleanupActivity()].browsed += 1
        persistStats()
    }

    func delete(_ mediaAsset: MediaAsset) async {
        do {
            try await service.delete([mediaAsset])
            dailyStats.deletedByKind[mediaAsset.kind, default: 0] += 1
            dailyStats.savedBytesByKind[mediaAsset.kind, default: 0] += mediaAsset.bytes
            dailyStats.savedBytes += mediaAsset.bytes
            dailyStats.activityByDay[Self.today, default: DailyCleanupActivity()].deleted += 1
            dailyStats.activityByDay[Self.today, default: DailyCleanupActivity()].savedBytes += mediaAsset.bytes
            persistStats()
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ mediaAssets: [MediaAsset]) async -> Bool {
        do {
            try await service.delete(mediaAssets)
            for mediaAsset in mediaAssets {
                dailyStats.deletedByKind[mediaAsset.kind, default: 0] += 1
                dailyStats.savedBytesByKind[mediaAsset.kind, default: 0] += mediaAsset.bytes
                dailyStats.savedBytes += mediaAsset.bytes
                dailyStats.activityByDay[Self.today, default: DailyCleanupActivity()].deleted += 1
                dailyStats.activityByDay[Self.today, default: DailyCleanupActivity()].savedBytes += mediaAsset.bytes
            }
            persistStats()
            await load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    static var today: Date {
        Calendar.current.startOfDay(for: .now)
    }

    private func persistStats() {
        do {
            let data = try JSONEncoder().encode(dailyStats)
            UserDefaults.standard.set(data, forKey: statsStoreKey)
        } catch {
            errorMessage = "Unable to save cleanup stats."
        }
    }

    private static func loadStats(key: String) -> DailyCleanupStats {
        guard let data = UserDefaults.standard.data(forKey: key),
              let stats = try? JSONDecoder().decode(DailyCleanupStats.self, from: data) else {
            return DailyCleanupStats()
        }
        return stats
    }
}
