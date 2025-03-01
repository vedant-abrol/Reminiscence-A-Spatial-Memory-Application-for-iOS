//
//  Tag+Manual.swift
//  Reminiscence
//
//  Created for Spatial Memory App
//

import Foundation
import CoreData
import SwiftUI

@objc(Tag)
public class Tag: NSManagedObject, Identifiable {
    @NSManaged public var color: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var memories: NSSet?
    
    // Basic fetch request
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Reminiscence.Tag> {
        return NSFetchRequest<Reminiscence.Tag>(entityName: "Tag")
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
        if self.name == nil {
            self.name = "New Tag"
        }
        if self.color == nil {
            self.color = "blue"
        }
    }
}

// MARK: Generated accessors for memories
extension Reminiscence.Tag {
    @objc(addMemoriesObject:)
    @NSManaged public func addToMemories(_ value: Reminiscence.MemoryItem)
    
    @objc(removeMemoriesObject:)
    @NSManaged public func removeFromMemories(_ value: Reminiscence.MemoryItem)
    
    @objc(addMemories:)
    @NSManaged public func addToMemories(_ values: NSSet)
    
    @objc(removeMemories:)
    @NSManaged public func removeFromMemories(_ values: NSSet)
} 