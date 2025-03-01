//
//  MapView.swift
//  Reminiscence
//
//  Created for Spatial Memory App
//

import SwiftUI
import MapKit
import CoreLocation
import Reminiscence

struct MemoryMapView: View {
    @EnvironmentObject var viewModel: MemoryViewModel
    @EnvironmentObject var appLocationManager: AppLocationManager
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var showingCreateMemory = false
    @State private var mapType: MKMapType = .standard
    @State private var showHeatmap = false
    @State private var showPermissionDeniedView = false
    @State private var showPermissionBanner = false
    
    var body: some View {
        ZStack {
            // Always show the map content, but with different functionality based on permissions
            mapContent
                .overlay(
                    // Show a permission banner at the top of the map when permissions are denied
                    permissionBanner
                        .animation(.easeInOut, value: showPermissionBanner)
                )
        }
        .onAppear {
            checkLocationAuthorization()
            
            // Ensure we have a default location if the user doesn't grant permissions
            if viewModel.currentLocation == nil {
                // San Francisco as a default location
                print("MAP VIEW: Setting default location (San Francisco)")
                viewModel.currentLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
                updateMapRegion()
            }
        }
        .onChange(of: appLocationManager.authorizationStatus) { newStatus in
            print("MAP VIEW: Authorization status changed to: \(newStatus.rawValue)")
            
            // Update banner visibility based on status
            showPermissionBanner = (newStatus == .denied || newStatus == .restricted)
            
            // If we have permission, start location updates
            if newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways {
                viewModel.startLocationUpdates()
            } else {
                // Ensure we have a default location
                if viewModel.currentLocation == nil {
                    viewModel.currentLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
                    updateMapRegion()
                }
            }
        }
        .onChange(of: viewModel.currentLocation) { _ in
            updateMapRegion()
        }
    }
    
    // MARK: - Permission Banner
    
    private var permissionBanner: some View {
        Group {
            if showPermissionBanner {
                VStack {
                    HStack {
                        Image(systemName: "location.slash.fill")
                            .foregroundColor(.white)
                        
                        Text("Location access denied")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button(action: {
                            // Show the permission screen
                            LocationPermissionHelper.shared.showPermissionViewController { _ in 
                                // Check status after completion
                                let newStatus = appLocationManager.authorizationStatus
                                showPermissionBanner = (newStatus == .denied || newStatus == .restricted)
                            }
                        }) {
                            Text("Enable")
                                .font(.subheadline.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color.white)
                                .foregroundColor(.red)
                                .cornerRadius(12)
                        }
                    }
                    .padding(12)
                    .background(Color.red)
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Map Content View
    
    private var mapContent: some View {
        ZStack(alignment: .bottomTrailing) {
            // Map View
            Map(coordinateRegion: $region, showsUserLocation: true, userTrackingMode: .constant(.follow), annotationItems: viewModel.memories) { memory in
                MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: memory.latitude, longitude: memory.longitude)) {
                    MemoryAnnotationView(memory: memory)
                        .onTapGesture {
                            viewModel.selectedMemory = memory
                            viewModel.isShowingMemoryDetail = true
                        }
                }
            }
            .overlay(
                // Heatmap overlay
                showHeatmap ? HeatmapOverlay(heatmapData: viewModel.memoryHeatmap) : nil
            )
            .edgesIgnoringSafeArea(.all)
            
            // Controls
            VStack(spacing: 10) {
                HStack {
                    Spacer()
                    
                    // Map type control
                    Button(action: toggleMapType) {
                        Image(systemName: "map")
                            .padding()
                            .background(Color.white.opacity(0.9))
                            .clipShape(Circle())
                            .shadow(radius: 3)
                    }
                    .padding(.trailing)
                }
                
                HStack {
                    Spacer()
                    
                    // Toggle heatmap button
                    Button(action: {
                        withAnimation {
                            showHeatmap.toggle()
                        }
                    }) {
                        Image(systemName: showHeatmap ? "flame.fill" : "flame")
                            .padding()
                            .background(Color.white.opacity(0.9))
                            .clipShape(Circle())
                            .shadow(radius: 3)
                    }
                    .padding(.trailing)
                }
                
                HStack {
                    Spacer()
                    
                    // Add memory button
                    Button(action: {
                        // Check if we have location before showing create memory view
                        if viewModel.currentLocation != nil {
                            showingCreateMemory = true
                        } else {
                            // If no location, show alert instead
                            viewModel.alertMessage = "Cannot create memory: Your location is unavailable. Please make sure location services are enabled."
                            viewModel.showAlert = true
                        }
                    }) {
                        Image(systemName: "plus")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                            .shadow(radius: 3)
                    }
                    .padding([.trailing, .bottom])
                }
            }
            
            // Center on user button
            Button(action: centerOnUser) {
                Image(systemName: "location.fill")
                    .padding()
                    .background(Color.white.opacity(0.9))
                    .clipShape(Circle())
                    .shadow(radius: 3)
            }
            .padding()
            .position(x: 40, y: UIScreen.main.bounds.height - 120)
        }
        .alert(isPresented: $viewModel.showAlert) {
            Alert(title: Text("Notification"), message: Text(viewModel.alertMessage ?? ""), dismissButton: .default(Text("OK")))
        }
        .sheet(isPresented: $showingCreateMemory) {
            // Use the full CreateMemoryView instead of the simplified version
            CreateMemoryView()
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $viewModel.isShowingMemoryDetail, content: {
            if let memory = viewModel.selectedMemory {
                MemoryDetailView(memory: memory)
                    .environmentObject(viewModel)
            }
        })
    }
    
    // MARK: - Helper Methods
    
    private func checkLocationAuthorization() {
        // Use our app location manager to get the current status
        let authStatus = appLocationManager.authorizationStatus
        print("MAP VIEW: Checking location authorization - current status: \(authStatus.rawValue)")
        
        // Show banner if permission is denied
        showPermissionBanner = (authStatus == .denied || authStatus == .restricted)
        
        if authStatus == .notDetermined {
            print("MAP VIEW: Authorization not determined - requesting now from app location manager")
            appLocationManager.requestPermission()
        } else if authStatus == .denied || authStatus == .restricted {
            print("MAP VIEW: Location access denied/restricted - showing permission banner")
            
            // Still provide a default location so the app is usable
            if viewModel.currentLocation == nil {
                // San Francisco as a default location for testing
                print("MAP VIEW: Setting default location (San Francisco)")
                viewModel.currentLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
                updateMapRegion()
            }
        } else {
            // We have permission, make sure updates are started
            print("MAP VIEW: We have permission - starting location updates")
            viewModel.startLocationUpdates()
        }
    }
    
    private func updateMapRegion() {
        if let location = viewModel.currentLocation {
            region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
    }
    
    private func centerOnUser() {
        if let location = viewModel.currentLocation {
            withAnimation {
                region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            }
        }
    }
    
    private func toggleMapType() {
        switch mapType {
        case .standard:
            mapType = .satellite
        case .satellite:
            mapType = .hybrid
        case .hybrid:
            mapType = .standard
        default:
            mapType = .standard
        }
    }
}

// MARK: - Memory Annotation View

struct MemoryAnnotationView: View {
    let memory: MemoryItem
    
    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: iconForMemoryType(memory.contentType ?? "text"))
                .foregroundColor(.white)
                .padding(8)
                .background(Color.blue)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
                .shadow(radius: 3)
            
            Image(systemName: "triangle.fill")
                .foregroundColor(.blue)
                .rotationEffect(.degrees(180))
                .offset(y: -5)
                .padding(.bottom, 5)
        }
    }
    
    private func iconForMemoryType(_ type: String) -> String {
        switch type {
        case "photo":
            return "photo"
        case "audio":
            return "mic"
        case "video":
            return "video"
        default:
            return "note.text"
        }
    }
}

// MARK: - Heatmap Overlay

struct HeatmapOverlay: UIViewRepresentable {
    var heatmapData: [LocationCoordinate: Int]
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Remove existing overlays
        uiView.removeOverlays(uiView.overlays)
        
        // Add heatmap points
        for (hashableCoord, intensity) in heatmapData {
            let circle = MKCircle(center: hashableCoord.coordinate, radius: CLLocationDistance(20 + intensity * 5))
            uiView.addOverlay(circle)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: HeatmapOverlay
        
        init(_ parent: HeatmapOverlay) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                
                // Find the intensity for this circle
                let coordinate = circle.coordinate
                let hashableCoord = LocationCoordinate(coordinate: coordinate)
                if let intensity = parent.heatmapData[hashableCoord] {
                    // Calculate color based on intensity (red to blue gradient)
                    let normalizedIntensity = min(1.0, Double(intensity) / 10.0)
                    renderer.fillColor = UIColor(
                        red: CGFloat(normalizedIntensity),
                        green: 0.3,
                        blue: CGFloat(1.0 - normalizedIntensity),
                        alpha: 0.5
                    )
                    renderer.strokeColor = UIColor.white.withAlphaComponent(0.3)
                    renderer.lineWidth = 1
                } else {
                    // Default color if intensity not found
                    renderer.fillColor = UIColor.blue.withAlphaComponent(0.3)
                    renderer.strokeColor = UIColor.white.withAlphaComponent(0.3)
                    renderer.lineWidth = 1
                }
                
                return renderer
            }
            
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - Preview

#Preview {
    MemoryMapView()
        .environmentObject(MemoryViewModel())
} 