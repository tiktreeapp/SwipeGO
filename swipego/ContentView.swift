//
//  ContentView.swift
//  swipego
//
//  Created by apple on 8/31/26.
//

import SwiftUI
import AVKit
import Photos
import PhotosUI
import StoreKit
import UIKit

struct ContentView: View {
    @StateObject private var store = PhotoLibraryStore()
    @State private var didStart = false

    var body: some View {
        Group {
            if didStart {
                MainTabView()
                    .environmentObject(store)
            } else {
                LaunchView(didStart: $didStart)
                    .environmentObject(store)
            }
        }
        .tint(.swipeGreen)
        .task {
            await store.load()
        }
    }
}

private struct LaunchView: View {
    @EnvironmentObject private var store: PhotoLibraryStore
    @Binding var didStart: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.swipeMist, .white, Color.swipeGreen.opacity(0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer(minLength: 28)

                VStack(spacing: 16) {
                    LaunchIcon(size: 94)
                    VStack(spacing: 8) {
                        Text("SwipeGo")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                        Text("Clean Photos Smarter,\nRediscover Memories.")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }

                StorageOverviewPanel(overview: store.overview, isLoading: store.isLoading)
                    .padding(.horizontal, 20)

                if let errorMessage = store.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button {
                    didStart = true
                } label: {
                    Text("Start")
                        .font(.system(size: 21, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 28)

                Label("Cleanup locally. Privacy protected. Use with confidence.", systemImage: "lock.shield.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.swipeGreen)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 34)

                Spacer(minLength: 22)
            }
        }
    }
}

private struct MainTabView: View {
    var body: some View {
        TabView {
            SwipeView()
                .tabItem {
                    Label("SwipeGo", systemImage: "sparkles.rectangle.stack.fill")
                }

            CleanupView()
                .tabItem {
                    Label("Photos", systemImage: "photo.on.rectangle.angled")
                }

            MyView()
                .tabItem {
                    Label("My", systemImage: "person.crop.circle.fill")
                }
        }
        .background(.ultraThinMaterial)
    }
}

private struct SwipeView: View {
    @EnvironmentObject private var store: PhotoLibraryStore
    @State private var showIntentAlert = true
    @State private var path: [SwipeGroup] = []
    @State private var selectedDate = Date.now

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    SwipeHeader(selectedDate: $selectedDate)
                        .environmentObject(store)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 2), spacing: 14) {
                        ForEach(store.swipeGroups) { group in
                            Button {
                                path.append(group)
                            } label: {
                                SwipeGroupCard(group: group)
                            }
                            .buttonStyle(.plain)
                            .disabled(group.assets.isEmpty)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)

                    Text("Smart Groups. Easy Swipes. Rediscover Memories.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.swipeGreen.opacity(0.5))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
                .padding(.vertical, 20)
            }
            .navigationTitle("Swipe")
            .toolbar {
                Button {
                    Task { await store.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Refresh Library")
            }
            .navigationDestination(for: SwipeGroup.self) { group in
                SwipeDetailView(group: group, groups: store.swipeGroups, path: $path)
                    .environmentObject(store)
            }
        }
        .overlay {
            if showIntentAlert {
                CalmerNotice(isPresented: $showIntentAlert)
            }
        }
    }
}

private struct CalmerNotice: View {
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.24)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                Text("Calmer Notice")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, alignment: .center)

                Text("To reduce the pressure of cleaning up a large photo library,")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 10) {
                    Text("SwipeGo uses")
                        .font(.subheadline.weight(.semibold))

                    NoticeBullet("Smart groups, with no more than 16 photos in each set.")
                    NoticeBullet("Small batches from past days, kept together whenever possible.")
                    NoticeBullet("A trip, a reunion, or a meaningful memory appears at the right time.")
                }

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        isPresented = false
                    }
                } label: {
                    Text("Got it")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.top, 4)
            }
            .padding(22)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.horizontal, 28)
        }
        .transition(.opacity)
    }
}

private struct NoticeBullet: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
        }
        .font(.subheadline.bold())
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SwipeHeader: View {
    @EnvironmentObject private var store: PhotoLibraryStore
    @Binding var selectedDate: Date

    private var weekDates: [Date] {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: selectedDate)
        let daysFromMonday = (weekday + 5) % 7
        let start = calendar.date(byAdding: .day, value: -daysFromMonday, to: calendar.startOfDay(for: selectedDate)) ?? selectedDate
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private var todayActivity: DailyCleanupActivity {
        store.dailyStats.activityByDay[Calendar.current.startOfDay(for: selectedDate)] ?? DailyCleanupActivity()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Text(selectedDate.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.system(size: 16, weight: .bold, design: .rounded))

                Spacer()

                HeaderMetric(icon: "eye.fill", value: "\(todayActivity.browsed)", color: .primary)
                HeaderMetric(icon: "trash.fill", value: "\(todayActivity.deleted)", color: .red)
                HeaderMetric(icon: "internaldrive.fill", value: todayActivity.savedBytes.storageDisplay, color: Color.swipeGreen)
            }

            HStack(spacing: 6) {
                ForEach(weekDates, id: \.self) { date in
                    let day = Calendar.current.startOfDay(for: date)
                    let activity = store.dailyStats.activityByDay[day]
                    WeekDayButton(
                        date: date,
                        isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                        hasCleanupActivity: (activity?.deleted ?? 0) > 0 || (activity?.savedBytes ?? 0) > 0
                    ) {
                        selectedDate = date
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}

private struct HeaderMetric: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        Label(value, systemImage: icon)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }
}

private struct WeekDayButton: View {
    let date: Date
    let isSelected: Bool
    let hasCleanupActivity: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(date.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.system(size: 9, weight: .semibold))
                Text(date.formatted(.dateTime.day()))
                    .font(.caption.weight(.bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? Color.swipeGreen.opacity(0.25) : Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .foregroundStyle(hasCleanupActivity ? Color.swipeGreen : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

private struct SwipeGroupCard: View {
    @EnvironmentObject private var store: PhotoLibraryStore
    let group: SwipeGroup
    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CoverFrame(image: image, fallbackIcon: group.kind.iconName)

            VStack(alignment: .leading, spacing: 6) {
                Text(group.title)
                    .font(.headline)
                    .shadow(color: .black.opacity(0.75), radius: 4, x: 0, y: 2)
                Text("\(group.assets.count) items")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.82))
                    .shadow(color: .black.opacity(0.72), radius: 3, x: 0, y: 1)
            }
            .foregroundStyle(.white)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [.black.opacity(0), .black.opacity(0.62)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .task(id: group.coverAsset?.id) {
            guard let asset = group.coverAsset?.asset else { return }
            image = await store.image(for: asset, targetSize: CGSize(width: 520, height: 700))
        }
    }
}

private struct SwipeDetailView: View {
    @EnvironmentObject private var store: PhotoLibraryStore
    let group: SwipeGroup
    let groups: [SwipeGroup]
    @Binding var path: [SwipeGroup]
    @State private var index = 0
    @State private var dragOffset = CGSize.zero
    @State private var queuedDeletes: [MediaAsset] = []
    @State private var sessionBrowsed = 0
    @State private var summary: SwipeSessionSummary?
    @State private var isFinishing = false
    @State private var entryOffset = CGSize.zero
    @State private var showDeleteRecoveryNotice = false
    @State private var followUpGroup: SwipeGroup?
    @Environment(\.requestReview) private var requestReview

    private var current: MediaAsset? {
        guard group.assets.indices.contains(index) else { return nil }
        return group.assets[index]
    }

    private var dragIntent: SwipeIntent? {
        if dragOffset.height < -34 && abs(dragOffset.height) > abs(dragOffset.width) {
            return .delete
        }
        if dragOffset.width < -34 {
            return .skip
        }
        if dragOffset.width > 34 {
            return .favorite
        }
        return nil
    }

    var body: some View {
        ZStack {
            DetailPhotoBackground()
                .ignoresSafeArea()

            if let current {
                SwipeAssetCard(mediaAsset: current, dragOffset: dragOffset + entryOffset)
                    .id(current.id)
                    .overlay {
                        if let dragIntent {
                            SwipeIntentBadge(intent: dragIntent)
                                .transition(.scale(scale: 0.92).combined(with: .opacity))
                        }
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.86)) {
                                    dragOffset = value.translation
                                }
                            }
                            .onEnded { value in handleSwipe(value.translation, asset: current) }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .padding(.top, 48)
            } else {
                VStack(spacing: 16) {
                    if isFinishing {
                        ProgressView()
                            .controlSize(.large)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(Color.swipeGreen)
                        Text("All Done")
                            .font(.title2.bold())
                            .foregroundStyle(.primary)

                        if let followUpGroup {
                            Button {
                                path = [followUpGroup]
                            } label: {
                                Label("Next Group", systemImage: "arrow.right.circle.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                            }
                            .buttonStyle(.borderedProminent)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .padding(.horizontal, 28)
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            DetailTopBar(title: group.title, progress: "\(min(index + 1, group.assets.count))/\(group.assets.count)") {
                requestReviewAfterFirstOrThirdGroupIfNeeded()
                path.removeAll()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task(id: index) {
            if index >= group.assets.count {
                await finishGroupIfNeeded()
            }
        }
        .alert("Recoverable After Delete", isPresented: $showDeleteRecoveryNotice) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text("After you confirm deletion later, you can still recover it in Photos > Recently Deleted.")
        }
        .overlay {
            if let summary {
                SessionSummaryDialog(summary: summary) {
                    self.summary = nil
                }
            }
        }
    }

    private func handleSwipe(_ translation: CGSize, asset: MediaAsset) {
        if translation.height < -120 && abs(translation.height) > abs(translation.width) {
            queueDelete(asset, exitOffset: CGSize(width: 0, height: -900), entryOffset: CGSize(width: 0, height: 900))
        } else if translation.width > 120 {
            store.markBrowsed(asset)
            sessionBrowsed += 1
            completeSwipe(exitOffset: CGSize(width: 700, height: 0), entryOffset: CGSize(width: -700, height: 0))
        } else if translation.width < -120 {
            store.markBrowsed(asset)
            sessionBrowsed += 1
            completeSwipe(exitOffset: CGSize(width: -700, height: 0), entryOffset: CGSize(width: 700, height: 0))
        } else {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                dragOffset = .zero
            }
        }
    }

    private func queueDelete(_ asset: MediaAsset, exitOffset: CGSize, entryOffset: CGSize) {
        store.markBrowsed(asset)
        sessionBrowsed += 1
        if !queuedDeletes.contains(asset) {
            queuedDeletes.append(asset)
        }
        if shouldShowDeleteRecoveryNotice() {
            showDeleteRecoveryNotice = true
        }
        completeSwipe(exitOffset: exitOffset, entryOffset: entryOffset)
    }

    private func completeSwipe(exitOffset: CGSize, entryOffset nextEntryOffset: CGSize) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        withAnimation(.easeOut(duration: 0.18)) {
            dragOffset = exitOffset
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            entryOffset = nextEntryOffset
            dragOffset = .zero
            index += 1

            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    entryOffset = .zero
                }
            }
        }
    }

    private func shouldShowDeleteRecoveryNotice() -> Bool {
        let key = "SwipeGoDeleteRecoveryNotice-\(Date.now.formatted(.iso8601.year().month().day()))"
        guard !UserDefaults.standard.bool(forKey: key) else { return false }
        UserDefaults.standard.set(true, forKey: key)
        return true
    }

    private func finishGroupIfNeeded() async {
        guard !isFinishing, summary == nil else { return }
        isFinishing = true

        let deletedAssets = queuedDeletes
        let savedBytes = deletedAssets.map(\.bytes).reduce(0, +)
        if deletedAssets.isEmpty {
            summary = SwipeSessionSummary(browsed: sessionBrowsed, deleted: 0, savedBytes: 0)
        } else {
            let didDelete = await store.delete(deletedAssets)
            summary = SwipeSessionSummary(
                browsed: sessionBrowsed,
                deleted: didDelete ? deletedAssets.count : 0,
                savedBytes: didDelete ? savedBytes : 0
            )
        }

        followUpGroup = store.followUpGroup(after: group.kind)
        isFinishing = false
    }

    private func requestReviewAfterFirstOrThirdGroupIfNeeded() {
        guard index >= group.assets.count,
              let groupIndex = groups.firstIndex(of: group),
              groupIndex == 0 || groupIndex == 2 else { return }

        let key = "SwipeGoReviewPromptAfterGroup-\(groupIndex + 1)"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        requestReview()
    }
}

private struct DetailPhotoBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(.systemGroupedBackground),
                Color.swipeMist.opacity(0.62),
                Color(.secondarySystemGroupedBackground)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct DominantPreviewBackground: View {
    let image: UIImage?

    var body: some View {
        ZStack {
            Color(.secondarySystemGroupedBackground)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 375)
                    .blur(radius: 32)
                    .opacity(0.92)
            }
        }
        .clipped()
    }
}

private enum SwipeIntent {
    case skip
    case favorite
    case delete

    var title: String {
        switch self {
        case .skip: "Left Swipe to Skip"
        case .favorite: "Right Swipe to Favorite"
        case .delete: "Up Swipe to Delete"
        }
    }

    var iconName: String {
        switch self {
        case .skip: "arrow.left"
        case .favorite: "heart.fill"
        case .delete: "trash.fill"
        }
    }

    var color: Color {
        switch self {
        case .skip: Color.swipeGreen
        case .favorite: Color.swipeGreen
        case .delete: .red
        }
    }
}

private struct SwipeIntentBadge: View {
    let intent: SwipeIntent

    var body: some View {
        Label(intent.title, systemImage: intent.iconName)
            .font(.subheadline.bold())
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(intent.color.opacity(0.14), in: Capsule())
            .foregroundStyle(intent.color)
    }
}

private struct SwipeSessionSummary: Identifiable {
    let id = UUID()
    let browsed: Int
    let deleted: Int
    let savedBytes: Int64
}

private struct DetailTopBar: View {
    let title: String
    let progress: String
    let backAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: backAction) {
                Label("Swipe", systemImage: "chevron.left")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.plain)

            Spacer()

            Label(title, systemImage: "rectangle.stack.fill")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            Spacer()

            Text(progress)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(minWidth: 44, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 0.5)
        }
    }
}

private struct SessionSummaryDialog: View {
    let summary: SwipeSessionSummary
    let close: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.24)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Summary")
                    .font(.title3.bold())

                VStack(alignment: .leading, spacing: 10) {
                    Text("Browsed: \(summary.browsed)")
                    Text("Deleted: \(summary.deleted)")
                    Text("Storage Saved: \(summary.savedBytes.storageDisplay)")
                        .fontWeight(.bold)
                }
                .font(.system(size: 15, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: close) {
                    Text("Done")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(22)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.horizontal, 32)
        }
    }
}

private struct SwipeAssetCard: View {
    @EnvironmentObject private var store: PhotoLibraryStore
    let mediaAsset: MediaAsset
    let dragOffset: CGSize
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { proxy in
            let cardWidth = min(proxy.size.width, 430)
            VStack(spacing: 14) {
                ZStack {
                    DominantPreviewBackground(image: image)

                    MediaPreview(mediaAsset: mediaAsset, image: image)
                        .frame(width: cardWidth, height: cardWidth * 4 / 3)
                }
                .frame(width: cardWidth, height: cardWidth * 4 / 3)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 18, y: 8)

                AssetInfoBar(mediaAsset: mediaAsset)
                    .frame(width: cardWidth)
            }
            .frame(width: cardWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .scaleEffect(1 - min(abs(dragOffset.width) / 2800, 0.035))
        .rotationEffect(.degrees(Double(dragOffset.width / 28)))
        .offset(dragOffset)
        .task(id: mediaAsset.id) {
            image = await store.image(for: mediaAsset.asset, targetSize: CGSize(width: 1100, height: 1400))
        }
    }
}

private struct MediaPreview: View {
    let mediaAsset: MediaAsset
    let image: UIImage?

    var body: some View {
        switch mediaAsset.kind {
        case .videos:
            VideoPreview(mediaAsset: mediaAsset, placeholder: image)
        case .livePhotos:
            LivePhotoPreview(mediaAsset: mediaAsset, placeholder: image)
        case .photos, .screenshots:
            PhotoPreview(image: image)
        }
    }
}

private struct PhotoPreview: View {
    let image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}

private struct VideoPreview: View {
    @EnvironmentObject private var store: PhotoLibraryStore
    let mediaAsset: MediaAsset
    let placeholder: UIImage?
    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                PhotoPreview(image: placeholder)
                    .overlay {
                        ProgressView()
                            .controlSize(.large)
                    }
            }
        }
        .task(id: mediaAsset.id) {
            if let item = await store.playerItem(for: mediaAsset.asset) {
                let player = AVPlayer(playerItem: item)
                self.player = player
                player.play()
            }
        }
        .onDisappear {
            player?.pause()
        }
    }
}

private struct LivePhotoPreview: View {
    @EnvironmentObject private var store: PhotoLibraryStore
    let mediaAsset: MediaAsset
    let placeholder: UIImage?
    @State private var livePhoto: PHLivePhoto?

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let livePhoto {
                LivePhotoPlayer(livePhoto: livePhoto)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                PhotoPreview(image: placeholder)
            }

            Label("LIVE", systemImage: "livephoto")
                .font(.caption2.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .padding()
        }
        .task(id: mediaAsset.id) {
            livePhoto = await store.livePhoto(for: mediaAsset.asset, targetSize: CGSize(width: 1100, height: 1400))
        }
    }
}

private struct LivePhotoPlayer: UIViewRepresentable {
    let livePhoto: PHLivePhoto

    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.contentMode = .scaleAspectFit
        view.livePhoto = livePhoto
        view.startPlayback(with: .full)
        return view
    }

    func updateUIView(_ uiView: PHLivePhotoView, context: Context) {
        uiView.livePhoto = livePhoto
        uiView.startPlayback(with: .full)
    }
}

private struct AssetInfoBar: View {
    let mediaAsset: MediaAsset

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            InfoLine(icon: "calendar", title: "Time", value: mediaAsset.creationDate?.formatted(date: .abbreviated, time: .shortened) ?? "Unknown")
            InfoLine(icon: "location.fill", title: "Location", value: mediaAsset.locationText)
            InfoLine(icon: "internaldrive.fill", title: "Size", value: ByteCountFormatter.storage.string(fromByteCount: mediaAsset.bytes))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct InfoLine: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.swipeGreen)
                .frame(width: 18)
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
        .font(.footnote)
    }
}

private struct CleanupView: View {
    @EnvironmentObject private var store: PhotoLibraryStore
    @State private var selectedMode: CleanupMode = .time
    @State private var selectedYear: Int? = Calendar.current.component(.year, from: .now)
    @State private var selectedMonth: Int?
    @State private var selectedSystemAlbum: SystemAlbumSummary?
    @State private var path: [SwipeGroup] = []

    private var years: [Int] {
        Array(Set(store.assets.compactMap { asset in
            asset.creationDate.map { Calendar.current.component(.year, from: $0) }
        })).sorted(by: >)
    }

    private var filteredAssets: [MediaAsset] {
        store.assets.filter { asset in
            switch selectedMode {
            case .time:
                guard let date = asset.creationDate else { return false }
                let yearMatches = selectedYear == nil || Calendar.current.component(.year, from: date) == selectedYear
                let monthMatches = selectedMonth == nil || Calendar.current.component(.month, from: date) == selectedMonth
                return yearMatches && monthMatches
            case .mediaType:
                guard let selectedSystemAlbum else { return true }
                return selectedSystemAlbum.assetIDs.contains(asset.id)
            }
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 12) {
                Picker("Cleanup Mode", selection: $selectedMode) {
                    ForEach(CleanupMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if selectedMode == .time {
                    TimeFilters(years: years, selectedYear: $selectedYear, selectedMonth: $selectedMonth)
                } else {
                    MediaTypeFilters(albums: store.systemAlbums, selectedAlbum: $selectedSystemAlbum)
                }

                AssetGrid(assets: filteredAssets) { asset in
                    path = [detailGroup(startingAt: asset)]
                }
            }
            .navigationTitle("Photos")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: SwipeGroup.self) { group in
                SwipeDetailView(group: group, groups: [], path: $path)
                    .environmentObject(store)
            }
        }
    }

    private func detailGroup(startingAt asset: MediaAsset) -> SwipeGroup {
        let remaining = filteredAssets.filter { $0.id != asset.id }
        return SwipeGroup(kind: .random, title: detailTitle, assets: [asset] + remaining)
    }

    private var detailTitle: String {
        switch selectedMode {
        case .time:
            if let selectedYear, let selectedMonth {
                let monthName = DateFormatter().shortMonthSymbols[safe: selectedMonth - 1] ?? "\(selectedMonth)"
                return "\(monthName) \(selectedYear)"
            }
            if let selectedYear {
                return "\(selectedYear)"
            }
            return "Photos"
        case .mediaType:
            return selectedSystemAlbum?.title ?? "Photos"
        }
    }
}

private enum CleanupMode: String, CaseIterable, Identifiable {
    case time = "Time"
    case mediaType = "Media Type"

    var id: String { rawValue }
}

private struct TimeFilters: View {
    let years: [Int]
    @Binding var selectedYear: Int?
    @Binding var selectedMonth: Int?
    private let monthSymbols = DateFormatter().shortMonthSymbols ?? []
    private let currentYear = Calendar.current.component(.year, from: .now)
    private let currentMonth = Calendar.current.component(.month, from: .now)

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", isSelected: selectedYear == nil) {
                    selectedYear = nil
                    selectedMonth = nil
                }
                ForEach(years, id: \.self) { year in
                    FilterChip(title: "\(year)", isSelected: selectedYear == year) {
                        selectedYear = year
                    }
                }
            }
            .padding(.horizontal)
        }

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", isSelected: selectedMonth == nil) {
                    selectedMonth = nil
                }
                ForEach(1...12, id: \.self) { month in
                    let isFutureMonth = selectedYear == currentYear && month > currentMonth
                    FilterChip(title: monthSymbols[safe: month - 1] ?? "\(month)", isSelected: selectedMonth == month, isEnabled: !isFutureMonth) {
                        selectedMonth = month
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

private struct MediaTypeFilters: View {
    let albums: [SystemAlbumSummary]
    @Binding var selectedAlbum: SystemAlbumSummary?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", isSelected: selectedAlbum == nil) {
                    selectedAlbum = nil
                }
                ForEach(albums) { album in
                    FilterChip(title: album.title, isSelected: selectedAlbum == album) {
                        selectedAlbum = album
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

private struct AssetGrid: View {
    let assets: [MediaAsset]
    let onSelect: (MediaAsset) -> Void
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(assets) { asset in
                    Button {
                        onSelect(asset)
                    } label: {
                        SquareThumb(mediaAsset: asset)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct SquareThumb: View {
    @EnvironmentObject private var store: PhotoLibraryStore
    let mediaAsset: MediaAsset
    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(.gray.opacity(0.18))
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipped()

            if mediaAsset.kind == .videos {
                Image(systemName: "play.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(6)
            }
        }
        .task(id: mediaAsset.id) {
            image = await store.image(for: mediaAsset.asset, targetSize: CGSize(width: 360, height: 360))
        }
    }
}

private struct MyView: View {
    @EnvironmentObject private var store: PhotoLibraryStore
    @Environment(\.requestReview) private var requestReview
    @AppStorage("SwipeGoLastPromptedSavedMilestone") private var lastPromptedSavedMilestone = 0
    @State private var pendingSavedMilestone = 0
    @State private var showSavedMilestone = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    ShareReviewPanel(stats: store.dailyStats)
                    SummaryPanel(stats: store.dailyStats)
                    StorageOverviewPanel(overview: store.overview, isLoading: store.isLoading)
                }
                .padding()
            }
            .navigationTitle("My")
            .refreshable {
                await store.load()
            }
            .onAppear(perform: evaluateSavedMilestone)
            .onChange(of: store.dailyStats.savedBytes) { _, _ in
                evaluateSavedMilestone()
            }
            .alert("New Milestone", isPresented: $showSavedMilestone) {
                Button("Great") {
                    lastPromptedSavedMilestone = pendingSavedMilestone
                    requestReview()
                }
            } message: {
                Text("Congratulations! You've cleaned \(milestoneSavedText) with SwipeGo.")
            }
        }
    }

    private var milestoneSavedText: String {
        (Int64(pendingSavedMilestone) * 100.megabytes).storageDisplay
    }

    private func evaluateSavedMilestone() {
        let milestone = Int(store.dailyStats.savedBytes / 100.megabytes)
        guard milestone > 0, milestone > lastPromptedSavedMilestone else { return }
        pendingSavedMilestone = milestone
        showSavedMilestone = true
    }
}

private struct ShareReviewPanel: View {
    let stats: DailyCleanupStats
    private static let reviewURL = URL(string: "https://apps.apple.com/us/app/id6806951126?action=write-review")!
    private static let shareText = "Clean Photos Smarter, Rediscover Memories. by SwipeGo https://apps.apple.com/us/app/id6806951126"
    @State private var sharePayload: SharePayload?

    var body: some View {
        HStack(spacing: 12) {
            Button {
                sharePayload = makeSharePayload()
            } label: {
                QuickActionModule(title: "Share", icon: "square.and.arrow.up.fill")
            }
            .buttonStyle(.plain)

            Button {
                UIApplication.shared.open(Self.reviewURL)
            } label: {
                QuickActionModule(title: "Review", icon: "star.bubble.fill")
            }
            .buttonStyle(.plain)
        }
        .sheet(item: $sharePayload) { payload in
            ActivityShareSheet(items: payload.items)
        }
    }

    @MainActor
    private func makeSharePayload() -> SharePayload {
        var items: [Any] = []
        let renderer = ImageRenderer(
            content: SummaryShareSnapshot(stats: stats)
                .frame(width: 375)
                .background(Color(.systemBackground))
        )
        renderer.scale = UIScreen.main.scale

        if let image = renderer.uiImage {
            items.append(image)
        }
        items.append(Self.shareText)
        return SharePayload(items: items)
    }
}

private struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

private struct QuickActionModule: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.swipeGreen)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.swipeGreen.opacity(0.16), lineWidth: 1)
        }
    }
}

private struct SummaryShareSnapshot: View {
    let stats: DailyCleanupStats
    private let kinds: [MediaKind] = [.videos, .photos, .screenshots]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                LaunchIcon(size: 48)
                VStack(alignment: .leading, spacing: 4) {
                    Text("SwipeGo")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("Clean Photos Smarter, Rediscover Memories.")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                Text("Summary")
                    .font(.headline)

                HStack(alignment: .top, spacing: 14) {
                    SummaryMetric(title: "Viewed", icon: "eye.fill", value: "\(summaryBrowsed)", color: .primary)
                    SummaryMetric(title: "Deleted", icon: "trash.fill", value: "\(summaryDeleted)", color: .red)
                    SummaryMetric(title: "Cleaned", icon: "sparkles", value: summarySaved.storageDisplay, color: Color.swipeGreen)
                }

                ForEach(kinds) { kind in
                    SummaryCategoryBlock(
                        title: kind.rawValue,
                        icon: kind.iconName,
                        viewed: stats.browsedByKind[kind, default: 0],
                        deleted: stats.deletedByKind[kind, default: 0],
                        savedBytes: stats.savedBytesByKind[kind, default: 0]
                    )
                }
            }
            .padding(18)
            .background(Color.swipeMist.opacity(0.8), in: RoundedRectangle(cornerRadius: 22, style: .continuous))

            Text("https://apps.apple.com/us/app/id6806951126")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.swipeGreen)
        }
        .padding(18)
    }

    private var summaryBrowsed: Int {
        kinds.map { stats.browsedByKind[$0, default: 0] }.reduce(0, +)
    }

    private var summaryDeleted: Int {
        kinds.map { stats.deletedByKind[$0, default: 0] }.reduce(0, +)
    }

    private var summarySaved: Int64 {
        kinds.map { stats.savedBytesByKind[$0, default: 0] }.reduce(0, +)
    }
}

private struct SummaryPanel: View {
    let stats: DailyCleanupStats
    private let kinds: [MediaKind] = [.videos, .photos, .screenshots]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Summary")
                .font(.headline)

            HStack(alignment: .top, spacing: 14) {
                SummaryMetric(title: "Viewed", icon: "eye.fill", value: "\(summaryBrowsed)", color: .primary)
                SummaryMetric(title: "Deleted", icon: "trash.fill", value: "\(summaryDeleted)", color: .red)
                SummaryMetric(title: "Cleaned", icon: "sparkles", value: summarySaved.storageDisplay, color: Color.swipeGreen)
            }

            ForEach(kinds) { kind in
                SummaryCategoryBlock(
                    title: kind.rawValue,
                    icon: kind.iconName,
                    viewed: stats.browsedByKind[kind, default: 0],
                    deleted: stats.deletedByKind[kind, default: 0],
                    savedBytes: stats.savedBytesByKind[kind, default: 0]
                )
            }
        }
        .panelStyle()
    }

    private var summaryBrowsed: Int {
        kinds.map { stats.browsedByKind[$0, default: 0] }.reduce(0, +)
    }

    private var summaryDeleted: Int {
        kinds.map { stats.deletedByKind[$0, default: 0] }.reduce(0, +)
    }

    private var summarySaved: Int64 {
        kinds.map { stats.savedBytesByKind[$0, default: 0] }.reduce(0, +)
    }
}

private struct SummaryCategoryBlock: View {
    let title: String
    let icon: String
    let viewed: Int
    let deleted: Int
    let savedBytes: Int64

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))

            HStack(alignment: .top, spacing: 14) {
                SummaryMetric(title: "Viewed", icon: "eye.fill", value: "\(viewed)", color: .primary)
                SummaryMetric(title: "Deleted", icon: "trash.fill", value: "\(deleted)", color: .red)
                SummaryMetric(title: "Cleaned", icon: "sparkles", value: savedBytes.storageDisplay, color: Color.swipeGreen)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct SummaryMetric: View {
    let title: String
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StorageOverviewPanel: View {
    let overview: AlbumOverview
    let isLoading: Bool
    private let barHeight: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Photos on Device")
                        .font(.headline)
                    Text("\(ByteCountFormatter.storage.string(fromByteCount: overview.usedBytes))/\(ByteCountFormatter.storage.string(fromByteCount: overview.deviceBytes))")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.75)
                }

                Spacer()

                if isLoading {
                    ProgressView()
                }
            }

            StorageUsageBar(categories: overview.topCategories, height: barHeight)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 10) {
                ForEach(overview.topCategories) { item in
                    CategorySummaryView(summary: item)
                }
            }
        }
        .panelStyle()
    }
}

private struct CategorySummaryView: View {
    let summary: MediaCategorySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(summary.kind.rawValue, systemImage: summary.kind.iconName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(summary.kind.categoryColor)
            Text("\(summary.count) items · \(ByteCountFormatter.storage.string(fromByteCount: summary.bytes))")
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StorageUsageBar: View {
    let categories: [MediaCategorySummary]
    let height: CGFloat

    private var totalBytes: Int64 {
        max(categories.map(\.bytes).reduce(0, +), 1)
    }

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 2) {
                ForEach(categories) { item in
                    Rectangle()
                        .fill(item.kind.categoryColor)
                        .frame(width: max(proxy.size.width * CGFloat(item.bytes) / CGFloat(totalBytes), item.bytes > 0 ? 8 : 0))
                }
            }
        }
        .frame(height: height)
        .clipShape(Capsule())
    }
}

private struct StatRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(isSelected ? Color.swipeGreen : Color.gray.opacity(0.14), in: Capsule())
                .foregroundStyle(isSelected ? .white : (isEnabled ? .primary : .secondary.opacity(0.55)))
        }
        .disabled(!isEnabled)
    }
}

private struct CoverFrame: View {
    let image: UIImage?
    let fallbackIcon: String

    var body: some View {
        GeometryReader { proxy in
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Color.swipeGreen.opacity(0.14))
                        .overlay {
                            Image(systemName: fallbackIcon)
                                .font(.system(size: 34, weight: .semibold))
                                .foregroundStyle(Color.swipeGreen)
                        }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .aspectRatio(3 / 4, contentMode: .fit)
    }
}

private struct LaunchIcon: View {
    let size: CGFloat

    var body: some View {
        Image("LaunchIcon")
            .resizable()
            .scaledToFill()
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        .shadow(color: Color.swipeGreen.opacity(0.32), radius: 24, y: 12)
    }
}

private extension View {
    func panelStyle() -> some View {
        self
            .padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(0.55), lineWidth: 1)
            }
    }
}

private extension Color {
    static let swipeGreen = Color(red: 2 / 255, green: 167 / 255, blue: 91 / 255)
    static let swipeMist = Color(red: 0.88, green: 0.98, blue: 0.93)
}

private extension MediaAsset {
    var locationText: String {
        guard let coordinate = location?.coordinate else {
            return "Unknown"
        }
        if let place = OfflineLocationResolver.placeName(for: coordinate) {
            return place
        }
        return String(format: "Lat %.4f, Lon %.4f", coordinate.latitude, coordinate.longitude)
    }
}

private enum OfflineLocationResolver {
    private struct Place {
        let name: String
        let latitude: Double
        let longitude: Double
        let radiusKilometers: Double
    }

    private static let places: [Place] = [
        Place(name: "The Forbidden City", latitude: 39.9163, longitude: 116.3972, radiusKilometers: 3),
        Place(name: "Temple of Heaven", latitude: 39.8822, longitude: 116.4066, radiusKilometers: 3),
        Place(name: "Beijing Chaoyang District", latitude: 39.9219, longitude: 116.4436, radiusKilometers: 12),
        Place(name: "Beijing Haidian District", latitude: 39.9599, longitude: 116.2981, radiusKilometers: 12),
        Place(name: "Beijing Dongcheng District", latitude: 39.9289, longitude: 116.4164, radiusKilometers: 6),
        Place(name: "Beijing Xicheng District", latitude: 39.9123, longitude: 116.3659, radiusKilometers: 6),
        Place(name: "The Bund", latitude: 31.2403, longitude: 121.4906, radiusKilometers: 3),
        Place(name: "People's Square", latitude: 31.2304, longitude: 121.4737, radiusKilometers: 2),
        Place(name: "Lujiazui", latitude: 31.2387, longitude: 121.5056, radiusKilometers: 3),
        Place(name: "Shanghai Disneyland", latitude: 31.1440, longitude: 121.6570, radiusKilometers: 5),
        Place(name: "Shanghai Huangpu District", latitude: 31.2316, longitude: 121.4845, radiusKilometers: 6),
        Place(name: "Shanghai Pudong New Area", latitude: 31.2215, longitude: 121.5441, radiusKilometers: 18),
        Place(name: "Shanghai Xuhui District", latitude: 31.1885, longitude: 121.4368, radiusKilometers: 8),
        Place(name: "Shanghai Jing'an District", latitude: 31.2278, longitude: 121.4470, radiusKilometers: 6),
        Place(name: "West Lake", latitude: 30.2431, longitude: 120.1500, radiusKilometers: 5),
        Place(name: "Hangzhou Xihu District", latitude: 30.2596, longitude: 120.1303, radiusKilometers: 9),
        Place(name: "Hangzhou Shangcheng District", latitude: 30.2425, longitude: 120.1699, radiusKilometers: 7),
        Place(name: "Canton Tower", latitude: 23.1090, longitude: 113.3190, radiusKilometers: 3),
        Place(name: "Guangzhou Tianhe District", latitude: 23.1246, longitude: 113.3612, radiusKilometers: 10),
        Place(name: "Guangzhou Yuexiu District", latitude: 23.1290, longitude: 113.2670, radiusKilometers: 6),
        Place(name: "Guangzhou Haizhu District", latitude: 23.0840, longitude: 113.3172, radiusKilometers: 9),
        Place(name: "Window of the World", latitude: 22.5365, longitude: 113.9730, radiusKilometers: 3),
        Place(name: "Shenzhen Nanshan District", latitude: 22.5333, longitude: 113.9304, radiusKilometers: 10),
        Place(name: "Shenzhen Futian District", latitude: 22.5215, longitude: 114.0559, radiusKilometers: 8),
        Place(name: "Shenzhen Luohu District", latitude: 22.5484, longitude: 114.1316, radiusKilometers: 7),
        Place(name: "Chengdu Research Base of Giant Panda Breeding", latitude: 30.7346, longitude: 104.1456, radiusKilometers: 4),
        Place(name: "Chengdu Jinjiang District", latitude: 30.6570, longitude: 104.0834, radiusKilometers: 8),
        Place(name: "Chengdu Wuhou District", latitude: 30.6424, longitude: 104.0434, radiusKilometers: 9),
        Place(name: "Terracotta Army", latitude: 34.3841, longitude: 109.2785, radiusKilometers: 5),
        Place(name: "Xi'an Yanta District", latitude: 34.2134, longitude: 108.9480, radiusKilometers: 9),
        Place(name: "Xi'an Beilin District", latitude: 34.2567, longitude: 108.9343, radiusKilometers: 6),
        Place(name: "Hong Kong Disneyland", latitude: 22.3130, longitude: 114.0413, radiusKilometers: 4),
        Place(name: "Victoria Harbour", latitude: 22.2930, longitude: 114.1694, radiusKilometers: 5),
        Place(name: "Hong Kong Central", latitude: 22.2819, longitude: 114.1581, radiusKilometers: 3),
        Place(name: "Tsim Sha Tsui", latitude: 22.2988, longitude: 114.1722, radiusKilometers: 3),
        Place(name: "Taipei 101", latitude: 25.0339, longitude: 121.5645, radiusKilometers: 3),
        Place(name: "Taipei Xinyi District", latitude: 25.0330, longitude: 121.5668, radiusKilometers: 5),
        Place(name: "Tokyo Disneyland", latitude: 35.6329, longitude: 139.8804, radiusKilometers: 4),
        Place(name: "Shibuya Crossing", latitude: 35.6595, longitude: 139.7005, radiusKilometers: 2),
        Place(name: "Eiffel Tower", latitude: 48.8584, longitude: 2.2945, radiusKilometers: 3),
        Place(name: "Louvre Museum", latitude: 48.8606, longitude: 2.3376, radiusKilometers: 3),
        Place(name: "Tower Bridge", latitude: 51.5055, longitude: -0.0754, radiusKilometers: 3),
        Place(name: "Times Square", latitude: 40.7580, longitude: -73.9855, radiusKilometers: 3),
        Place(name: "Central Park", latitude: 40.7829, longitude: -73.9654, radiusKilometers: 5),
        Place(name: "Golden Gate Bridge", latitude: 37.8199, longitude: -122.4783, radiusKilometers: 4),
        Place(name: "Burj Khalifa", latitude: 25.1972, longitude: 55.2744, radiusKilometers: 3),
        Place(name: "Beijing", latitude: 39.9042, longitude: 116.4074, radiusKilometers: 55),
        Place(name: "Shanghai", latitude: 31.2304, longitude: 121.4737, radiusKilometers: 55),
        Place(name: "Guangzhou", latitude: 23.1291, longitude: 113.2644, radiusKilometers: 45),
        Place(name: "Shenzhen", latitude: 22.5431, longitude: 114.0579, radiusKilometers: 45),
        Place(name: "Hangzhou", latitude: 30.2741, longitude: 120.1551, radiusKilometers: 42),
        Place(name: "Chengdu", latitude: 30.5728, longitude: 104.0668, radiusKilometers: 50),
        Place(name: "Xi'an", latitude: 34.3416, longitude: 108.9398, radiusKilometers: 42),
        Place(name: "Nanjing", latitude: 32.0603, longitude: 118.7969, radiusKilometers: 40),
        Place(name: "Wuhan", latitude: 30.5928, longitude: 114.3055, radiusKilometers: 45),
        Place(name: "Chongqing", latitude: 29.5630, longitude: 106.5516, radiusKilometers: 55),
        Place(name: "Hong Kong", latitude: 22.3193, longitude: 114.1694, radiusKilometers: 35),
        Place(name: "Macau", latitude: 22.1987, longitude: 113.5439, radiusKilometers: 16),
        Place(name: "Taipei", latitude: 25.0330, longitude: 121.5654, radiusKilometers: 35),
        Place(name: "Tokyo", latitude: 35.6762, longitude: 139.6503, radiusKilometers: 45),
        Place(name: "Osaka", latitude: 34.6937, longitude: 135.5023, radiusKilometers: 35),
        Place(name: "Seoul", latitude: 37.5665, longitude: 126.9780, radiusKilometers: 45),
        Place(name: "Singapore", latitude: 1.3521, longitude: 103.8198, radiusKilometers: 28),
        Place(name: "Bangkok", latitude: 13.7563, longitude: 100.5018, radiusKilometers: 45),
        Place(name: "Paris", latitude: 48.8566, longitude: 2.3522, radiusKilometers: 35),
        Place(name: "London", latitude: 51.5072, longitude: -0.1276, radiusKilometers: 40),
        Place(name: "New York", latitude: 40.7128, longitude: -74.0060, radiusKilometers: 45),
        Place(name: "Los Angeles", latitude: 34.0522, longitude: -118.2437, radiusKilometers: 55),
        Place(name: "San Francisco", latitude: 37.7749, longitude: -122.4194, radiusKilometers: 35),
        Place(name: "Dubai", latitude: 25.2048, longitude: 55.2708, radiusKilometers: 45)
    ]

    static func placeName(for coordinate: CLLocationCoordinate2D) -> String? {
        let current = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var bestPlace: Place?
        var bestDistance = Double.greatestFiniteMagnitude

        for place in places {
            let location = CLLocation(latitude: place.latitude, longitude: place.longitude)
            let distance = current.distance(from: location) / 1000
            if distance < bestDistance {
                bestPlace = place
                bestDistance = distance
            }
        }

        guard let bestPlace else { return nil }
        if bestDistance <= bestPlace.radiusKilometers {
            return bestDistance < 3 ? bestPlace.name : "\(bestPlace.name) Nearby"
        }
        return "Near \(bestPlace.name) · \(Int(bestDistance.rounded())) km"
    }
}

private extension MediaKind {
    var categoryColor: Color {
        switch self {
        case .videos: Color(red: 0.02, green: 0.55, blue: 0.78)
        case .photos: Color.swipeGreen
        case .livePhotos: Color(red: 0.47, green: 0.72, blue: 0.18)
        case .screenshots: Color(red: 0.55, green: 0.42, blue: 0.88)
        }
    }
}

private extension CGSize {
    static func + (lhs: CGSize, rhs: CGSize) -> CGSize {
        CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
    }
}

private extension Int {
    var megabytes: Int64 {
        Int64(self) * 1024 * 1024
    }
}

private extension Int64 {
    var storageDisplay: String {
        self == 0 ? "0 KB" : ByteCountFormatter.storage.string(fromByteCount: self)
    }
}

private extension UIImage {
    var averageColor: UIColor? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        let image = renderer.image { _ in
            draw(in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }

        guard let data = image.cgImage?.dataProvider?.data,
              let pointer = CFDataGetBytePtr(data) else {
            return nil
        }

        return UIColor(
            red: CGFloat(pointer[0]) / 255,
            green: CGFloat(pointer[1]) / 255,
            blue: CGFloat(pointer[2]) / 255,
            alpha: 1
        )
    }
}

private extension UIColor {
    func adjusted(brightness multiplier: CGFloat) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return self
        }
        return UIColor(
            hue: hue,
            saturation: saturation,
            brightness: min(max(brightness * multiplier, 0), 1),
            alpha: alpha
        )
    }
}

private extension ByteCountFormatter {
    static let storage: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter
    }()
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
