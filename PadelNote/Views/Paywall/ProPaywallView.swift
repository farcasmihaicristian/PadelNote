import StoreKit
import SwiftUI

struct ProPaywallView: View {
    @Environment(ProEntitlementStore.self) private var proStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SubscriptionStoreView(productIDs: ProProductIDs.all) {
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
            .storeButton(.visible, for: .restorePurchases)
            .subscriptionStorePolicyDestination(url: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!, for: .termsOfService)
            .subscriptionStorePolicyDestination(url: URL(string: "https://www.apple.com/privacy/")!, for: .privacyPolicy)
            .onInAppPurchaseCompletion { _, result in
                if case .success = result {
                    await proStore.refresh()
                    if proStore.isPro {
                        dismiss()
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
}

#Preview {
    ProPaywallView()
        .environment(ProEntitlementStore())
}
