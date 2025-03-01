//
//  VisitRecord+Manual.swift
//  Reminiscence
//
//  Created for Spatial Memory App
//

import Foundation
import CoreData
import SwiftUI

@objc(VisitRecord)
public class VisitRecord: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var timestamp: Date?
    @NSManaged public var memory: Reminiscence.MemoryItem?
    
    // Basic fetch request
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Reminiscence.VisitRecord> {
        return NSFetchRequest<Reminiscence.VisitRecord>(entityName: "VisitRecord")
    }
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        
        // Set required default values
        if self.id == nil {
            self.id = UUID()
        }
        if self.timestamp == nil {
            self.timestamp = Date()
        }
    }
    
    // Ensure memory relationship is properly set up
    public func setMemory(_ memory: Reminiscence.MemoryItem?) {
        self.memory = memory
        if let memory = memory {
            memory.addToVisitRecords(self)
        }
    }
} 