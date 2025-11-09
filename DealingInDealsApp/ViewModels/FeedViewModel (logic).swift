import Foundation

@MainActor
final class FeedViewModel: ObservableObject {
    @Published var state: LoadState = .idle
    @Published var posts: [WPPost] = []
    @Published var query: String = ""
    @Published var selectedStore: String? = nil

    var visiblePosts: [WPPost] {
        posts.filter { post in
            (query.isEmpty || post.title.rendered.localizedCaseInsensitiveContains(query)) &&
            (selectedStore == nil || post.title.rendered.localizedCaseInsensitiveContains(selectedStore!))
        }
    }

    var storesLastWeek: [String] {
        Array(Set(posts.compactMap { DealFormatting.storeName(fromTitleHTML: $0.title.rendered) })).sorted()
    }

    func load() async {
        state = .loading
        await refresh()
    }

    func refresh() async {
        do {
            let fetched = try await WordPressAPI.latestPosts()
            let ordered = fetched.sorted { $0.date > $1.date }
            posts = ordered
            #if DEBUG
            print("Refreshed posts count: \(ordered.count)")
            #endif
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func setQuery(_ q: String) { query = q }
    func selectStore(_ s: String?) { selectedStore = s }
}

enum LoadState {
    case idle, loading
    case failed(String)
    case loaded
}
