//
//  ReminiscenceApp.swift
//  Reminiscence
//
//  Created by Vedant Abrol on 3/1/25.
//

import SwiftUI
import CoreData
import CoreLocation
import UserNotifications

// Adding a UIApplicationDelegate to handle location permissions directly
class AppDelegate: NSObject, UIApplicationDelegate, CLLocationManagerDelegate {
    var locationManager: CLLocationManager?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("APP DELEGATE: Application did finish launching")
        
        // Initialize the location manager
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            print("Notification permission \(granted ? "granted" : "denied")")
        }
        
        // Check if location services are enabled at the system level
        if CLLocationManager.locationServicesEnabled() {
            print("APP DELEGATE: Location services are ENABLED on device")
        } else {
            print("APP DELEGATE: ⚠️ Location services are DISABLED on device - NO PROMPT WILL APPEAR")
        }
        
        // Show our dedicated permission screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // Ensure the app is fully loaded before showing the permission screen
            LocationPermissionHelper.shared.showPermissionViewController { granted in
                print("APP DELEGATE: Permission flow completed. Permission granted: \(granted)")
                
                // Notify the rest of the app
                let status = self.locationManager?.authorizationStatus ?? .notDetermined
                NotificationCenter.default.post(
                    name: Notification.Name("LocationAuthorizationChanged"),
                    object: nil,
                    userInfo: ["status": status]
                )
                
                // Start location updates if we have permission
                if granted {
                    self.locationManager?.startUpdatingLocation()
                }
            }
        }
        
        return true
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        print("APP DELEGATE: Authorization changed to: \(status.rawValue)")
        
        // Broadcast the change to the rest of the app
        NotificationCenter.default.post(
            name: Notification.Name("LocationAuthorizationChanged"),
            object: nil,
            userInfo: ["status": status]
        )
        
        // Start location updates if we have permission
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        // For iOS versions prior to iOS 14
        print("APP DELEGATE: Authorization changed to: \(status.rawValue)")
        
        // Broadcast the change to the rest of the app
        NotificationCenter.default.post(
            name: Notification.Name("LocationAuthorizationChanged"),
            object: nil,
            userInfo: ["status": status]
        )
    }
}

// GLOBAL LOCATION MANAGER - PERSISTENT THROUGHOUT APP
class AppLocationManager: NSObject, CLLocationManagerDelegate, ObservableObject {
    static let shared = AppLocationManager()
    var locationManager: CLLocationManager
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    // Keep track of notification observers
    private var notificationObserver: NSObjectProtocol?
    
    override init() {
        locationManager = CLLocationManager()
        super.init()
        locationManager.delegate = self
        
        // Initialize with current status
        authorizationStatus = CLLocationManager.authorizationStatus()
        print("APP LOCATION MANAGER: Created with initial status: \(authorizationStatus.rawValue)")
        
        // Set up observer for permission requests from LocationService
        notificationObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("RequestLocationPermission"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("APP LOCATION MANAGER: Received request for permission - executing")
            self?.requestPermission()
        }
    }
    
    deinit {
        // Remove observer when this object is deallocated
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    func requestPermission() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("APP LOCATION MANAGER: Explicitly requesting permission")
            let currentStatus = CLLocationManager.authorizationStatus()
            print("APP LOCATION MANAGER: Current status before request: \(currentStatus.rawValue)")
            
            if currentStatus == .notDetermined {
                self.locationManager.requestWhenInUseAuthorization()
            } else if currentStatus == .authorizedWhenInUse {
                self.locationManager.requestAlwaysAuthorization()
            }
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        print("APP LOCATION MANAGER: Authorization changed to: \(authorizationStatus.rawValue)")
        
        // Forward the authorization status to LocationService
        NotificationCenter.default.post(
            name: Notification.Name("LocationAuthorizationChanged"),
            object: nil,
            userInfo: ["status": authorizationStatus]
        )
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        // For iOS versions prior to iOS 14
        authorizationStatus = status
        print("APP LOCATION MANAGER: Authorization changed to: \(status.rawValue)")
    }
}

@main
struct ReminiscenceApp: App {
    // Initialize Core Data stack
    let coreDataStack = CoreDataStack.shared
    
    // Add the app location manager as a StateObject to ensure it persists
    @StateObject private var appLocationManager = AppLocationManager.shared
    
    // Register the app delegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    init() {
        // Configure global appearance
        configureAppearance()
        
        // For free Apple Developer accounts, background location won't work
        print("Note: Using a free developer account - background location features will be limited")
        
        // Check if location services are enabled at the system level
        if CLLocationManager.locationServicesEnabled() {
            print("MAIN APP: Location services are ENABLED on device")
        } else {
            print("MAIN APP: ⚠️ Location services are DISABLED on device - NO PROMPT WILL APPEAR")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            SplashScreenView()
                .environmentObject(appLocationManager) // Make it available throughout the app
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    // Save context when app goes to background
                    coreDataStack.saveContext()
                }
        }
    }
    
    private func configureAppearance() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
}
