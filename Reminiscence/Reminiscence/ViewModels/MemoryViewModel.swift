//
//  MemoryViewModel.swift
//  Reminiscence
//
//  Created for Spatial Memory App
//

import Foundation
import Combine
import CoreLocation
import CoreData
import SwiftUI
import Reminiscence

class MemoryViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var memories: [MemoryItem] = []
    @Published var nearbyMemories: [MemoryItem] = []
    @Published var selectedMemory: MemoryItem?
    @Published var tags: [Tag] = []
    @Published var currentLocation: CLLocation?
    @Published var locationAuthStatus: CLAuthorizationStatus = .notDetermined
    @Published var isCreatingMemory = false
    @Published var isShowingMemoryDetail = false
    @Published var alertMessage: String?
    @Published var showAlert = false
    @Published var memoryHeatmap: [LocationCoordinate: Int] = [:]
    @Published var isLoadingData = false
    @Published var filterTag: Tag?
    @Published var searchTerm: String = ""
    
    // MARK: - Services
    
    private lazy var locationService = LocationService.shared // Make lazy to defer initialization
    private let coreDataStack = CoreDataStack.shared
    private var dataManager: CoreDataManaging
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let nearbyRadius: Double = 300.0 // meters
    
    // MARK: - Initialization
    
    init(dataManager: CoreDataManaging = CoreDataStack.shared) {
        self.dataManager = dataManager
        
        // Setup core data first
        setupSubscriptions()
        loadInitialData()
        
        // Set up location service subscriptions after a short delay
        // This helps avoid startup crashes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.setupLocationSubscriptions()
        }
    }
    
    // Setup location subscriptions separately to avoid startup crashes
    func setupLocationSubscriptions() {
        // Set up location service subscriptions
        locationService.currentLocationPublisher
            .sink { [weak self] location in
                self?.handleLocationUpdate(location)
            }
            .store(in: &cancellables)
        
        locationService.regionStateChangePublisher
            .sink { [weak self] region, didEnter in
                if didEnter {
                    self?.handleRegionEntry(region)
                } else {
                    self?.handleRegionExit(region)
                }
            }
            .store(in: &cancellables)
        
        locationService.authorizationPublisher
            .sink { [weak self] status in
                self?.handleAuthorizationChange(status)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Setup Methods
    
    private func setupSubscriptions() {
        // Location service subscriptions are now in the initializer
        
        // Subscribe to filter changes
        $filterTag
            .sink { [weak self] tag in
                self?.filterMemories()
            }
            .store(in: &cancellables)
        
        // Subscribe to search term changes
        $searchTerm
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.filterMemories()
            }
            .store(in: &cancellables)
    }
    
    private func loadInitialData() {
        isLoadingData = true
        
        let context = coreDataStack.persistentContainer.viewContext
        
        // Load all memories
        let memoryRequest: NSFetchRequest<MemoryItem> = MemoryItem.fetchRequest()
        memoryRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        // Load all tags
        let tagRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        tagRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            memories = try context.fetch(memoryRequest)
            tags = try context.fetch(tagRequest)
            generateHeatmap()
            isLoadingData = false
        } catch {
            print("Error loading initial data: \(error)")
            alertMessage = "Failed to load memories: \(error.localizedDescription)"
            showAlert = true
            isLoadingData = false
        }
    }
    
    // MARK: - Location Handlers
    
    private func handleLocationUpdate(_ location: CLLocation) {
        // Update the current location
        currentLocation = location
        updateNearbyMemories()
    }
    
    private func updateNearbyMemories() {
        guard let location = currentLocation else { return }
        nearbyMemories = coreDataStack.fetchMemories(near: location, radius: nearbyRadius)
    }
    
    private func handleRegionEntry(_ region: CLRegion) {
        guard let identifier = region.identifier.components(separatedBy: "-").first,
              let memoryID = UUID(uuidString: identifier) else {
            return
        }
        
        // Find the memory that triggered this region entry
        guard let memory = memories.first(where: { $0.id?.uuidString == identifier }) else {
            return
        }
        
        // Record visit
        addVisitToMemory(memory)
        
        // Show notification
        showNotification(for: memory)
        
        // Update UI
        selectedMemory = memory
        isShowingMemoryDetail = true
    }
    
    private func handleRegionExit(_ region: CLRegion) {
        // Optionally handle region exit events
    }
    
    private func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
        // Update the UI with the current authorization status
        locationAuthStatus = status
        
        // If authorization is granted, start updates and request high accuracy
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            locationService.configureLocationManager(highAccuracy: true)
            locationService.startLocationUpdates()
        }
    }
    
    private func addVisitToMemory(_ memory: MemoryItem) {
        // Create a visit record for this memory
        if let location = currentLocation {
            coreDataStack.recordVisit(at: location, memory: memory)
        }
    }
    
    private func showNotification(for memory: MemoryItem) {
        // Display a notification to the user
        let title = "Memory Nearby"
        let body = "You're near: \(memory.title ?? "A memory")"
        
        alertMessage = body
        showAlert = true
        
        // In a real app, you would use UNUserNotificationCenter for proper notifications
        // This is simplified for the example
    }
    
    // MARK: - Memory Management
    
    func createMemory(title: String, content: String, mediaPath: String? = nil, contentType: String = "text") {
        guard let location = currentLocation else {
            alertMessage = "Cannot create memory: location is unavailable"
            showAlert = true
            return
        }
        
        // Re-enable all memory types
        let memory = coreDataStack.createMemory(
            title: title,
            contentText: content,
            contentType: contentType,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            mediaPath: mediaPath  // Re-enable media support
        )
        
        // Add to our list
        memories.insert(memory, at: 0)
        
        // Set up geofence for this memory
        _ = locationService.createMemoryGeofence(for: memory)
        
        // Update heatmap
        addToHeatmap(coordinate: location.coordinate)
        
        isCreatingMemory = false
    }
    
    func deleteMemory(_ memory: MemoryItem) {
        // Remove geofence
        locationService.stopMonitoringMemory(memory)
        
        // Remove from Core Data
        let context = coreDataStack.persistentContainer.viewContext
        context.delete(memory)
        
        do {
            try context.save()
            
            // Update the view model state
            if let index = memories.firstIndex(of: memory) {
                memories.remove(at: index)
            }
            
            if let index = nearbyMemories.firstIndex(of: memory) {
                nearbyMemories.remove(at: index)
            }
            
            if selectedMemory == memory {
                selectedMemory = nil
                isShowingMemoryDetail = false
            }
            
            // Update heatmap
            generateHeatmap()
            
        } catch {
            alertMessage = "Failed to delete memory: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    func updateMemory(_ memory: MemoryItem, title: String, content: String) {
        memory.title = title
        memory.contentText = content
        memory.modifiedAt = Date()
        
        do {
            try coreDataStack.persistentContainer.viewContext.save()
            
            // Force UI to update by updating the lists
            loadInitialData()
            
        } catch {
            alertMessage = "Failed to update memory: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    // MARK: - Tag Management
    
    func createTag(name: String, color: String = "blue") -> Tag {
        return coreDataStack.createTag(name: name, color: color)
    }
    
    func addTagToMemory(_ tag: Tag, memory: MemoryItem) {
        memory.addToTags(tag)
        
        do {
            try coreDataStack.persistentContainer.viewContext.save()
        } catch {
            alertMessage = "Failed to add tag: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    func removeTagFromMemory(_ tag: Tag, memory: MemoryItem) {
        memory.removeFromTags(tag)
        
        do {
            try coreDataStack.persistentContainer.viewContext.save()
        } catch {
            alertMessage = "Failed to remove tag: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    // MARK: - Location Permission
    
    func requestLocationPermission() {
        // Show an alert to guide users on enabling location permissions
        // This happens before actually requesting to prepare them
        if CLLocationManager.authorizationStatus() == .notDetermined {
            // First time asking - show system dialog
            LocationService.shared.requestLocationPermission()
        } else if CLLocationManager.authorizationStatus() == .denied || 
                  CLLocationManager.authorizationStatus() == .restricted {
            // Permission previously denied - show custom alert with instructions
            self.alertMessage = "Location access is required for creating memories. Please go to Settings > Privacy > Location Services > Reminiscence and select 'While Using the App'."
            self.showAlert = true
        } else {
            // Authorization already granted or permission request already shown
            LocationService.shared.startLocationUpdates()
        }
    }
    
    // Public method to start location updates (to avoid direct access to private locationService)
    func startLocationUpdates() {
        LocationService.shared.startLocationUpdates()
    }
    
    // MARK: - Heatmap Generation
    
    private func generateHeatmap() {
        memoryHeatmap.removeAll()
        
        for memory in memories {
            let coordinate = CLLocationCoordinate2D(latitude: memory.latitude, longitude: memory.longitude)
            addToHeatmap(coordinate: coordinate)
        }
    }
    
    private func addToHeatmap(coordinate: CLLocationCoordinate2D) {
        let key = coordinate.hashableCoordinate
        memoryHeatmap[key] = (memoryHeatmap[key] ?? 0) + 1
    }
    
    // Function to directly access heatmap value for a coordinate if needed from views
    func heatmapValue(for coordinate: CLLocationCoordinate2D) -> Int {
        return memoryHeatmap[coordinate.hashableCoordinate] ?? 0
    }
    
    // MARK: - Search and Filtering
    
    func searchMemories(query: String) -> [MemoryItem] {
        if query.isEmpty {
            return memories
        }
        
        return memories.filter { memory in
            let titleMatch = memory.title?.localizedCaseInsensitiveContains(query) ?? false
            let contentMatch = memory.contentText?.localizedCaseInsensitiveContains(query) ?? false
            return titleMatch || contentMatch
        }
    }
    
    func filterMemoriesByTag(_ tag: Tag) -> [MemoryItem] {
        return coreDataStack.fetchMemories(withTag: tag)
    }
    
    private func filterMemories() {
        if let tag = filterTag {
            memories = filterMemoriesByTag(tag)
        } else {
            memories = searchMemories(query: searchTerm)
        }
        generateHeatmap()
    }
}

// MARK: - Extension for providing CLLocationCoordinate2D support 
extension MemoryViewModel {
    // Helper to convert back to CLLocationCoordinate2D for use with MapKit
    // Returns array of tuples instead of a dictionary to avoid Hashable requirement
    public func heatmapCoordinates() -> [(coordinate: CLLocationCoordinate2D, intensity: Int)] {
        var result = [(coordinate: CLLocationCoordinate2D, intensity: Int)]()
        for (hashableCoord, count) in memoryHeatmap {
            result.append((coordinate: hashableCoord.coordinate, intensity: count))
        }
        return result
    }
} 