import StoreKit
import SwiftUI

struct ProPaywallView: View {
    @Environment(ProEntitlementStore.self) private var proStore
    @Environment(\.dismiss) private var dismiss

    private static let productIDList = [ProProductIDs.monthly, ProProductIDs.yearly]

    var body: some View {
        NavigationStack {
            Group {
                if proStore.isLoading && proStore.products.isEmpty {
                    ProgressView(String(localized: "Loading subscriptions…"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if proStore.products.isEmpty {
                    ContentUnavailableView {
                        Label(String(localized: "Subscriptions unavailable"), systemImage: "cart.badge.questionmark")
                    } description: {
                        storeKitDiagnosticMessage
                    } actions: {
                        Button(String(localized: "Try Again")) {
                            Task { await proStore.refresh() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    SubscriptionStoreView(productIDs: Self.productIDList) {
                        marketingHeader
                    }
                    .storeButton(.visible, for: .restorePurchases)
                    .subscriptionStorePolicyDestination(
                        url: LegalURLs.termsOfService,
                        for: .termsOfService
                    )
                    .subscriptionStorePolicyDestination(
                        url: LegalURLs.privacyPolicy,
                        for: .privacyPolicy
                    )
                    .onInAppPurchaseCompletion { _, result in
                        if case .success = result {
                            await proStore.refresh()
                            if proStore.isPro {
                                dismiss()
                            }
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "Upgrade"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Close")) {
                        dismiss()
                    }
                }
            }
            .task {
                await proStore.refresh()
            }
        }
    }

    private var marketingHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "PadelNote Watch Pro"))
                .font(.largeTitle.bold())

            Text(String(localized: "Unlock every court theme, the moving-ball serve indicator, and your full match journal beyond the last 30 days."))
                .font(.body)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Label(String(localized: "All color themes"), systemImage: "paintpalette.fill")
                Label(String(localized: "Moving-ball serve indicator"), systemImage: "tennisball.fill")
                Label(String(localized: "Full match history & insights"), systemImage: "clock.arrow.circlepath")
            }
            .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    private var storeKitDiagnosticMessage: Text {
        if let message = proStore.lastErrorMessage, !message.isEmpty {
            return Text(message)
        }
        #if DEBUG
        return Text(String(localized: "No StoreKit products loaded. For Simulator: Edit Scheme → Run → Options → StoreKit Configuration → PadelNote.storekit."))
        #else
        return Text(String(localized: "Subscriptions are temporarily unavailable. Check your connection and try again, or use Restore Purchases."))
        #endif
    }
}

#Preview {
    ProPaywallView()
        .environment(ProEntitlementStore())
}
