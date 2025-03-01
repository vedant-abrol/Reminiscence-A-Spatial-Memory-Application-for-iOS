//
//  CreateMemoryView.swift
//  Reminiscence
//
//  Created for Spatial Memory App
//

import SwiftUI
import PhotosUI

struct CreateMemoryView: View {
    @EnvironmentObject var viewModel: MemoryViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var content = ""
    @State private var memoryType = "text"
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImageData: Data?
    
    private let memoryTypes = ["text", "photo"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Memory Type")) {
                    Picker("Type", selection: $memoryType) {
                        Text("Text").tag("text")
                        Text("Photo").tag("photo")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Title")) {
                    TextField("Enter a title for your memory", text: $title)
                }
                
                // Dynamic content section based on selected type
                Section(header: Text("Content")) {
                    if memoryType == "text" {
                        TextEditor(text: $content)
                            .frame(minHeight: 100)
                    } else if memoryType == "photo" {
                        VStack {
                            if let selectedImageData, let image = UIImage(data: selectedImageData) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 300)
                            } else {
                                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                    Label("Select a Photo", systemImage: "photo")
                                }
                                .onChange(of: selectedPhoto) { newValue in
                                    Task {
                                        if let data = try? await newValue?.loadTransferable(type: Data.self) {
                                            selectedImageData = data
                                        }
                                    }
                                }
                            }
                            
                            if selectedImageData != nil {
                                Button("Remove Photo") {
                                    selectedImageData = nil
                                    selectedPhoto = nil
                                }
                                .foregroundColor(.red)
                            }
                            
                            TextField("Add a caption (optional)", text: $content)
                        }
                    }
                }
                
                Section {
                    if let location = viewModel.currentLocation {
                        Text("Memory will be saved at your current location")
                            .foregroundColor(.secondary)
                    } else {
                        Text("Waiting for location...")
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    Button("Save Memory") {
                        saveMemory()
                    }
                    .disabled(title.isEmpty || viewModel.currentLocation == nil || 
                             (memoryType == "photo" && selectedImageData == nil))
                }
            }
            .navigationTitle("Create Memory")
            .navigationBarItems(trailing: Button("Cancel") {
                dismiss()
            })
        }
    }
    
    // MARK: - Private Methods
    
    private func saveMemory() {
        // Handle different memory types
        switch memoryType {
        case "text":
            viewModel.createMemory(title: title, content: content, contentType: "text")
            
        case "photo":
            if let imageData = selectedImageData {
                // Save the image to the app's document directory
                if let imageURL = saveImageToDocuments(imageData: imageData) {
                    viewModel.createMemory(title: title, content: content, mediaPath: imageURL.path, contentType: "photo")
                }
            }
            
        default:
            break
        }
        
        dismiss()
    }
    
    private func saveImageToDocuments(imageData: Data) -> URL? {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = UUID().uuidString + ".jpg"
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        do {
            try imageData.write(to: fileURL)
            return fileURL
        } catch {
            print("Error saving image: \(error)")
            return nil
        }
    }
}

struct AudioPlayerView: View {
    let url: URL
    
    var body: some View {
        Text("Audio playback is disabled")
            .foregroundColor(.secondary)
            .padding()
    }
}

#Preview {
    CreateMemoryView()
        .environmentObject(MemoryViewModel())
} 