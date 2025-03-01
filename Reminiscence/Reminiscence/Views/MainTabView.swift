//
//  MainTabView.swift
//  Reminiscence
//
//  Created for Spatial Memory App
//

import SwiftUI
import CoreLocation

struct MainTabView: View {
    @EnvironmentObject var viewModel: MemoryViewModel
    @State private var selectedTab = 0
    
    // Use the app-wide location manager instead of creating our own
    @EnvironmentObject var appLocationManager: AppLocationManager
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Map Tab
            MemoryMapView()
                .tabItem {
                    Label("Map", systemImage: "map")
                }
                .tag(0)
            
            // List Tab
            MemoryListView()
                .tabItem {
                    Label("Memories", systemImage: "list.bullet")
                }
                .tag(1)
            
            // Stats Tab
            StatsView()
                .tabItem {
                    Label("Analytics", systemImage: "chart.bar")
                }
                .tag(2)
            
            // Settings Tab
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
        .environmentObject(viewModel)
        .onAppear {
            // Configure appearance
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            UITabBar.appearance().standardAppearance = appearance
            
            if #available(iOS 15.0, *) {
                UITabBar.appearance().scrollEdgeAppearance = appearance
            }
            
            // Listen for location changes
            if appLocationManager.authorizationStatus == .authorizedWhenInUse || 
               appLocationManager.authorizationStatus == .authorizedAlways {
                // Start location updates if we already have permission
                viewModel.startLocationUpdates()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LocationAuthorizationChanged"))) { notification in
            guard let userInfo = notification.userInfo,
                  let status = userInfo["status"] as? CLAuthorizationStatus else {
                return
            }
            
            // If we now have permission, start updates
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                viewModel.startLocationUpdates()
            }
        }
    }
}

struct StatsView: View {
    @EnvironmentObject var viewModel: MemoryViewModel
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Memory count card
                    StatCard(title: "Total Memories", value: "\(viewModel.memories.count)", icon: "note.text", color: .blue)
                    
                    // Memory types breakdown
                    VStack(alignment: .leading) {
                        Text("Memory Types")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        HStack {
                            // Text memories
                            let textCount = viewModel.memories.filter { $0.contentType == "text" }.count
                            TypePieSlice(count: textCount, total: viewModel.memories.count, title: "Text", icon: "note.text", color: .blue)
                            
                            // Photo memories
                            let photoCount = viewModel.memories.filter { $0.contentType == "photo" }.count
                            TypePieSlice(count: photoCount, total: viewModel.memories.count, title: "Photos", icon: "photo", color: .green)
                            
                            // Audio memories
                            let audioCount = viewModel.memories.filter { $0.contentType == "audio" }.count
                            TypePieSlice(count: audioCount, total: viewModel.memories.count, title: "Audio", icon: "mic", color: .red)
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.1)))
                        .padding(.horizontal)
                    }
                    
                    // Most active locations
                    VStack(alignment: .leading) {
                        Text("Most Active Locations")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if viewModel.memoryHeatmap.isEmpty {
                            Text("No location data yet")
                                .foregroundColor(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            // Display top locations based on heatmap
                            let sortedLocations = viewModel.memoryHeatmap.sorted { $0.value > $1.value }.prefix(5)
                            
                            ForEach(Array(sortedLocations.enumerated()), id: \.element.key.latitude) { index, item in
                                HStack {
                                    Text("\(index + 1)")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(width: 30, height: 30)
                                        .background(Circle().fill(Color.blue))
                                    
                                    VStack(alignment: .leading) {
                                        Text("Location \(index + 1)")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        Text("Visited \(item.value) times")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("\(item.value)")
                                        .font(.headline)
                                        .foregroundColor(.blue)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal)
                                
                                if index < sortedLocations.count - 1 {
                                    Divider()
                                        .padding(.horizontal)
                                }
                            }
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.1)))
                            .padding(.horizontal)
                        }
                    }
                    
                    // Tags usage
                    VStack(alignment: .leading) {
                        Text("Most Used Tags")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if viewModel.tags.isEmpty {
                            Text("No tags created yet")
                                .foregroundColor(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            // Count memories per tag
                            let tagCounts = viewModel.tags.map { tag -> (Tag, Int) in
                                guard let memorySet = tag.memories as? Set<MemoryItem> else {
                                    return (tag, 0)
                                }
                                return (tag, memorySet.count)
                            }
                            
                            let sortedTags = tagCounts.sorted { $0.1 > $1.1 }.prefix(5)
                            
                            ForEach(Array(sortedTags.enumerated()), id: \.element.0.id) { index, item in
                                HStack {
                                    Circle()
                                        .fill(colorFromString(item.0.color ?? "blue"))
                                        .frame(width: 12, height: 12)
                                    
                                    Text(item.0.name ?? "Unknown tag")
                                        .fontWeight(.medium)
                                    
                                    Spacer()
                                    
                                    Text("\(item.1) memories")
                                        .foregroundColor(.secondary)
                                        .font(.subheadline)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal)
                                
                                if index < sortedTags.count - 1 {
                                    Divider()
                                        .padding(.horizontal)
                                }
                            }
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.1)))
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Analytics")
        }
    }
    
    private func colorFromString(_ colorName: String) -> Color {
        switch colorName {
        case "red": return .red
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "orange": return .orange
        default: return .blue
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
                .frame(width: 50)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
            }
            
            Spacer()
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.1)))
        .padding(.horizontal)
    }
}

struct TypePieSlice: View {
    let count: Int
    let total: Int
    let title: String
    let icon: String
    let color: Color
    
    var percentage: Int {
        if total == 0 { return 0 }
        return Int((Double(count) / Double(total)) * 100)
    }
    
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.3), lineWidth: 10)
                    .frame(width: 70, height: 70)
                
                if total > 0 {
                    Circle()
                        .trim(from: 0, to: CGFloat(count) / CGFloat(total))
                        .stroke(color, lineWidth: 10)
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))
                }
                
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
            }
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
            
            Text("\(count) (\(percentage)%)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SettingsView: View {
    @EnvironmentObject var viewModel: MemoryViewModel
    @EnvironmentObject var appLocationManager: AppLocationManager
    @State private var notificationsEnabled = true
    @State private var backgroundLocationEnabled = true
    @State private var batteryOptimizationEnabled = true
    @State private var backupFrequency = "daily"
    
    let backupOptions = ["daily", "weekly", "monthly", "never"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Location Settings")) {
                    HStack {
                        Text("Location Authorization")
                        Spacer()
                        Text(authStatusText)
                            .foregroundColor(authStatusColor)
                    }
                    
                    // Add the location permission button if permission is not granted
                    if appLocationManager.authorizationStatus == .notDetermined ||
                       appLocationManager.authorizationStatus == .denied ||
                       appLocationManager.authorizationStatus == .restricted {
                        
                        LocationPermissionButton(title: "Request Location Permission")
                            .listRowInsets(EdgeInsets())
                            .padding(.vertical, 8)
                    }
                    
                    // Only show background toggle if when-in-use permission is granted
                    if appLocationManager.authorizationStatus == .authorizedWhenInUse {
                        Toggle("Request Background Location", isOn: $backgroundLocationEnabled)
                            .onChange(of: backgroundLocationEnabled) { newValue in
                                if newValue {
                                    // Request 'Always' permission
                                    LocationPermissionHelper.shared.forceLocationPermissionRequest()
                                }
                            }
                    }
                    
                    Toggle("Battery Optimization", isOn: $batteryOptimizationEnabled)
                        .onChange(of: batteryOptimizationEnabled) { _ in
                            // In a real app, this would adjust the location manager's
                            // accuracy parameters and monitoring strategy
                        }
                }
                
                Section(header: Text("Notifications")) {
                    Toggle("Memory Notifications", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { _ in
                            // In a real app, this would request notification permissions
                        }
                    
                    Stepper("Notification Radius: \(notificationRadius)m", 
                            value: $notificationRadius, 
                            in: 10...500, 
                            step: 10)
                }
                
                Section(header: Text("Data Management")) {
                    Picker("Backup Frequency", selection: $backupFrequency) {
                        Text("Daily").tag("daily")
                        Text("Weekly").tag("weekly")
                        Text("Monthly").tag("monthly")
                        Text("Never").tag("never")
                    }
                    
                    Button(action: {
                        // In a real app, this would initiate a backup process
                    }) {
                        Text("Backup Now")
                    }
                    
                    Button(action: {
                        // In a real app, this would clear all data
                    }) {
                        Text("Clear All Data")
                            .foregroundColor(.red)
                    }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: {
                        // In a real app, this would open a web link
                    }) {
                        Text("Privacy Policy")
                    }
                    
                    Button(action: {
                        // In a real app, this would open a feedback form
                    }) {
                        Text("Send Feedback")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
    
    private var authStatusText: String {
        switch appLocationManager.authorizationStatus {
        case .notDetermined:
            return "Not Determined"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .authorizedAlways:
            return "Always"
        case .authorizedWhenInUse:
            return "When In Use"
        @unknown default:
            return "Unknown"
        }
    }
    
    private var authStatusColor: Color {
        switch appLocationManager.authorizationStatus {
        case .authorizedAlways:
            return .green
        case .authorizedWhenInUse:
            return .orange
        case .denied, .restricted:
            return .red
        default:
            return .secondary
        }
    }
    
    @State private var notificationRadius: Int = 50
}

#Preview {
    MainTabView()
} 