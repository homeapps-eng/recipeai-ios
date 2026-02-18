import SwiftUI
import UIKit
import Combine

// MARK: - AI Loading View

struct AILoadingView: View {
    let mode: AILoadingMode
    let image: UIImage?

    @State private var isAnimating = false
    @State private var currentMessageIndex = 0

    private let timer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Dark overlay
            Color.black.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                // Image preview with scanning effect
                if let image = image {
                    imageWithScanEffect(image)
                } else {
                    aiIconAnimation
                }

                // Status text
                statusSection

                // Progress dots
                progressDots
            }
            .padding(32)
        }
        .onAppear {
            isAnimating = true
        }
    }

    // MARK: - Image with Scan Effect

    private func imageWithScanEffect(_ uiImage: UIImage) -> some View {
        ZStack {
            // Image container
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 260, height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            // Scan overlay
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.green.opacity(0.1))
                .frame(width: 260, height: 260)

            // Animated scan line
            VStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .green.opacity(0.6), .green, .green.opacity(0.6), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 260, height: 4)
                    .shadow(color: .green, radius: 8)
                    .offset(y: isAnimating ? 120 : -120)
                    .animation(
                        .easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                Spacer()
            }
            .frame(width: 260, height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Corner brackets
            cornerBrackets
                .frame(width: 280, height: 280)

            // Glowing border
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green, lineWidth: 2)
                .frame(width: 260, height: 260)
                .shadow(color: .green.opacity(0.5), radius: isAnimating ? 10 : 5)
                .animation(
                    .easeInOut(duration: 1)
                    .repeatForever(autoreverses: true),
                    value: isAnimating
                )
        }
    }

    // MARK: - AI Icon Animation (when no image)

    private var aiIconAnimation: some View {
        ZStack {
            // Rotating outer ring
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [.green, .blue, .purple, .green],
                        center: .center
                    ),
                    lineWidth: 3
                )
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(
                    .linear(duration: 2)
                    .repeatForever(autoreverses: false),
                    value: isAnimating
                )

            // Pulsing inner circle
            Circle()
                .fill(Color.green.opacity(0.2))
                .frame(width: 80, height: 80)
                .scaleEffect(isAnimating ? 1.2 : 0.9)
                .animation(
                    .easeInOut(duration: 1)
                    .repeatForever(autoreverses: true),
                    value: isAnimating
                )

            // AI Icon
            Image(systemName: mode.iconName)
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(.green)
        }
    }

    // MARK: - Corner Brackets

    private var cornerBrackets: some View {
        ZStack {
            // Top-left
            VStack {
                HStack {
                    CornerBracket(rotation: 0)
                    Spacer()
                }
                Spacer()
            }

            // Top-right
            VStack {
                HStack {
                    Spacer()
                    CornerBracket(rotation: 90)
                }
                Spacer()
            }

            // Bottom-left
            VStack {
                Spacer()
                HStack {
                    CornerBracket(rotation: 270)
                    Spacer()
                }
            }

            // Bottom-right
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    CornerBracket(rotation: 180)
                }
            }
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(spacing: 12) {
            Text(mode.title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Text(mode.messages[currentMessageIndex])
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(height: 40)
                .id(currentMessageIndex) // Force view refresh for animation
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                currentMessageIndex = (currentMessageIndex + 1) % mode.messages.count
            }
        }
    }

    // MARK: - Progress Dots

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .scaleEffect(isAnimating ? 1.3 : 0.7)
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.15),
                        value: isAnimating
                    )
            }
        }
    }
}

// MARK: - Corner Bracket Shape

struct CornerBracket: View {
    let rotation: Double

    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 20))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 20, y: 0))
        }
        .stroke(Color.green, lineWidth: 3)
        .frame(width: 20, height: 20)
        .rotationEffect(.degrees(rotation))
    }
}

// MARK: - AI Loading Mode

enum AILoadingMode {
    case analyzingImage
    case generatingRecipes
    case calculatingCalories
    case processingRequest

    var title: String {
        switch self {
        case .analyzingImage:
            return "Analyzing Image"
        case .generatingRecipes:
            return "Creating Recipes"
        case .calculatingCalories:
            return "Calculating Nutrition"
        case .processingRequest:
            return "Processing"
        }
    }

    var iconName: String {
        switch self {
        case .analyzingImage:
            return "eye.fill"
        case .generatingRecipes:
            return "wand.and.stars"
        case .calculatingCalories:
            return "chart.bar.fill"
        case .processingRequest:
            return "sparkles"
        }
    }

    var messages: [String] {
        switch self {
        case .analyzingImage:
            return [
                "Scanning image contents...",
                "Identifying ingredients...",
                "Analyzing food items...",
                "Processing visual data..."
            ]
        case .generatingRecipes:
            return [
                "AI is crafting recipes...",
                "Matching flavors and ingredients...",
                "Creating cooking instructions...",
                "Almost ready..."
            ]
        case .calculatingCalories:
            return [
                "Identifying food portions...",
                "Calculating nutritional values...",
                "Analyzing macronutrients...",
                "Preparing your results..."
            ]
        case .processingRequest:
            return [
                "Processing your request...",
                "AI is thinking...",
                "Almost there...",
                "Finalizing results..."
            ]
        }
    }
}

// MARK: - View Extension for AI Loading

extension View {
    func aiLoadingOverlay(
        isLoading: Bool,
        mode: AILoadingMode = .processingRequest,
        image: UIImage? = nil
    ) -> some View {
        self.overlay {
            if isLoading {
                AILoadingView(mode: mode, image: image)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isLoading)
    }
}

// MARK: - Inline AI Recipe Loading Animation

struct AIRecipeLoadingAnimation: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Orbiting dots
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.green.opacity(0.7))
                    .frame(width: 10, height: 10)
                    .offset(x: 35)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(
                        .linear(duration: 1.5)
                        .repeatForever(autoreverses: false)
                        .delay(Double(index) * 0.5),
                        value: isAnimating
                    )
            }

            // Center pulse
            Circle()
                .stroke(Color.green.opacity(0.4), lineWidth: 2)
                .frame(width: 60, height: 60)
                .scaleEffect(isAnimating ? 1.3 : 0.9)
                .animation(
                    .easeInOut(duration: 0.8)
                    .repeatForever(autoreverses: true),
                    value: isAnimating
                )

            // Inner circle
            Circle()
                .fill(Color.green.opacity(0.15))
                .frame(width: 50, height: 50)

            // AI Icon
            Image(systemName: "wand.and.stars")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.green)
        }
        .frame(width: 90, height: 90)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Preview

#Preview("With Image") {
    AILoadingView(
        mode: .generatingRecipes,
        image: UIImage(systemName: "photo.fill")
    )
}

#Preview("Without Image") {
    AILoadingView(
        mode: .generatingRecipes,
        image: nil
    )
}

#Preview("Inline") {
    VStack {
        AIRecipeLoadingAnimation()
        Text("AI is preparing...")
            .foregroundColor(.gray)
    }
}
