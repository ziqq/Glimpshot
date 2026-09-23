import AppKit
import ImageIO
import SwiftUI

struct HistoryItem: Identifiable, Hashable {
    let url: URL
    let date: Date
    let bytes: Int
    var id: URL { url }
}

@MainActor
final class HistoryModel: ObservableObject {
    @Published private(set) var items: [HistoryItem] = []
    @Published var query = ""
    private var observer: NSObjectProtocol?

    init() {
        observer = NotificationCenter.default.addObserver(forName: .snaplyDidSave, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }
    }

    var filtered: [HistoryItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return items }
        return items.filter { $0.url.lastPathComponent.localizedCaseInsensitiveContains(q) }
    }

    func reload() {
        let folder = Preferences.shared.saveFolder
        Task.detached(priority: .userInitiated) {
            let keys: [URLResourceKey] = [.creationDateKey, .fileSizeKey]
            let urls = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys,
                                                                     options: [.skipsHiddenFiles])) ?? []
            let items = urls
                .filter { ["png", "jpg", "jpeg"].contains($0.pathExtension.lowercased()) }
                .map { url -> HistoryItem in
                    let values = try? url.resourceValues(forKeys: Set(keys))
                    return HistoryItem(url: url, date: values?.creationDate ?? .distantPast, bytes: values?.fileSize ?? 0)
                }
                .sorted { $0.date > $1.date }
            await MainActor.run { self.items = items }
        }
    }

    func trash(_ item: HistoryItem) {
        try? FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
        items.removeAll { $0.url == item.url }
    }

    static func loadImage(_ url: URL) -> (CGImage, CGFloat)? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any]
        let dpi = (props?[kCGImagePropertyDPIWidth] as? NSNumber)?.doubleValue ?? 72
        return (image, max(1, CGFloat(dpi) / 72))
    }

    func copy(_ item: HistoryItem) {
        guard let (image, scale) = HistoryModel.loadImage(item.url) else { return }
        Exporter.copy(image, scale: scale)
        Exporter.feedback(image, scale: scale, title: "Скопировано в буфер обмена", url: item.url)
    }

    func pin(_ item: HistoryItem) {
        guard let (image, scale) = HistoryModel.loadImage(item.url) else { return }
        PinPanel.show(image: image, scale: scale, frame: nil)
    }
}

// MARK: - Thumbnails

private enum ThumbnailCache {
    static let cache = NSCache<NSURL, NSImage>()

    static func load(_ url: URL) async -> NSImage? {
        if let hit = cache.object(forKey: url as NSURL) { return hit }
        let image = await Task.detached(priority: .utility) { () -> NSImage? in
            guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
            let opts: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 600,
                kCGImageSourceCreateThumbnailWithTransform: true,
            ]
            guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
            return NSImage(cgImage: cg, size: CGSize(width: cg.width, height: cg.height))
        }.value
        if let image { cache.setObject(image, forKey: url as NSURL) }
        return image
    }
}

private struct Thumbnail: View {
    let url: URL
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            Rectangle().fill(Color.primary.opacity(0.05))
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(8)
                    .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .task(id: url) { image = await ThumbnailCache.load(url) }
    }
}

// MARK: - Views

struct HistoryView: View {
    @ObservedObject var model: HistoryModel
    @ObservedObject private var prefs = Preferences.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Поиск по имени", text: $model.query)
                    .textFieldStyle(.plain)
                Spacer()
                Text(countLabel).font(.callout).foregroundStyle(.secondary)
                Button {
                    NSWorkspace.shared.open(prefs.saveFolder)
                } label: {
                    Label("Открыть папку", systemImage: "folder")
                }
                Button {
                    model.reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Обновить")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            if model.filtered.isEmpty {
                ContentUnavailableView {
                    Label(model.items.isEmpty ? "Пока пусто" : "Ничего не найдено", systemImage: "photo.on.rectangle.angled")
                } description: {
                    Text(model.items.isEmpty
                         ? "Сохранённые снимки из \(prefs.saveFolder.abbreviatedPath) появятся здесь."
                         : "Попробуйте другой запрос.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 280), spacing: 16)], spacing: 18) {
                        ForEach(model.filtered) { item in
                            HistoryCard(item: item, model: model)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .frame(minWidth: 520, minHeight: 360)
        .onAppear { model.reload() }
        .onChange(of: prefs.saveFolder) { _, _ in model.reload() }
    }

    private var countLabel: String {
        let n = model.items.count
        let mod10 = n % 10, mod100 = n % 100
        let word = mod10 == 1 && mod100 != 11 ? "снимок"
            : (2...4).contains(mod10) && !(12...14).contains(mod100) ? "снимка" : "снимков"
        return "\(n) \(word)"
    }
}

private struct HistoryCard: View {
    let item: HistoryItem
    let model: HistoryModel
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Thumbnail(url: item.url)
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(hovering ? Color.accentColor : Color.primary.opacity(0.08),
                                  lineWidth: hovering ? 2 : 1))
                .overlay(alignment: .topTrailing) {
                    if hovering {
                        HStack(spacing: 4) {
                            CardButton(icon: "doc.on.doc", help: "Копировать") { model.copy(item) }
                            CardButton(icon: "pin", help: "Закрепить") { model.pin(item) }
                            CardButton(icon: "folder", help: "Показать в Finder") {
                                NSWorkspace.shared.activateFileViewerSelecting([item.url])
                            }
                            CardButton(icon: "trash", help: "В корзину") { model.trash(item) }
                        }
                        .padding(6)
                    }
                }
            VStack(alignment: .leading, spacing: 1) {
                Text(item.date, format: .dateTime.day().month().hour().minute())
                    .font(.system(size: 12, weight: .medium))
                Text(ByteCountFormatter.string(fromByteCount: Int64(item.bytes), countStyle: .file))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 2)
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) { NSWorkspace.shared.open(item.url) }
        .onDrag { NSItemProvider(contentsOf: item.url) ?? NSItemProvider() }
        .contextMenu {
            Button("Открыть") { NSWorkspace.shared.open(item.url) }
            Button("Копировать") { model.copy(item) }
            Button("Закрепить поверх окон") { model.pin(item) }
            Button("Показать в Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
            Divider()
            Button("Переместить в корзину", role: .destructive) { model.trash(item) }
        }
    }
}

private struct CardButton: View {
    let icon: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 26, height: 26)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
