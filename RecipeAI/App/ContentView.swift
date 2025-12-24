import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var userDefaultsManager: UserDefaultsManager
    @State private var showOnboarding = false

    var body: some View {
        Group {
            if authManager.isLoading {
                LoadingView()
            } else if authManager.isAuthenticated {
                if userDefaultsManager.preferencesCompleted {
                    MainTabView()
                } else {
                    FoodPreferencesView(onComplete: {
                        userDefaultsManager.preferencesCompleted = true
                    })
                }
            } else {
                SignInView()
            }
        }
        .animation(.easeInOut, value: authManager.isAuthenticated)
        .animation(.easeInOut, value: userDefaultsManager.preferencesCompleted)
    }
}

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.brandGreen
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)

            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
                .tag(1)
        }
        .tint(.brandGreen)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager.shared)
        .environmentObject(UserDefaultsManager.shared)
}
