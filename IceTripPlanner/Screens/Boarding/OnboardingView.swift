import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0
    @State private var dragOffset: CGFloat = 0
    
    let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "calendar.badge.clock",
            title: "Plan your fishing trips in advance",
            description: "Schedule trips, set dates, and never miss your favorite fishing season",
            color: Color(hex: "4A90E2")
        ),
        OnboardingPage(
            icon: "bag.fill",
            title: "Prepare gear and tasks before trip",
            description: "Create checklists, organize equipment, and ensure you have everything ready",
            color: Color(hex: "4CAF50")
        ),
        OnboardingPage(
            icon: "note.text.badge.plus",
            title: "Track completed trips and notes",
            description: "Record results, catches, and memorable moments from every adventure",
            color: Color(hex: "FF9800")
        )
    ]
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "1E3A5F"),
                    Color(hex: "2C5F8D")
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(
                            page: pages[index],
                            pageIndex: index,
                            currentPage: $currentPage
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                Spacer()
                
                // Custom page indicator
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Capsule()
                            .fill(currentPage == index ? Color.white : Color.white.opacity(0.3))
                            .frame(width: currentPage == index ? 30 : 8, height: 8)
                            .animation(.spring(), value: currentPage)
                    }
                }
                .padding(.bottom, 20)
                
                // Action buttons
                HStack(spacing: 20) {
                    if currentPage < pages.count - 1 {
                        Button(action: {
                            withAnimation {
                                hasCompletedOnboarding = true
                            }
                        }) {
                            Text("Skip")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 30)
                                .padding(.vertical, 15)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation {
                                currentPage += 1
                            }
                        }) {
                            HStack {
                                Text("Continue")
                                    .font(.system(size: 16, weight: .semibold))
                                Image(systemName: "arrow.right")
                            }
                            .foregroundColor(Color(hex: "1E3A5F"))
                            .padding(.horizontal, 30)
                            .padding(.vertical, 15)
                            .background(Color.white)
                            .cornerRadius(25)
                            .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                        }
                    } else {
                        Button(action: {
                            withAnimation {
                                hasCompletedOnboarding = true
                            }
                        }) {
                            HStack {
                                Text("Get Started")
                                    .font(.system(size: 18, weight: .bold))
                                Image(systemName: "arrow.right.circle.fill")
                            }
                            .foregroundColor(Color(hex: "1E3A5F"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.white)
                            .cornerRadius(25)
                            .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                        }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Onboarding Page Model
struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let color: Color
}

// MARK: - Individual Page View
struct OnboardingPageView: View {
    let page: OnboardingPage
    let pageIndex: Int
    @Binding var currentPage: Int
    
    @State private var iconScale: CGFloat = 0.8
    @State private var iconRotation: Double = 0
    @State private var textOpacity: Double = 0
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Animated icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                page.color.opacity(0.3),
                                page.color.opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 200, height: 200)
                    .blur(radius: 20)
                
                Image(systemName: page.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .foregroundColor(.white)
                    .scaleEffect(iconScale)
                    .rotationEffect(.degrees(iconRotation))
            }
            .padding(.top, 50)
            
            // Text content
            VStack(spacing: 20) {
                Text(page.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(textOpacity)
                
                Text(page.description)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(textOpacity)
            }
            
            Spacer()
        }
        .onChange(of: currentPage) { newValue in
            if newValue == pageIndex {
                startAnimations()
            }
        }
        .onAppear {
            if currentPage == pageIndex {
                startAnimations()
            }
        }
    }
    
    private func startAnimations() {
        // Icon animations
        iconScale = 0.8
        iconRotation = -15
        textOpacity = 0
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            iconScale = 1.0
        }
        
        withAnimation(.easeOut(duration: 0.5)) {
            iconRotation = 0
        }
        
        withAnimation(.easeIn(duration: 0.5).delay(0.2)) {
            textOpacity = 1.0
        }
        
        // Bounce animation
        if pageIndex == 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(
                    Animation.spring(response: 0.3, dampingFraction: 0.5)
                        .repeatCount(2, autoreverses: true)
                ) {
                    iconScale = 1.08
                }
            }
        }
        
        // Checkmark animation for last page
        if pageIndex == 2 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    iconScale = 1.1
                }
            }
        }
    }
}
