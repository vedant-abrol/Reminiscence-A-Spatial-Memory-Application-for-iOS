//
//  CoreDataStack.swift
//  Reminiscence
//
//  Created for Spatial Memory App
//

import Foundation
import CoreData
import Combine
import CoreLocation

class CoreDataStack {
    static let shared = CoreDataStack()
    
    // MARK: - Core Data stack
    
    lazy var persistentContainer: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "SpatialMemory")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        
        // Configure the container for background operations
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    // MARK: - Core Data Saving support
    
    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
    // MARK: - Convenience Methods
    
    func createBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    // MARK: - MemoryItem Methods
    
    func createMemory(title: String, contentText: String? = nil, contentType: String = "text", 
                     latitude: Double, longitude: Double, mediaPath: String? = nil,
                     tags: [Reminiscence.Tag] = [], context: NSManagedObjectContext? = nil) -> Reminiscence.MemoryItem {
        
        let ctx = context ?? persistentContainer.viewContext
        
        let memory = Reminiscence.MemoryItem(context: ctx)
        memory.id = UUID()
        memory.title = title
        memory.contentText = contentText
        memory.contentType = contentType
        memory.latitude = latitude
        memory.longitude = longitude
        memory.mediaPath = mediaPath
        memory.createdAt = Date()
        memory.modifiedAt = Date()
        memory.isFavorite = false
        
        // Add tags if any
        for tag in tags {
            memory.addToTags(tag)
        }
        
        if context == nil {
            saveContext()
        }
        
        return memory
    }
    
    func fetchMemories(near location: CLLocation, radius: Double, context: NSManagedObjectContext? = nil) -> [Reminiscence.MemoryItem] {
        let ctx = context ?? persistentContainer.viewContext
        
        let request: NSFetchRequest<Reminiscence.MemoryItem> = Reminiscence.MemoryItem.fetchRequest()
        
        // No direct way to filter by distance in Core Data, so we fetch all and filter
        do {
            let allMemories = try ctx.fetch(request)
            
            // Filter memories within the radius
            return allMemories.filter { memory in
                let memoryLocation = CLLocation(latitude: memory.latitude, longitude: memory.longitude)
                let distance = location.distance(from: memoryLocation)
                return distance <= radius
            }
        } catch {
            print("Error fetching memories: \(error)")
            return []
        }
    }
    
    func fetchMemories(withTag tag: Reminiscence.Tag, context: NSManagedObjectContext? = nil) -> [Reminiscence.MemoryItem] {
        let ctx = context ?? persistentContainer.viewContext
        
        let request: NSFetchRequest<Reminiscence.MemoryItem> = Reminiscence.MemoryItem.fetchRequest()
        request.predicate = NSPredicate(format: "ANY tags == %@", tag)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        do {
            return try ctx.fetch(request)
        } catch {
            print("Error fetching memories with tag: \(error)")
            return []
        }
    }
    
    // MARK: - Tag Methods
    
    func createTag(name: String, color: String? = nil, context: NSManagedObjectContext? = nil) -> Reminiscence.Tag {
        let ctx = context ?? persistentContainer.viewContext
        
        let tag = Reminiscence.Tag(context: ctx)
        tag.id = UUID()
        tag.name = name
        tag.color = color ?? "blue"
        tag.createdAt = Date()
        
        if context == nil {
            saveContext()
        }
        
        return tag
    }
    
    func fetchAllTags(context: NSManagedObjectContext? = nil) -> [Reminiscence.Tag] {
        let ctx = context ?? persistentContainer.viewContext
        
        let request: NSFetchRequest<Reminiscence.Tag> = Reminiscence.Tag.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            return try ctx.fetch(request)
        } catch {
            print("Error fetching tags: \(error)")
            return []
        }
    }
    
    // MARK: - VisitRecord Methods
    
    func recordVisit(at location: CLLocation, memory: Reminiscence.MemoryItem? = nil, context: NSManagedObjectContext? = nil) {
        let ctx = context ?? persistentContainer.viewContext
        
        let visit = Reminiscence.VisitRecord(context: ctx)
        visit.id = UUID()
        visit.latitude = location.coordinate.latitude
        visit.longitude = location.coordinate.longitude
        visit.timestamp = Date()
        visit.memory = memory
        
        if context == nil {
            saveContext()
        }
    }
    
    func fetchRecentVisits(limit: Int = 100, context: NSManagedObjectContext? = nil) -> [Reminiscence.VisitRecord] {
        let ctx = context ?? persistentContainer.viewContext
        
        let request: NSFetchRequest<Reminiscence.VisitRecord> = Reminiscence.VisitRecord.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        request.fetchLimit = limit
        
        do {
            return try ctx.fetch(request)
        } catch {
            print("Error fetching recent visits: \(error)")
            return []
        }
    }
}

// MARK: - CoreDataManaging Protocol
protocol CoreDataManaging {
    var persistentContainer: NSPersistentCloudKitContainer { get }
    func saveContext()
    func createMemory(title: String, contentText: String?, contentType: String, 
                     latitude: Double, longitude: Double, mediaPath: String?,
                     tags: [Reminiscence.Tag], context: NSManagedObjectContext?) -> Reminiscence.MemoryItem
    func fetchMemories(near location: CLLocation, radius: Double, context: NSManagedObjectContext?) -> [Reminiscence.MemoryItem]
    func fetchMemories(withTag tag: Reminiscence.Tag, context: NSManagedObjectContext?) -> [Reminiscence.MemoryItem]
    func createTag(name: String, color: String?, context: NSManagedObjectContext?) -> Reminiscence.Tag
    func recordVisit(at location: CLLocation, memory: Reminiscence.MemoryItem?, context: NSManagedObjectContext?)
}

// Make CoreDataStack conform to CoreDataManaging
extension CoreDataStack: CoreDataManaging {} 