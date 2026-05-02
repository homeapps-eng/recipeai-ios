import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var showCamera = false
    @State private var showVoice = false
    @State private var showRecipes = false
    @State private var showCalories = false
    @State private var showSubscription = false
    @State private var generatedRecipes: [Recipe] = []
    @State private var caloriesResponse: CaloriesResponse?
    @State private var hasLoadedRecipe = false
    @State private var showRefreshError = false
    @State private var refreshErrorMessage = ""

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
                guard !hasLoadedRecipe else { return }
                hasLoadedRecipe = true
                Task {
                    await viewModel.loadDailyRecipe()
                }
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isLoading {
                    loadingSection
                } else if let recipe = viewModel.dailyRecipe {
                    dailyRecipeCard(recipe)
                } else if let error = viewModel.error {
                    errorSection(error)
                } else {
                    emptySection
                }
            }
            .padding()
            .padding(.bottom, 80) // Space for FAB
        }
        .refreshable {
            // Start refresh in background task and return immediately
            // This hides the pull-to-refresh spinner quickly
            // App's custom loading indicator will show instead
            Task { @MainActor in
                await viewModel.refreshRecipe()
                // Show alert if refresh failed but we still have old recipe
                if let error = viewModel.error, viewModel.dailyRecipe != nil {
                    refreshErrorMessage = error.userFriendlyMessage
                    showRefreshError = true
                }
            }
        }
        .alert("Couldn't Refresh", isPresented: $showRefreshError) {
            Button("OK") {}
        } message: {
            Text(refreshErrorMessage)
        }
        .alert("Daily Limit Reached", isPresented: $viewModel.showAdPrompt) {
            Button("Watch Ad") {
                viewModel.watchAdAndContinue()
            }
            Button("Upgrade to Premium") {
                viewModel.showAdPrompt = false
                showSubscription = true
            }
            Button("Cancel", role: .cancel) {
                viewModel.dismissAdPrompt()
            }
        } message: {
            Text("You've reached your daily limit. Watch a short ad to continue or upgrade to Premium for unlimited access.")
        }
        .alert("Ad Unavailable", isPresented: $viewModel.showAdError) {
            Button("Try Again") {
                viewModel.watchAdAndContinue()
            }
            Button("Upgrade to Premium") {
                showSubscription = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(viewModel.adErrorMessage)
        }
        .sheet(isPresented: $showSubscription, onDismiss: {
            // If user subscribed, try loading recipe again
            if SubscriptionManager.shared.isPremium && viewModel.dailyRecipe == nil {
                Task {
                    await viewModel.loadDailyRecipe()
                }
            }
        }) {
            NavigationStack {
                SubscriptionView()
                    .environmentObject(UserDefaultsManager.shared)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Close") {
                                showSubscription = false
                            }
                        }
                    }
            }
        }
    }

    // MARK: - Daily Recipe Card

    private func dailyRecipeCard(_ recipe: Recipe) -> some View {
        VStack(spacing: 12) {
            NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                VStack(alignment: .leading, spacing: 12) {
                    // Recipe Image — unified placeholder + animation + auto-polling
                    RecipeImageView(
                        recipeId: recipe.id,
                        initialImageUrl: recipe.imageUrl,
                        cornerRadius: 12
                    )
                    .frame(height: 200)

                    // Recipe Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Today's Recipe")
                            .font(.appCaption1)
                            .foregroundColor(.brandGreen)
                            .textCase(.uppercase)

                        Text(recipe.name)
                            .font(.appTitle3)
                            .foregroundColor(.textPrimary)

                        Text(recipe.shortDescription)
                            .font(.appSubheadline)
                            .foregroundColor(.textSecondary)
                            .lineLimit(2)

                        HStack(spacing: 16) {
                            Label(recipe.cookingTime, systemImage: "clock")
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Label(recipe.servings + " servings", systemImage: "person.2")
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Label(recipe.difficulty, systemImage: "chart.bar")
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .font(.appCaption1)
                        .foregroundColor(.textSecondary)
                    }
                }
                .cardStyle()
            }
            .buttonStyle(.plain)

            // Refresh hint
            Button {
                Task {
                    await viewModel.refreshRecipe()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                    Text("Get new recipe")
                        .font(.appCaption1)
                }
                .foregroundColor(.textSecondary)
            }
            .disabled(viewModel.isLoading)
            .opacity(viewModel.isLoading ? 0.5 : 1)
        }
    }

    // MARK: - Loading Section

    private var loadingSection: some View {
        VStack(spacing: 20) {
            // AI Animation
            AIRecipeLoadingAnimation()

            Text("AI is preparing your recipe...")
                .font(.appSubheadline)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Empty Section

    private var emptySection: some View {
        VStack(spacing: 16) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 60))
                .foregroundColor(.brandGreen)

            Text("No recipe available")
                .font(.appHeadline)
                .foregroundColor(.textPrimary)

            Text("Take a photo of your ingredients to generate recipes!")
                .font(.appSubheadline)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Error Section

    private func errorSection(_ error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: error.isNetworkUnavailable ? "wifi.slash" : "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.statusOrange)

            Text("Something went wrong")
                .font(.appHeadline)
                .foregroundColor(.textPrimary)

            Text(error.userFriendlyMessage)
                .font(.appSubheadline)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                Task {
                    await viewModel.refreshRecipe()
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

#Preview {
    HomeView()
}
