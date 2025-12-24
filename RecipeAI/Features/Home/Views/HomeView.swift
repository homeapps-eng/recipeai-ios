import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var showCamera = false
    @State private var showRecipes = false
    @State private var showCalories = false
    @State private var generatedRecipes: [Recipe] = []
    @State private var caloriesResponse: CaloriesResponse?

    var body: some View {
        NavigationStack {
            ZStack {
                // Main Content
                mainContent

                // Camera FAB
                cameraFAB
            }
            .navigationTitle("RecipeAI")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await viewModel.refreshRecipe()
            }
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
            .navigationDestination(isPresented: $showRecipes) {
                RecipesListView(recipes: generatedRecipes)
            }
            .navigationDestination(isPresented: $showCalories) {
                if let response = caloriesResponse {
                    CaloriesView(caloriesResponse: response)
                }
            }
            .task {
                await viewModel.loadDailyRecipe()
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

                // Usage Info for Free Users
                if !SubscriptionManager.shared.isPremium {
                    usageInfoSection
                }
            }
            .padding()
            .padding(.bottom, 80) // Space for FAB
        }
    }

    // MARK: - Daily Recipe Card

    private func dailyRecipeCard(_ recipe: Recipe) -> some View {
        NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
            VStack(alignment: .leading, spacing: 12) {
                // Recipe Image
                if let imageUrl = recipe.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.brandGreenLight)
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundColor(.brandGreen)
                            }
                    }
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(12)
                } else {
                    Rectangle()
                        .fill(Color.brandGreenLight)
                        .frame(height: 200)
                        .overlay {
                            Image(systemName: "fork.knife")
                                .font(.system(size: 50))
                                .foregroundColor(.brandGreen)
                        }
                        .cornerRadius(12)
                }

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
                        Label(recipe.servings + " servings", systemImage: "person.2")
                        Label(recipe.difficulty, systemImage: "chart.bar")
                    }
                    .font(.appCaption1)
                    .foregroundColor(.textSecondary)
                }
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Loading Section

    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading today's recipe...")
                .font(.appSubheadline)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 100)
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
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.statusOrange)

            Text("Something went wrong")
                .font(.appHeadline)
                .foregroundColor(.textPrimary)

            Text(error.localizedDescription)
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

    // MARK: - Usage Info

    private var usageInfoSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Daily Recipe Limit")
                    .font(.appSubheadline)
                    .foregroundColor(.textSecondary)

                Spacer()

                Text("\(RecipeUsageTracker.shared.remainingRecipes)/\(AppConfig.maxDailyRecipes)")
                    .font(.poppinsSemiBold(size: 15))
                    .foregroundColor(.brandGreen)
            }

            ProgressView(
                value: Double(AppConfig.maxDailyRecipes - RecipeUsageTracker.shared.remainingRecipes),
                total: Double(AppConfig.maxDailyRecipes)
            )
            .tint(.brandGreen)
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(12)
    }

    // MARK: - Camera FAB

    private var cameraFAB: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
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
                .padding(.trailing, 24)
                .padding(.bottom, 24)
            }
        }
    }
}

#Preview {
    HomeView()
}
