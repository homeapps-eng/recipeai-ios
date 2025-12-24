import Foundation
import SwiftData

@MainActor
final class FavoritesRepository: ObservableObject {
    private let modelContext: ModelContext

    @Published var favorites: [Recipe] = []
    @Published var isLoading = false
    @Published var error: Error?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - CRUD Operations

    func addFavorite(_ recipe: Recipe) {
        // Check if already exists
        guard !isFavorite(recipeId: recipe.id) else { return }

        let favorite = FavoriteRecipe(from: recipe)
        modelContext.insert(favorite)

        do {
            try modelContext.save()
            fetchAllFavorites()
        } catch {
            self.error = error
            print("Error saving favorite: \(error)")
        }
    }

    func removeFavorite(recipeId: String) {
        let descriptor = FetchDescriptor<FavoriteRecipe>(
            predicate: #Predicate { $0.recipeId == recipeId }
        )

        do {
            if let favorite = try modelContext.fetch(descriptor).first {
                modelContext.delete(favorite)
                try modelContext.save()
                fetchAllFavorites()
            }
        } catch {
            self.error = error
            print("Error removing favorite: \(error)")
        }
    }

    func toggleFavorite(_ recipe: Recipe) {
        if isFavorite(recipeId: recipe.id) {
            removeFavorite(recipeId: recipe.id)
        } else {
            addFavorite(recipe)
        }
    }

    func isFavorite(recipeId: String) -> Bool {
        let descriptor = FetchDescriptor<FavoriteRecipe>(
            predicate: #Predicate { $0.recipeId == recipeId }
        )

        do {
            let count = try modelContext.fetchCount(descriptor)
            return count > 0
        } catch {
            return false
        }
    }

    // MARK: - Fetch Operations

    func fetchAllFavorites() {
        let descriptor = FetchDescriptor<FavoriteRecipe>(
            sortBy: [SortDescriptor(\.dateSaved, order: .reverse)]
        )

        do {
            let favoriteRecipes = try modelContext.fetch(descriptor)
            favorites = favoriteRecipes.map { $0.toRecipe() }
        } catch {
            self.error = error
            favorites = []
        }
    }

    func fetchFavoritesByDate(_ date: Date) -> [Recipe] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let descriptor = FetchDescriptor<FavoriteRecipe>(
            predicate: #Predicate { $0.dateSaved >= startOfDay && $0.dateSaved < endOfDay },
            sortBy: [SortDescriptor(\.dateSaved, order: .reverse)]
        )

        do {
            let favoriteRecipes = try modelContext.fetch(descriptor)
            return favoriteRecipes.map { $0.toRecipe() }
        } catch {
            self.error = error
            return []
        }
    }

    func getDatesWithFavorites() -> Set<Date> {
        let descriptor = FetchDescriptor<FavoriteRecipe>()

        do {
            let favorites = try modelContext.fetch(descriptor)
            let dates = favorites.map { Calendar.current.startOfDay(for: $0.dateSaved) }
            return Set(dates)
        } catch {
            return []
        }
    }

    // MARK: - Sync with Backend

    func syncWithBackend(userId: String) async {
        isLoading = true
        error = nil

        do {
            // Fetch favorites from backend
            let response: FavoritesResponse = try await NetworkManager.shared.get(
                endpoint: .getFavorites(userId: userId)
            )

            // Update local storage
            for favorite in response.favorites {
                if let recipe = favorite.recipe, !isFavorite(recipeId: recipe.id) {
                    addFavorite(recipe)
                }
            }

            fetchAllFavorites()
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }

    func addFavoriteToBackend(_ recipe: Recipe, userId: String) async {
        let request = AddFavoriteRequest(
            recipeId: recipe.id,
            recipe: recipe,
            capturedImagePath: recipe.capturedImagePath
        )

        do {
            let _: Favorite = try await NetworkManager.shared.post(
                endpoint: .addFavorite(userId: userId),
                body: request
            )
        } catch {
            print("Error adding favorite to backend: \(error)")
        }
    }

    func removeFavoriteFromBackend(recipeId: String, userId: String) async {
        do {
            let _: FavoritesResponse = try await NetworkManager.shared.delete(
                endpoint: .removeFavorite(userId: userId, recipeId: recipeId)
            )
        } catch {
            print("Error removing favorite from backend: \(error)")
        }
    }
}
