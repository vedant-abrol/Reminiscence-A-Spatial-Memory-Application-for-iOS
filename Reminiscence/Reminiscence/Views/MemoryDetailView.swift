//
//  MemoryDetailView.swift
//  Reminiscence
//
//  Created for Spatial Memory App
//

import SwiftUI
import MapKit
import AVKit

struct MemoryDetailView: View {
    @EnvironmentObject var viewModel: MemoryViewModel
    @Environment(\.dismiss) private var dismiss
    
    let memory: MemoryItem
    
    @State private var isEditing = false
    @State private var editedTitle = ""
    @State private var editedContent = ""
    @State private var showDeleteConfirmation = false
    @State private var showTagsSheet = false
    
    // Map region centered on memory location
    @State private var region: MKCoordinateRegion
    
    init(memory: MemoryItem) {
        self.memory = memory
        
        // Initialize the map region centered on the memory location
        _region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: memory.latitude, longitude: memory.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        ))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Map showing the memory location
                    Map(coordinateRegion: $region, annotationItems: [memory]) { item in
                        MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: item.latitude, longitude: item.longitude)) {
                            MemoryAnnotationView(memory: item)
                        }
                    }
                    .frame(height: 200)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Memory content
                    VStack(alignment: .leading, spacing: 16) {
                        if isEditing {
                            // Edit mode
                            TextField("Title", text: $editedTitle)
                                .font(.title)
                                .padding(.horizontal)
                            
                            if memory.contentType == "text" {
                                TextEditor(text: $editedContent)
                                    .frame(minHeight: 100)
                                    .padding(.horizontal)
                            } else {
                                TextField("Caption/Description", text: $editedContent)
                                    .padding(.horizontal)
                            }
                        } else {
                            // View mode
                            Text(memory.title ?? "Untitled Memory")
                                .font(.title)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            // Show creation date
                            if let date = memory.createdAt {
                                Text(date, style: .date)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                            }
                            
                            // Media content based on type
                            if memory.contentType == "photo", let mediaPath = memory.mediaPath {
                                DisplayPhotoMemory(path: mediaPath)
                            } else if memory.contentType == "audio", let mediaPath = memory.mediaPath {
                                DisplayAudioMemory(path: mediaPath)
                            }
                            
                            // Text content
                            if let content = memory.contentText, !content.isEmpty {
                                Text(content)
                                    .padding(.horizontal)
                            }
                            
                            // Tags
                            if let tags = memory.tags as? Set<Tag>, !tags.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack {
                                        ForEach(Array(tags), id: \.self) { tag in
                                            TagView(tag: tag)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(.vertical)
            }
            .navigationBarTitle("", displayMode: .inline)
            .navigationBarItems(
                leading: Button(action: { dismiss() }) {
                    Text("Back")
                },
                trailing: HStack {
                    if isEditing {
                        Button("Save") {
                            saveChanges()
                        }
                    } else {
                        Menu {
                            Button(action: {
                                editedTitle = memory.title ?? ""
                                editedContent = memory.contentText ?? ""
                                isEditing = true
                            }) {
                                Label("Edit", systemImage: "pencil")
                            }
                            
                            Button(action: {
                                showTagsSheet = true
                            }) {
                                Label("Manage Tags", systemImage: "tag")
                            }
                            
                            Button(action: {
                                showDeleteConfirmation = true
                            }) {
                                Label("Delete", systemImage: "trash")
                                    .foregroundColor(.red)
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            )
            .alert("Delete Memory", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    viewModel.deleteMemory(memory)
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to delete this memory? This action cannot be undone.")
            }
            .sheet(isPresented: $showTagsSheet) {
                TagManagementView(memory: memory)
                    .environmentObject(viewModel)
            }
        }
    }
    
    private func saveChanges() {
        viewModel.updateMemory(memory, title: editedTitle, content: editedContent)
        isEditing = false
    }
}

// MARK: - Helper Views

struct DisplayPhotoMemory: View {
    let path: String
    
    var body: some View {
        if let image = UIImage(contentsOfFile: path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .cornerRadius(12)
                .padding(.horizontal)
        } else {
            Text("Unable to load image")
                .foregroundColor(.red)
                .padding()
        }
    }
}

struct DisplayAudioMemory: View {
    let path: String
    
    var body: some View {
        let url = URL(fileURLWithPath: path)
        AudioPlayerView(url: url)
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
    }
}

struct TagView: View {
    let tag: Tag
    
    var body: some View {
        Text(tag.name ?? "")
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tagColor.opacity(0.2))
            .foregroundColor(tagColor)
            .cornerRadius(20)
    }
    
    private var tagColor: Color {
        switch tag.color {
        case "red":
            return .red
        case "green":
            return .green
        case "blue":
            return .blue
        case "purple":
            return .purple
        case "orange":
            return .orange
        default:
            return .blue
        }
    }
}

// MARK: - Tag Management View

struct TagManagementView: View {
    @EnvironmentObject var viewModel: MemoryViewModel
    @Environment(\.dismiss) private var dismiss
    
    let memory: MemoryItem
    @State private var newTagName = ""
    @State private var selectedColor = "blue"
    
    private let colors = ["blue", "green", "red", "purple", "orange"]
    
    var body: some View {
        NavigationView {
            VStack {
                // Create new tag
                HStack {
                    TextField("New tag name", text: $newTagName)
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                    
                    Picker("", selection: $selectedColor) {
                        ForEach(colors, id: \.self) { color in
                            Circle()
                                .fill(colorFromString(color))
                                .frame(width: 20, height: 20)
                                .tag(color)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    Button(action: createTag) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                    .disabled(newTagName.isEmpty)
                }
                .padding()
                
                // Current tags
                Text("Current Tags")
                    .font(.headline)
                    .padding(.top)
                
                // List of all tags with selection state
                List {
                    ForEach(viewModel.tags, id: \.self) { tag in
                        HStack {
                            Circle()
                                .fill(colorFromString(tag.color ?? "blue"))
                                .frame(width: 12, height: 12)
                            
                            Text(tag.name ?? "")
                            
                            Spacer()
                            
                            if memoryHasTag(tag) {
                                Button(action: {
                                    removeTagFromMemory(tag)
                                }) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            } else {
                                Button(action: {
                                    addTagToMemory(tag)
                                }) {
                                    Image(systemName: "circle")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Manage Tags")
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
    
    private func colorFromString(_ colorName: String) -> Color {
        switch colorName {
        case "red":
            return .red
        case "green":
            return .green
        case "blue":
            return .blue
        case "purple":
            return .purple
        case "orange":
            return .orange
        default:
            return .blue
        }
    }
    
    private func createTag() {
        let newTag = viewModel.createTag(name: newTagName, color: selectedColor)
        viewModel.addTagToMemory(newTag, memory: memory)
        newTagName = ""
    }
    
    private func memoryHasTag(_ tag: Tag) -> Bool {
        guard let memoryTags = memory.tags as? Set<Tag> else {
            return false
        }
        return memoryTags.contains(tag)
    }
    
    private func addTagToMemory(_ tag: Tag) {
        viewModel.addTagToMemory(tag, memory: memory)
    }
    
    private func removeTagFromMemory(_ tag: Tag) {
        viewModel.removeTagFromMemory(tag, memory: memory)
    }
}

// MARK: - Preview

struct MemoryDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let context = CoreDataStack.shared.persistentContainer.viewContext
        let memory = MemoryItem(context: context)
        memory.id = UUID()
        memory.title = "Sample Memory"
        memory.contentText = "This is a sample memory for preview purposes."
        memory.latitude = 37.7749
        memory.longitude = -122.4194
        memory.createdAt = Date()
        memory.modifiedAt = Date()
        memory.contentType = "text"
        
        return MemoryDetailView(memory: memory)
            .environmentObject(MemoryViewModel())
    }
} 