import DesignSystem
import SwiftUI
import UIKit
import WebKit

/// The in-app legal pages. Settings and the paywall use the same destinations.
enum LegalPage: Hashable, Identifiable {
    var id: Self { self }

    case privacy
    case terms

    var title: String {
        switch self {
        case .privacy: "Privacy Policy"
        case .terms: "Terms of Use"
        }
    }

    /// Nil until the URL is configured in `AppLinks` (the page is then not offered).
    var url: URL? {
        switch self {
        case .privacy: AppLinks.privacyPolicy
        case .terms: AppLinks.termsOfUse
        }
    }
}

/// A published page shown inside Retrograde, with loading, error and retry, and a way to open it
/// in Safari.
struct WebPageView: View {
    let title: String
    let url: URL
    @State private var state = WebView.LoadState.loading
    @State private var reloadToken = 0

    var body: some View {
        ZStack {
            WebView(url: url, reloadToken: reloadToken, state: $state)
                .opacity(state == .loaded ? 1 : 0)
                .accessibilityHidden(state != .loaded)
            switch state {
            case .loading:
                ProgressView("Loading…").tint(RetroColor.textMuted).foregroundStyle(RetroColor.textMuted)
            case .failed:
                VStack(spacing: 14) {
                    Image(systemName: "wifi.exclamationmark").font(.system(size: 30)).foregroundStyle(RetroColor.textMuted).accessibilityHidden(true)
                    Text("Couldn’t load the \(title.lowercased())").retroText(.cardTitle).foregroundStyle(RetroColor.text).multilineTextAlignment(.center)
                    Text("Check your connection and try again.").retroText(.body).foregroundStyle(RetroColor.textMuted)
                    SecondaryButton("Try again", systemImage: RetroSymbol.restart) {
                        state = .loading
                        reloadToken += 1
                    }
                    .frame(maxWidth: 220)
                }
                .padding(RetroMetrics.screenPadding)
            case .loaded:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .retroScreenBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Link(destination: url) { Image(systemName: "safari") }
                    .accessibilityLabel("Open in Safari")
            }
        }
    }
}

struct WebView: UIViewRepresentable {
    enum LoadState: Equatable { case loading, loaded, failed }

    let url: URL
    let reloadToken: Int
    @Binding var state: LoadState

    func makeCoordinator() -> Coordinator { Coordinator(state: $state) }

    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.navigationDelegate = context.coordinator
        view.isOpaque = false
        view.backgroundColor = .clear
        context.coordinator.lastToken = reloadToken
        view.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        if context.coordinator.lastToken != reloadToken {
            context.coordinator.lastToken = reloadToken
            view.load(URLRequest(url: url))
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var state: Binding<LoadState>
        var lastToken = 0

        init(state: Binding<LoadState>) {
            self.state = state
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { state.wrappedValue = .loaded }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { state.wrappedValue = .failed }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { state.wrappedValue = .failed }
    }
}

/// How to reach support, from `AppLinks`. Nothing is invented: with neither set there's no contact.
struct SupportContact: Equatable {
    let email: String?
    let page: URL?

    static let configured = SupportContact(email: AppLinks.supportEmail, page: AppLinks.supportPage)

    var isAvailable: Bool { email != nil || page != nil }
    var mailURL: URL? { email.flatMap { URL(string: "mailto:\($0)?subject=Retrograde%20support") } }
}

/// Settings › Contact Support: a native page with the email action and the support page.
struct SupportView: View {
    let contact: SupportContact
    @Environment(\.openURL) private var openURL
    @State private var mailUnavailable = false
    @State private var copied = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("We’re here to help").retroText(.cardTitle).foregroundStyle(RetroColor.text)
                    Text("Questions about Premium, purchases or how Retrograde works? Get in touch and we’ll reply as soon as we can. Retrograde is operated by \(AppLinks.appOperator).")
                        .retroText(.body).foregroundStyle(RetroColor.textMuted)
                }
                .padding(.vertical, 6)
                .accessibilityElement(children: .combine)
            }
            .listRowBackground(RetroColor.surface)

            if let email = contact.email, let mail = contact.mailURL {
                Section {
                    Button {
                        openURL(mail) { accepted in mailUnavailable = !accepted }
                    } label: {
                        Label("Email support", systemImage: "envelope").retroText(.bodyStrong)
                    }
                    .frame(minHeight: 44)
                    if mailUnavailable {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No email app is set up on this iPhone. You can write to us at:").retroText(.body).foregroundStyle(RetroColor.textMuted)
                            Text(email).retroText(.bodyStrong).foregroundStyle(RetroColor.text).textSelection(.enabled)
                            Button(copied ? "Copied" : "Copy address") {
                                UIPasteboard.general.string = email
                                copied = true
                            }
                            .frame(minHeight: 44)
                        }
                    }
                }
                .listRowBackground(RetroColor.surface)
            }
            if let page = contact.page {
                Section {
                    NavigationLink {
                        WebPageView(title: "Support", url: page)
                    } label: {
                        Label("Visit the support page", systemImage: "questionmark.circle").retroText(.bodyStrong)
                    }
                    .frame(minHeight: 44)
                }
                .listRowBackground(RetroColor.surface)
            }
            if !contact.isAvailable {
                Section {
                    Text("Support contact details aren’t available yet.").retroText(.body).foregroundStyle(RetroColor.textMuted)
                }
                .listRowBackground(RetroColor.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .retroScreenBackground()
        .navigationTitle("Contact Support")
        .navigationBarTitleDisplayMode(.inline)
    }
}
