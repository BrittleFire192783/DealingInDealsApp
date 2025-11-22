import SwiftUI
import WebKit

struct DealCard: View {
    let post: WPPost
    @Environment(\.openURL) private var openURL
    @State private var resolvedURL: URL? = nil

    var body: some View {
        let primaryURL = post.fallbackImageURL ?? post.featuredMediaURL
        let displayURL = primaryURL ?? resolvedURL

        let derivedStore = DealFormatting.storeName(fromTitleHTML: post.title.rendered)
        let price = DealFormatting.price(titleHTML: post.title.rendered,
                                         contentHTML: post.content.rendered)
        let cleanedTitle = DealFormatting.cleanTitle(titleHTML: post.title.rendered,
                                                     store: derivedStore)

        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Rectangle().fill(Color.secondary.opacity(0.15))

                if let url = displayURL {
                    CachedAsyncImage(
                        url: url,
                        content: { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .clipped()
                        },
                        placeholder: {
                            ProgressView()
                        }
                    )
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