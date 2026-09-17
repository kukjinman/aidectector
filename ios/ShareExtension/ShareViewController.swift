import UIKit
import SwiftUI
import UniformTypeIdentifiers

/// Entry point declared via NSExtensionPrincipalClass in Info.plist (no storyboard).
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        Task { await presentShareUI() }
    }

    private func presentShareUI() async {
        let sharedURL = await extractSharedInstagramURL()
        let viewModel = ShareFlowViewModel(sharedURL: sharedURL, extensionContext: extensionContext)

        let hosting = UIHostingController(rootView: ShareRootView(viewModel: viewModel))
        addChild(hosting)
        hosting.view.frame = view.bounds
        hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hosting.view.backgroundColor = .clear
        view.addSubview(hosting.view)
        hosting.didMove(toParent: self)
    }

    /// Instagram's share sheet typically hands us the post's URL, either as a
    /// `public.url` item or embedded in shared plain text.
    private func extractSharedInstagramURL() async -> URL? {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return nil }

        for item in items {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                   let loaded = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil),
                   let url = loaded as? URL,
                   InstagramURLExtractor.isValidInstagramPostURL(url) {
                    return url
                }

                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                   let loaded = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil),
                   let text = loaded as? String,
                   let url = InstagramURLExtractor.firstInstagramURL(in: text) {
                    return url
                }
            }
        }
        return nil
    }
}
