import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var userDefaults: UserDefaultsManager
    @StateObject private var viewModel = HomeViewModel()
    @State private var showCamera = false
    @State private var showVoice = false
    @State private var showRecipes = false
    @State private var showCalories = false
    @State private var generatedRecipes: [Recipe] = []
    @State private var caloriesResponse: CaloriesResponse?

    // Two columns on a phone held upright, more where there is room for them.
    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 12)]

    var body: some View {
        NavigationStack {
            ZStack {
                // Main Content
                mainContent

                // FABs
                fabButtons
            }
            .navigationTitle("RecipeAI")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showCamera) {
                CameraView(
                    onRecipesGenerated: { recipes in
                        generatedRecipes = recipes
                        showCamera = false
                        showRecipes = true
                    },
                    onCaloriesCalculated: { response in
                        caloriesResponse = response
                        showCamera = false
                        showCalories = true
                    }
                )
            }
            .sheet(isPresented: $showVoice) {
                VoiceView { recipes in
                    generatedRecipes = recipes
                    showRecipes = true
                }
            }
            .navigationDestination(isPresented: $showRecipes) {
                RecipesListView(recipes: generatedRecipes)
            }
            .navigationDestination(isPresented: $showCalories) {
                if let response = caloriesResponse {
                    CaloriesView(caloriesResponse: response)
                }
            }
            .onAppear {
                Task {
                    await viewModel.loadIfNeeded()
                }
            }
            // The first-launch language picker sits on top of this screen, so
            // choosing a language there does not make the screen appear again.
            .onChange(of: userDefaults.selectedLanguage) {
                Task {
                    await viewModel.loadIfNeeded()
                }
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                if !viewModel.recipes.isEmpty {
                    recipeGrid
                    feedFooter
                } else if viewModel.error != nil {
                    errorSection
                } else if viewModel.hasNoMatches {
                    emptySection
                } else {
                    loadingGrid
                }
            }
            .padding()
            .padding(.bottom, 148) // Lets the last row scroll clear of the FABs
        }
        .refreshable {
            await viewModel.refresh()
        }
        .alert("Couldn't Refresh", isPresented: $viewModel.showRefreshError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    // MARK: - Recipe Grid

    private var recipeGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(viewModel.recipes) { recipe in
                NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                    RecipeGridCard(recipe: recipe)
                }
                .buttonStyle(.plain)
                .onAppear {
                    Task {
                        await viewModel.loadMoreIfNeeded(after: recipe)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var feedFooter: some View {
        if viewModel.isLoadingMore {
            ProgressView()
        } else if viewModel.loadMoreFailed {
            Button {
                Task {
                    await viewModel.loadMore()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                    Text("Couldn't load more recipes. Try again")
                        .font(.appCaption1)
                }
                .foregroundColor(.textSecondary)
            }
        }
    }

    // MARK: - Loading Grid

    /// Placeholder cards shown while the first page loads.
    private var loadingGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(0..<HomeViewModel.pageSize, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 8) {
                    LinearGradient(
                        colors: [Color.placeholderBgTop, Color.placeholderBgBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .aspectRatio(4 / 3, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    Text("Recipe name")
                        .font(.appSubheadline.weight(.semibold))
                        .lineLimit(2, reservesSpace: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .redacted(reason: .placeholder)
                }
                .cardStyle(padding: 8)
            }
        }
    }

    // MARK: - Empty Section

    private var emptySection: some View {
        VStack(spacing: 16) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 60))
                .foregroundColor(.brandGreen)

            Text("No recipes for your preferences yet")
                .font(.appHeadline)
                .foregroundColor(.textPrimary)

            Text("Take a photo of your ingredients or describe a dish, and we'll make a recipe for you!")
                .font(.appSubheadline)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Error Section

    private var errorSection: some View {
        VStack(spacing: 16) {
            Image(systemName: viewModel.error?.isNetworkUnavailable == true ? "wifi.slash" : "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.statusOrange)

            Text("Something went wrong")
                .font(.appHeadline)
                .foregroundColor(.textPrimary)

            Text(viewModel.errorMessage)
                .font(.appSubheadline)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                Task {
                    await viewModel.refresh()
                }
            }
            .buttonStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - FAB Buttons

    private var fabButtons: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 16) {
                    // Voice FAB
                    Button {
                        showVoice = true
                    } label: {
                        Image(systemName: "mic.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.brandGreen)
                            .clipShape(Circle())
                            .shadow(color: .brandGreen.opacity(0.4), radius: 8, x: 0, y: 4)
                    }

                    // Camera FAB
                    Button {
                        showCamera = true
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.brandGreen)
                            .clipShape(Circle())
                            .shadow(color: .brandGreen.opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                }
                .padding(.trailing, 24)
                .padding(.bottom, 24)
            }
        }
    }
}

// MARK: - Recipe Grid Card

/// One cell of the home feed: the picture with the name under it.
private struct RecipeGridCard: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RecipeImageView(
                recipeId: recipe.id,
                initialImageUrl: recipe.imageUrl,
                cornerRadius: 8
            )
            .aspectRatio(4 / 3, contentMode: .fit)

            Text(recipe.name)
                .font(.appSubheadline.weight(.semibold))
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.leading)
                // Two lines even for a short name, so every card is the same height
                .lineLimit(2, reservesSpace: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .cardStyle(padding: 8)
    }
}

#Preview {
    HomeView()
        .environmentObject(UserDefaultsManager.shared)
}
