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
    /// The camera or voice screen to open once AI consent is given.
    @State private var pendingAIFeature: (() -> Void)?
    @State private var showAIConsent = false

    // One column on a phone held upright, so each picture gets the full width.
    // Two or more on a phone turned sideways or an iPad, lined up at the top
    // so the pictures in a row stay level when the names differ in length.
    private let columns = [GridItem(.adaptive(minimum: 320), spacing: 16, alignment: .top)]
    private let rowSpacing: CGFloat = 24

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
            // Ad consent where the law requires it (EEA, UK, Switzerland); then ads start
            .task {
                await AdsConsent.shared.gatherAndStartAds()
            }
            // Permission to send photos, requests and food preferences to the AI service
            .sheet(isPresented: $showAIConsent, onDismiss: {
                if AIConsent.shared.isGranted { pendingAIFeature?() }
                pendingAIFeature = nil
            }) {
                AIConsentView(
                    onAllow: {
                        AIConsent.shared.grant()
                        showAIConsent = false
                    },
                    onDecline: { showAIConsent = false }
                )
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
        LazyVGrid(columns: columns, spacing: rowSpacing) {
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
        LazyVGrid(columns: columns, spacing: rowSpacing) {
            ForEach(0..<HomeViewModel.pageSize, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 4) {
                    LinearGradient(
                        colors: [Color.placeholderBgTop, Color.placeholderBgBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .aspectRatio(RecipeGridCard.imageAspectRatio, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: RecipeGridCard.imageCornerRadius))
                    .padding(.bottom, 6)

                    Text("Recipe name goes here")
                        .font(.appHeadline)
                        .redacted(reason: .placeholder)

                    Text("45 minutes · 4 servings")
                        .font(.appSubheadline)
                        .redacted(reason: .placeholder)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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
                        withAIConsent { showVoice = true }
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
                        withAIConsent { showCamera = true }
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

    /// Opens an AI feature, asking permission first if the user hasn't given it
    /// (App Review guideline 5.1.2(i)).
    private func withAIConsent(_ open: @escaping () -> Void) {
        if AIConsent.shared.isGranted {
            open()
        } else {
            pendingAIFeature = open
            showAIConsent = true
        }
    }
}

// MARK: - Recipe Grid Card

/// One cell of the home feed: a large picture with rounded corners, the name
/// under it, then the cooking time and the servings. There is no card around
/// it: the picture itself is the card.
private struct RecipeGridCard: View {
    static let imageAspectRatio: CGFloat = 4 / 3
    static let imageCornerRadius: CGFloat = 16

    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            RecipeImageView(
                recipeId: recipe.id,
                initialImageUrl: recipe.imageUrl,
                cornerRadius: Self.imageCornerRadius
            )
            .aspectRatio(Self.imageAspectRatio, contentMode: .fit)
            .padding(.bottom, 6)

            Text(recipe.name)
                .font(.appHeadline)
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 14) {
                detail(recipe.cookingTime, icon: "clock")
                detail(recipe.servings, icon: "person.2")
            }
            .font(.appSubheadline)
            .foregroundColor(.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // The space between the picture and the text opens the recipe too
        .contentShape(Rectangle())
    }

    /// A small green icon with its value in gray, kept on one line.
    @ViewBuilder
    private func detail(_ value: String, icon: String) -> some View {
        if !value.isEmpty {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(.brandGreen)
                Text(value)
                    .lineLimit(1)
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(UserDefaultsManager.shared)
}
