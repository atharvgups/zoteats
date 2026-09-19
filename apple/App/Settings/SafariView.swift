import SafariServices
import SwiftUI

/// In-app Safari for the Anteats feedback form (and any other public URL).
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = UIColor(Color.uciBlue)
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
