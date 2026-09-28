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

    private var updatesTask: Task<Void, Never>?

    init() {
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
            products = try await Product.products(for: ProProductIDs.all)
                .sorted { lhs, rhs in
                    // Monthly first, then yearly.
                    if lhs.id == ProProductIDs.monthly { return true }
                    if rhs.id == ProProductIDs.monthly { return false }
                    return lhs.displayName < rhs.displayName
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
        isPro = entitled
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
