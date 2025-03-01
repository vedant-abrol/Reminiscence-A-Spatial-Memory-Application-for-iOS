import SwiftUI
import UIKit

// A SwiftUI button that can be used to trigger location permission requests
struct LocationPermissionButton: View {
    let title: String
    let message: String?
    
    init(title: String = "Enable Location", message: String? = nil) {
        self.title = title
        self.message = message
    }
    
    var body: some View {
        Button(action: {
            // Find the top view controller
            if let topVC = UIApplication.topViewController() {
                // Show the explanation dialog
                LocationPermissionHelper.shared.showLocationExplanationDialog(from: topVC)
            } else {
                // Direct attempt if we can't get a view controller
                LocationPermissionHelper.shared.forceLocationPermissionRequest()
            }
        }) {
            HStack {
                Image(systemName: "location.fill")
                    .font(.body)
                Text(title)
            }
            .padding()
            .frame(maxWidth: message != nil ? .infinity : nil)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding(.horizontal, message != nil ? 16 : 0)
        .overlay(
            Group {
                if let message = message {
                    VStack(spacing: 12) {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .padding(.top, 8)
                        Spacer()
                    }
                    .padding(.top, 50)
                }
            }
        )
    }
}

// Use this view to show a permission denied alert with a button to go to settings
struct LocationPermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 70))
                .foregroundColor(.red.opacity(0.8))
                .padding()
            
            Text("Location Access Required")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("This app needs access to your location to associate memories with places. Please enable location services in Settings.")
                .multilineTextAlignment(.center)
                .font(.body)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button(action: {
                // Open app settings
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }) {
                Text("Open Settings")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.top, 10)
        }
        .padding()
    }
}

#Preview {
    VStack(spacing: 30) {
        LocationPermissionButton()
        
        LocationPermissionButton(title: "Allow Location Access", message: "Reminiscence needs your location to show you memories near you.")
        
        LocationPermissionDeniedView()
    }
} 