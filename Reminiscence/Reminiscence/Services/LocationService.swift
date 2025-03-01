//
//  LocationService.swift
//  Reminiscence
//
//  Created for Spatial Memory App
//

import Foundation
import CoreLocation
import CoreData
import UIKit
import Combine
import UserNotifications
import Reminiscence

// If the SpatialLocationManager is defined in Objective-C
// You'll need to include the bridging header or import specific files
// import "SpatialLocationManager.h"

// For now, let's use standard CLLocationManager
typealias SpatialLocationManager = CLLocationManager
typealias SpatialLocationDelegate = CLLocationManagerDelegate

// Define SpatialLocationDelegate conformance to receive updates from Objective-C
class LocationService: NSObject, SpatialLocationDelegate {
    
    // MARK: - Singleton
    static let shared = LocationService()
    
    // MARK: - Properties
    private var locationManager: SpatialLocationManager
    private var lastLocation: CLLocation?
    private var isMonitoringSignificantLocationChanges = false
    private var memoryRegions = [String: CLCircularRegion]()
    private var geofenceRadius: CLLocationDistance = 100 // Default radius in meters
    
    // MARK: - Publishers
    private let currentLocationSubject = PassthroughSubject<CLLocation, Never>()
    private let regionStateChangeSubject = PassthroughSubject<(CLRegion, Bool), Never>()
    private let authorizationSubject = PassthroughSubject<CLAuthorizationStatus, Never>()
    private let locationSubject = PassthroughSubject<CLLocation, Never>()
    private let regionEntrySubject = PassthroughSubject<CLRegion, Never>()
    private let errorSubject = PassthroughSubject<Error, Never>()
    
    // Keep track of notification observers
    private var notificationObserver: NSObjectProtocol?
    
    var currentLocationPublisher: AnyPublisher<CLLocation, Never> {
        return currentLocationSubject.eraseToAnyPublisher()
    }
    
    var regionStateChangePublisher: AnyPublisher<(CLRegion, Bool), Never> {
        return regionStateChangeSubject.eraseToAnyPublisher()
    }
    
    var authorizationPublisher: AnyPublisher<CLAuthorizationStatus, Never> {
        return authorizationSubject.eraseToAnyPublisher()
    }
    
    // These are for backward compatibility
    var locationPublisher: PassthroughSubject<CLLocation, Never> { return locationSubject }
    var regionsPublisher: PassthroughSubject<[CLRegion], Never> = PassthroughSubject<[CLRegion], Never>()
    var regionStatePublisher: PassthroughSubject<(CLRegion, Bool), Never> = PassthroughSubject<(CLRegion, Bool), Never>()
    var memoryDetectionPublisher: PassthroughSubject<Reminiscence.MemoryItem, Never> = PassthroughSubject<Reminiscence.MemoryItem, Never>()
    
    // MARK: - Initialization
    
    private override init() {
        // Create a fresh instance of the location manager
        self.locationManager = SpatialLocationManager()
        super.init()
        
        // Set the delegate to self to receive location updates and authorization changes
        locationManager.delegate = self
        
        // Set the purpose strings from Info.plist to improve permission dialog experience
        // Note: These must also be defined in Info.plist
        
        // Additional configuration
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        // Subscribe to authorization changes from the global manager
        notificationObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("LocationAuthorizationChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let status = userInfo["status"] as? CLAuthorizationStatus else { 
                return 
            }
            
            print("LOCATION SERVICE: Received notification of authorization change to: \(status)")
            self.authorizationSubject.send(status)
            
            // Start updates if we have permission
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.startLocationUpdates()
            }
        }
        
        // If we're using the simulator, set a default location
        #if targetEnvironment(simulator)
        // Create a default location for simulator testing
        let defaultLocation: CLLocation? = CLLocationManager.locationServicesEnabled() ? nil : CLLocation(latitude: 37.7749, longitude: -122.4194)
        if let location = defaultLocation {
            lastLocation = location
            locationSubject.send(location)
        }
        #endif
    }
    
    deinit {
        // Remove observer when this object is deallocated
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Public Methods
    
    func requestLocationPermission() {
        print("LOCATION SERVICE: Explicitly requesting location permission - DELEGATING TO APP MANAGER")
        // Instead of directly requesting, post a notification for the app manager to handle
        NotificationCenter.default.post(name: Notification.Name("RequestLocationPermission"), object: nil)
    }
    
    func configureLocationManager(highAccuracy: Bool = false) {
        if highAccuracy {
            // High accuracy mode - use when actively using the app
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.distanceFilter = 10 // meters
        } else {
            // Battery-saving mode - use for background monitoring
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            locationManager.distanceFilter = 50 // meters
        }
        locationManager.pausesLocationUpdatesAutomatically = !highAccuracy
    }
    
    func startLocationUpdates() {
        // Check if location services are enabled at the device level
        if CLLocationManager.locationServicesEnabled() {
            print("Starting location updates")
            
            // First, determine the current authorization status
            let authStatus = CLLocationManager.authorizationStatus()
            
            if authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways {
                // We have permission, start updates
                locationManager.startUpdatingLocation()
                
                // If we have 'always' permission, enable background updates
                if authStatus == .authorizedAlways {
                    locationManager.allowsBackgroundLocationUpdates = true
                    locationManager.showsBackgroundLocationIndicator = true
                }
            } else if authStatus == .notDetermined {
                // We don't have permission yet, request it
                requestLocationPermission()
            } else {
                // Permission denied or restricted, notify user
                print("Cannot start location updates: authorization status is \(authStatus)")
                
                // For testing, we might want to provide a default location
                #if DEBUG
                // Create a default location if we don't have one already
                if lastLocation == nil {
                    let defaultLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
                    lastLocation = defaultLocation
                    locationSubject.send(defaultLocation)
                }
                #endif
            }
        } else {
            print("Location services are disabled at the device level")
        }
    }
    
    func startMonitoringSignificantLocationChanges() {
        if !isMonitoringSignificantLocationChanges {
            locationManager.startMonitoringSignificantLocationChanges()
            isMonitoringSignificantLocationChanges = true
        }
    }
    
    func stopMonitoringSignificantLocationChanges() {
        if isMonitoringSignificantLocationChanges {
            locationManager.stopMonitoringSignificantLocationChanges()
            isMonitoringSignificantLocationChanges = false
        }
    }
    
    func startStandardLocationUpdates() {
        locationManager.startUpdatingLocation()
    }
    
    func stopStandardLocationUpdates() {
        locationManager.stopUpdatingLocation()
    }
    
    // MARK: - Memory Geofencing
    
    // Methods renamed to match ViewModel usage
    func createMemoryGeofence(for memory: Reminiscence.MemoryItem, radius: CLLocationDistance? = nil) -> Bool {
        guard let memoryId = memory.id?.uuidString else { return false }
        
        let memoryLocation = CLLocationCoordinate2D(latitude: memory.latitude, longitude: memory.longitude)
        let actualRadius = radius ?? geofenceRadius
        
        // Create a circular region
        let region = CLCircularRegion(center: memoryLocation, radius: actualRadius, identifier: memoryId)
        region.notifyOnEntry = true
        region.notifyOnExit = true
        
        // Start monitoring the region
        locationManager.startMonitoring(for: region)
        
        // Store the region for reference
        memoryRegions[memoryId] = region
        return true
    }
    
    func stopMonitoringMemory(_ memory: Reminiscence.MemoryItem) {
        guard let memoryId = memory.id?.uuidString else { return }
        
        if let region = memoryRegions[memoryId] {
            locationManager.stopMonitoring(for: region)
            memoryRegions.removeValue(forKey: memoryId)
        }
    }
    
    // Original methods for backward compatibility
    func addGeofenceForMemory(_ memory: Reminiscence.MemoryItem, radius: CLLocationDistance? = nil) {
        _ = createMemoryGeofence(for: memory, radius: radius)
    }
    
    func removeGeofenceForMemory(_ memory: Reminiscence.MemoryItem) {
        stopMonitoringMemory(memory)
    }
    
    func updateGeofenceRadius(_ radius: CLLocationDistance) {
        self.geofenceRadius = radius
    }
    
    // MARK: - SpatialLocationDelegate Methods
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        lastLocation = location
        locationSubject.send(location)
        locationPublisher.send(location)
        
        // Record the visit
        CoreDataStack.shared.recordVisit(at: location)
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if let circularRegion = region as? CLCircularRegion {
            regionStatePublisher.send((circularRegion, true))
            regionEntrySubject.send(region)
            
            // Find the memory associated with this region
            if let memoryId = UUID(uuidString: circularRegion.identifier) {
                let fetchRequest: NSFetchRequest<Reminiscence.MemoryItem> = Reminiscence.MemoryItem.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", memoryId as CVarArg)
                
                do {
                    let results = try CoreDataStack.shared.persistentContainer.viewContext.fetch(fetchRequest)
                    if let memory = results.first {
                        // Publish the memory that was detected
                        memoryDetectionPublisher.send(memory)
                        
                        // Optionally send a local notification
                        sendMemoryNotification(memory)
                    }
                } catch {
                    print("Error fetching memory for region: \(error)")
                    errorSubject.send(error)
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        if let circularRegion = region as? CLCircularRegion {
            regionStatePublisher.send((circularRegion, false))
        }
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("Monitoring failed for region with identifier: \(region?.identifier ?? "unknown")")
        print("Error: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("LOCATION SERVICE: Authorization status changed to: \(status)")
        
        // Publish the change to subscribers
        authorizationSubject.send(status)
        
        // Take action based on new status
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            print("LOCATION SERVICE: Got permission - starting location updates")
            
            // Start location updates since we have permission
            self.startLocationUpdates()
            
            // Enable background updates if we have 'always' permission
            if status == .authorizedAlways {
                print("LOCATION SERVICE: Enabling background location updates")
                locationManager.allowsBackgroundLocationUpdates = true
                locationManager.showsBackgroundLocationIndicator = true
            }
        } else if status == .denied || status == .restricted {
            print("LOCATION SERVICE: Permission denied/restricted - providing default location")
            
            // Provide a default location for testing
            #if DEBUG
            if lastLocation == nil {
                let defaultLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
                lastLocation = defaultLocation
                locationSubject.send(defaultLocation)
                currentLocationSubject.send(defaultLocation)
            }
            #endif
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error.localizedDescription)")
        errorSubject.send(error)
    }
    
    // MARK: - Private Helpers
    
    private func sendMemoryNotification(_ memory: Reminiscence.MemoryItem) {
        let content = UNMutableNotificationContent()
        content.title = "Memory Nearby"
        content.body = "You're near: \(memory.title ?? "A memory")"
        content.sound = UNNotificationSound.default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - SpatialLocationDelegate
    func didUpdateToLocation(_ location: CLLocation) {
        currentLocationSubject.send(location)
    }
    
    func didEnterRegion(_ region: CLRegion) {
        regionStateChangeSubject.send((region, true))
    }
    
    func didExitRegion(_ region: CLRegion) {
        regionStateChangeSubject.send((region, false))
    }
    
    func locationAuthorizationDidChange(_ status: CLAuthorizationStatus) {
        authorizationSubject.send(status)
    }
    
    func spatialLocationManager(_ manager: Any, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        authorizationSubject.send(status)
        // No need to set allowsBackgroundLocationUpdates here as it's now handled in Objective-C
    }
    
    func didFailWithError(_ error: Error) {
        print("Location service error: \(error.localizedDescription)")
    }
} 