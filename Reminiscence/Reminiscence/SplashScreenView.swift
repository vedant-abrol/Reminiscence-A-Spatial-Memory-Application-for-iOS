import SwiftUI

struct SplashScreenView: View {
    @StateObject private var viewModel = MemoryViewModel()
    @State private var isActive = false
    @State private var opacity = 0.0
    @State private var scale = 1.0
    
    // Access the app-wide location manager
    @EnvironmentObject var appLocationManager: AppLocationManager
    
    var body: some View {
        if isActive {
            MainTabView()
                .environmentObject(viewModel)
                .environmentObject(appLocationManager) // Pass it to MainTabView
        } else {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 24) {
                    // Minimal logo presentation
                    Image("AppLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .scaleEffect(scale)
                    
                    Text("Reminiscence")
                        .font(.system(size: 28, weight: .light, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.top, 8)
                }
                .opacity(opacity)
                .onAppear {
                    // Apple-like subtle animation
                    withAnimation(.easeOut(duration: 0.8)) {
                        self.opacity = 1.0
                    }
                    
                    // Subtle pulse animation
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        self.scale = 1.05
                    }
                    
                    // Transition to main view after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        withAnimation(.easeIn(duration: 0.5)) {
                            self.isActive = true
                        }
                    }
                }
            }
        }
    }
}

// Helper extension to create colors from hex values
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// Add environment object to preview
#Preview {
    SplashScreenView()
        .environmentObject(AppLocationManager.shared)
} 