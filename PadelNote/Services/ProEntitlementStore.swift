import Foundation
import Observation
import PadelCore
import StoreKit

@Observable
@MainActor
final class ProEntitlementStore {
    private(set) var isPro = false
    private(set) var products: [Product] = []
    private(set) var isLoading = false
    private(set) var lastErrorMessage: String?

    #if DEBUG
    /// Simulator/dev bypass when StoreKit Configuration fails to load products.
    private static let debugForceProKey = "debug.forceProUnlocked"
    var debugForceProUnlocked: Bool = false {
        didSet {
            UserDefaults.standard.set(debugForceProUnlocked, forKey: Self.debugForceProKey)
            isPro = debugForceProUnlocked || storeKitEntitled
        }
    }
    #endif

    private var storeKitEntitled = false
    private var updatesTask: Task<Void, Never>?

    init() {
        #if DEBUG
        debugForceProUnlocked = UserDefaults.standard.bool(forKey: Self.debugForceProKey)
        #endif
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        Task { await refresh() }
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        lastErrorMessage = nil

        do {
            let loaded = try await Product.products(for: Array(ProProductIDs.all))
            products = loaded.sorted { lhs, rhs in
                // Monthly first, then yearly.
                if lhs.id == ProProductIDs.monthly { return true }
                if rhs.id == ProProductIDs.monthly { return false }
                return lhs.displayName < rhs.displayName
            }
            if products.isEmpty {
                #if DEBUG
                lastErrorMessage = String(
                    localized: "StoreKit returned 0 products. For Simulator: Edit Scheme → Run → Options → StoreKit Configuration → PadelNote.storekit."
                )
                #else
                lastErrorMessage = String(
                    localized: "No subscriptions found in App Store Connect yet. Create products com.farcasmc.padelnote.pro.monthly and com.farcasmc.padelnote.pro.yearly under PadelNote Watch Pro, finish Paid Apps agreement, and enable In-App Purchase on the App ID."
                )
                #endif
            }
        } catch {
            lastErrorMessage = error.localizedDescription
        }

        await refreshEntitlement()
    }

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        switch result {
        case let .success(verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await refreshEntitlement()
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlement()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    /// Resets free-tier Appearance defaults when Pro is not active.
    @discardableResult
    func enforceFreeAppearanceDefaults(themeStore: AppThemeStore) -> Bool {
        guard !isPro else { return false }
        var didChange = false

        if !ProAccessPolicy.isThemeUnlocked(themeID: themeStore.activeTheme.id, isPro: false) {
            themeStore.apply(AppThemeCatalog.default)
            didChange = true
        }
        if !ProAccessPolicy.isServeStyleUnlocked(style: themeStore.serveIndicatorStyle, isPro: false) {
            themeStore.applyServeIndicatorStyle(.sideLabels)
            didChange = true
        }
        return didChange
    }

    private func refreshEntitlement() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            if ProProductIDs.all.contains(transaction.productID) {
                entitled = true
                break
            }
        }
        storeKitEntitled = entitled
        #if DEBUG
        isPro = debugForceProUnlocked || storeKitEntitled
        #else
        isPro = storeKitEntitled
        #endif
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard let transaction = try? checkVerified(result) else { return }
        await transaction.finish()
        await refreshEntitlement()
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case let .unverified(_, error):
            throw error
        case let .verified(safe):
            return safe
        }
    }
}
