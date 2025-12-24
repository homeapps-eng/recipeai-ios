import SwiftUI
import SwiftData

struct FavoritesView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewMode: ViewMode = .list
    @State private var selectedDate = Date()
    @State private var favorites: [Recipe] = []
    @State private var datesWithFavorites: Set<Date> = []

    private var favoritesRepo: FavoritesRepository {
        FavoritesRepository(modelContext: modelContext)
    }

    enum ViewMode {
        case list
        case calendar
    }

    var body: some View {
        VStack(spacing: 0) {
            // View Mode Picker
            Picker("View Mode", selection: $viewMode) {
                Image(systemName: "list.bullet")
                    .tag(ViewMode.list)
                Image(systemName: "calendar")
                    .tag(ViewMode.calendar)
            }
            .pickerStyle(.segmented)
            .padding()

            // Content
            if viewMode == .list {
                listView
            } else {
                calendarView
            }
        }
        .navigationTitle("Favorites")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadFavorites()
        }
    }

    // MARK: - List View

    private var listView: some View {
        Group {
            if favorites.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(favorites) { recipe in
                            NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                                RecipeCardView(recipe: recipe)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
    }

    // MARK: - Calendar View

    private var calendarView: some View {
        VStack(spacing: 16) {
            // Calendar
            DatePicker(
                "Select Date",
                selection: $selectedDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(.brandGreen)
            .padding(.horizontal)
            .onChange(of: selectedDate) { _, newDate in
                loadFavoritesForDate(newDate)
            }

            // Favorites for selected date
            let dateFavorites = favoritesRepo.fetchFavoritesByDate(selectedDate)
            if dateFavorites.isEmpty {
                Text("No favorites for this date")
                    .font(.appSubheadline)
                    .foregroundColor(.textSecondary)
                    .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(dateFavorites) { recipe in
                            NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                                compactRecipeRow(recipe)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }

            Spacer()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No favorites yet")
                .font(.appHeadline)
                .foregroundColor(.textPrimary)

            Text("Save recipes to view them here")
                .font(.appSubheadline)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Compact Recipe Row

    private func compactRecipeRow(_ recipe: Recipe) -> some View {
        HStack(spacing: 12) {
            // Thumbnail
            Group {
                if let imageUrl = recipe.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.brandGreenLight
                    }
                } else {
                    Color.brandGreenLight
                        .overlay {
                            Image(systemName: "fork.knife")
                                .foregroundColor(.brandGreen)
                        }
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(.appHeadline)
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)

                HStack {
                    Label(recipe.cookingTime, systemImage: "clock")
                    Label(recipe.difficulty, systemImage: "chart.bar")
                }
                .font(.appCaption1)
                .foregroundColor(.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.textTertiary)
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(12)
    }

    // MARK: - Data Loading

    private func loadFavorites() {
        favoritesRepo.fetchAllFavorites()
        favorites = favoritesRepo.favorites
        datesWithFavorites = favoritesRepo.getDatesWithFavorites()
    }

    private func loadFavoritesForDate(_ date: Date) {
        // This triggers UI update via state
    }
}

#Preview {
    NavigationStack {
        FavoritesView()
    }
}
