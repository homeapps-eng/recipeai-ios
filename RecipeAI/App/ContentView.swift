import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var userDefaultsManager: UserDefaultsManager
    @State private var showOnboarding = false

    var body: some View {
        Group {
            switch authManager.authState {
            case .loading:
                LoadingView()

            case .unauthenticated:
                SignInView()

            case .guest:
                // Guest users can skip preferences or complete them
                if userDefaultsManager.preferencesCompleted || userDefaultsManager.guestPreferencesSkipped {
                    MainTabView()
                } else {
                    GuestPreferencesView(onComplete: {
                        userDefaultsManager.preferencesCompleted = true
                    }, onSkip: {
                        userDefaultsManager.guestPreferencesSkipped = true
                    })
                }

            case .authenticated:
                // Authenticated users must complete preferences
                if userDefaultsManager.preferencesCompleted {
                    MainTabView()
                } else {
                    FoodPreferencesView(onComplete: {
                        userDefaultsManager.preferencesCompleted = true
                    })
                }
            }
        }
        .animation(.easeInOut, value: authManager.authState)
        .animation(.easeInOut, value: userDefaultsManager.preferencesCompleted)
        .animation(.easeInOut, value: userDefaultsManager.guestPreferencesSkipped)
    }
}

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.brandGreen
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image("logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)

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
