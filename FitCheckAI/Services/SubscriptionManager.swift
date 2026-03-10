//
//  SubscriptionManager.swift
//  FitCheckAI
//

import Foundation
import StoreKit
import SwiftUI
import Combine

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published var products: [Product] = []
    @Published var isSubscribed: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let freeAnalysesKey = "fitcheck_free_analyses_used"

    private let productIds: [String] = [
        "fitcheckai.pro.weekly",
        "fitcheckai.pro.monthly",
        "fitcheckai.pro.yearly"
    ]

    var canAnalyze: Bool {
        isSubscribed || freeAnalysesUsed < 3
    }

    init() {
        Task {
            await refresh()
            await observeTransactions()
        }
    }

    func refresh() async {
        await loadProducts()
        await updateSubscriptionStatus()
    }

    func recordAnalysisUsedIfNeeded() {
        guard !isSubscribed, freeAnalysesUsed < 3 else { return }
        let current = freeAnalysesUsed
        freeAnalysesUsed = current + 1
    }

    private var freeAnalysesUsed: Int {
        get {
            UserDefaults.standard.integer(forKey: freeAnalysesKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: freeAnalysesKey)
        }
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let storeProducts = try await Product.products(for: productIds)
            // Keep a stable order: weekly, monthly, yearly.
            products = productIds.compactMap { id in storeProducts.first(where: { $0.id == id }) }
        } catch {
            errorMessage = "Unable to load plans right now. Please try again later."
        }
    }

    func updateSubscriptionStatus() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if productIds.contains(transaction.productID),
               transaction.revocationDate == nil,
               (transaction.expirationDate ?? .distantFuture) > Date() {
                active = true
                break
            }
        }
        isSubscribed = active
    }

    func purchase(_ product: Product) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    errorMessage = "We couldn’t verify your purchase. Please try again."
                    return false
                }
                if productIds.contains(transaction.productID) {
                    isSubscribed = true
                }
                await transaction.finish()
                return true
            case .userCancelled:
                return false
            case .pending:
                errorMessage = "Your purchase is pending approval."
                return false
            @unknown default:
                errorMessage = "Something went wrong with the purchase."
                return false
            }
        } catch {
            errorMessage = "Unable to complete purchase. Please try again."
            return false
        }
    }

    func restore() async {
        isLoading = true
        defer { isLoading = false }
        await updateSubscriptionStatus()
        if !isSubscribed {
            errorMessage = "No active FitCheckAI Pro subscription was found for this Apple ID."
        }
    }

    private func observeTransactions() async {
        for await update in Transaction.updates {
            guard case .verified(let transaction) = update else { continue }
            if productIds.contains(transaction.productID) {
                await updateSubscriptionStatus()
            }
            await transaction.finish()
        }
    }
}

