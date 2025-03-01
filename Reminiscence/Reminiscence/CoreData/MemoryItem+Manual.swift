//
//  MemoryItem+Manual.swift
//  Reminiscence
//
//  Created for Spatial Memory App
//

import Foundation
import CoreData
import SwiftUI

@objc(MemoryItem)
public class MemoryItem: NSManagedObject, Identifiable {
    @NSManaged public var contentText: String?
    @NSManaged public var contentType: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var isFavorite: Bool
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var mediaPath: String?
    @NSManaged public var modifiedAt: Date?
    @NSManaged public var title: String?
    @NSManaged public var tags: NSSet?
    @NSManaged public var visitRecords: NSSet?
    
    // Basic fetch request
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Reminiscence.MemoryItem> {
        return NSFetchRequest<Reminiscence.MemoryItem>(entityName: "MemoryItem")
    }
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        
        // Set required default values
        if self.id == nil {
            self.id = UUID()
        }
        if self.createdAt == nil {
            self.createdAt = Date()
        }
        if self.modifiedAt == nil {
            self.modifiedAt = Date()
        }
        if self.contentType == nil {
            self.contentType = "text"
        }
        if self.title == nil {
            self.title = ""
        }
        self.isFavorite = false
    }
}

// MARK: Generated accessors for tags
extension Reminiscence.MemoryItem {
    @objc(addTagsObject:)
    @NSManaged public func addToTags(_ value: Reminiscence.Tag)
    
    @objc(removeTagsObject:)
    @NSManaged public func removeFromTags(_ value: Reminiscence.Tag)
    
    @objc(addTags:)
    @NSManaged public func addToTags(_ values: NSSet)
    
    @objc(removeTags:)
    @NSManaged public func removeFromTags(_ values: NSSet)
}

// MARK: Generated accessors for visitRecords
extension Reminiscence.MemoryItem {
    @objc(addVisitRecordsObject:)
    @NSManaged public func addToVisitRecords(_ value: Reminiscence.VisitRecord)
    
    @objc(removeVisitRecordsObject:)
    @NSManaged public func removeFromVisitRecords(_ value: Reminiscence.VisitRecord)
    
    @objc(addVisitRecords:)
    @NSManaged public func addToVisitRecords(_ values: NSSet)
    
    @objc(removeVisitRecords:)
    @NSManaged public func removeFromVisitRecords(_ values: NSSet)
} 