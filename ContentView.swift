import SwiftUI
import WebKit

// MARK: - ContentView (main screen)
struct ContentView: View {
    @StateObject private var vm = FeedViewModel()
    @State private var searchText = ""

    private let cols = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            Group {
                switch vm.state {
                case .idle, .loading:
                    ProgressView("Loading deals…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .failed(let msg):
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle").font(.largeTitle)
                        Text("Couldn’t load deals").font(.headline)
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Try Again") { Task { await vm.refresh() } }
                            .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .loaded:
                    let list = vm.visiblePosts
                    if list.isEmpty {
                        VStack(spacing: 12) {
                            ContentUnavailableView(
                                vm.query.isEmpty && vm.selectedStore == nil ? "No deals yet" : "No results",
                                systemImage: "magnifyingglass",
                                description: Text(vm.query.isEmpty && vm.selectedStore == nil
                                    ? "Pull to refresh to try again."
                                    : "Change filters or try a different keyword.")
                            )

                            if !(vm.query.isEmpty && vm.selectedStore == nil) {
                                Button {
                                    // Clear both search and store filter
                                    searchText = ""
                                    vm.setQuery("")
                                    vm.selectStore(nil)
                                } label: {
                                    Label("Clear filters", systemImage: "line.3.horizontal.decrease.circle")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVGrid(columns: cols, spacing: 12) {
                                ForEach(list) { post in
                                    NavigationLink(value: post) {
                                        DealCard(post: post)
                                    }
                                }
                            }
                            .padding(12)
                        }
                    }
                }
            }
            .navigationTitle("Dealing In Deals")
            .navigationDestination(for: WPPost.self) { post in
                DealDetailView(url: post.link)
            }
            .task { if case .idle = vm.state { await vm.load() } }
            .refreshable { await vm.refresh() }
            .searchable(text: $searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search deals")
            .onChange(of: searchText) { _, newValue in vm.setQuery(newValue) }
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            vm.selectStore(nil)
                        } label: {
                            Label("All stores", systemImage: vm.selectedStore == nil ? "checkmark" : "bag")
                        }

                        let stores = vm.storesLastWeek
                        if stores.isEmpty {
                            Label("No stores found (last 7 days)", systemImage: "clock")
                        } else {
                            ForEach(stores, id: \.self) { name in
                                Button { vm.selectStore(name) } label: {
                                    Label(name, systemImage: vm.selectedStore == name ? "checkmark" : "bag")
                                }
                            }
                        }
                    } label: {
                        if let s = vm.selectedStore {
                            Label(s, systemImage: "line.3.horizontal.decrease.circle")
                        } else {
                            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - DealCard (grid cell)
struct DealCard: View {
    let post: WPPost
    @Environment(\.openURL) private var openURL
    @State private var resolvedURL: URL? = nil   // og:image fallback

    var body: some View {
        let primaryURL = post.fallbackImageURL ?? post.featuredMediaURL
        let displayURL = primaryURL ?? resolvedURL

        let derivedStore = DealFormatting.storeName(fromTitleHTML: post.title.rendered)

        let price = DealFormatting.price(
            titleHTML: post.title.rendered,
            contentHTML: post.content.rendered
        )

        let cleanedTitle = DealFormatting.cleanTitle(
            titleHTML: post.title.rendered,
            store: derivedStore
        )

        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Rectangle().fill(Color.secondary.opacity(0.15))

                if let url = displayURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .clipped()
                        case .failure:
                            Image(systemName: "photo")
                                .imageScale(.large)
                                .foregroundStyle(.secondary)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: "photo")
                        .imageScale(.large)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if let price {
                    Text(price)
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.78))
                        .clipShape(Capsule())
                        .padding(6)
                        .zIndex(1)
                }
            }
            .onAppear {
                if resolvedURL == nil, primaryURL == nil {
                    Task {
                        let u = await ImageURLResolver.shared.resolve(from: post.link)
                        await MainActor.run { resolvedURL = u }
                    }
                }
            }

            Text(cleanedTitle)
                .font(.subheadline.weight(.semibold))
                .lineLimit(3)
                .foregroundStyle(.primary)

            Text(DealFormatting.displayTimestamp(iso: post.date))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contextMenu {
            ShareLink(item: post.link)
            Button {
                openURL(post.link)
            } label: {
                Label("Open in Safari", systemImage: "safari")
            }
        }
    }
}

// MARK: - DealDetailView
struct DealDetailView: View {
    let url: URL
    @Environment(\.openURL) private var openURL
    @State private var progress: Double = 0

    var body: some View {
        WebView(url: url, progress: $progress)
            .overlay(alignment: .top) {
                if progress < 1.0 {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .padding(.horizontal)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    ShareLink(item: url)
                    Button {
                        openURL(url)
                    } label: {
                        Label("Open in Safari", systemImage: "safari")
                    }
                }
            }
    }
}

// MARK: - WebView
struct WebView: UIViewRepresentable {
    let url: URL
    @Binding var progress: Double

    class Coordinator: NSObject {
        var progress: Binding<Double>
        init(progress: Binding<Double>) { self.progress = progress }
        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            guard keyPath == "estimatedProgress", let wv = object as? WKWebView else { return }
            DispatchQueue.main.async { self.progress.wrappedValue = wv.estimatedProgress }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(progress: $progress) }

    func makeUIView(context: Context) -> WKWebView {
        let wv = WKWebView()
        wv.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile"
        wv.allowsBackForwardNavigationGestures = true
        wv.addObserver(context.coordinator, forKeyPath: "estimatedProgress", options: .new, context: nil)
        wv.load(URLRequest(url: url))
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.url != url {
            uiView.load(URLRequest(url: url))
        }
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.removeObserver(coordinator, forKeyPath: "estimatedProgress")
    }
}

