//
//  MemoryListView.swift
//  Reminiscence
//
//  Created for Spatial Memory App
//

import SwiftUI
import CoreLocation

struct MemoryListView: View {
    @EnvironmentObject var viewModel: MemoryViewModel
    @State private var searchText = ""
    @State private var selectedTag: Tag?
    @State private var sortOption = SortOption.newest
    @State private var showingCreateMemory = false
    
    enum SortOption: String, CaseIterable, Identifiable {
        case newest = "Newest"
        case oldest = "Oldest"
        case nearbyFirst = "Nearby First"
        case title = "Title"
        
        var id: String { self.rawValue }
    }
    
    var filteredMemories: [MemoryItem] {
        // First apply tag filter if selected
        var memories = selectedTag != nil ? 
            viewModel.filterMemoriesByTag(selectedTag!) : 
            viewModel.memories
        
        // Then apply text search if any
        if !searchText.isEmpty {
            memories = memories.filter { memory in
                let titleMatch = memory.title?.localizedCaseInsensitiveContains(searchText) ?? false
                let contentMatch = memory.contentText?.localizedCaseInsensitiveContains(searchText) ?? false
                return titleMatch || contentMatch
            }
        }
        
        // Finally sort
        switch sortOption {
        case .newest:
            return memories.sorted { 
                ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast)
            }
        case .oldest:
            return memories.sorted { 
                ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast)
            }
        case .nearbyFirst:
            guard let userLocation = viewModel.currentLocation else {
                return memories
            }
            
            return memories.sorted {
                let loc1 = CLLocation(latitude: $0.latitude, longitude: $0.longitude)
                let loc2 = CLLocation(latitude: $1.latitude, longitude: $1.longitude)
                return loc1.distance(from: userLocation) < loc2.distance(from: userLocation)
            }
        case .title:
            return memories.sorted { 
                ($0.title ?? "") < ($1.title ?? "") 
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Tag filter
                if !viewModel.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            Button(action: {
                                selectedTag = nil
                            }) {
                                Text("All")
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedTag == nil ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedTag == nil ? .white : .primary)
                                    .cornerRadius(20)
                            }
                            
                            ForEach(viewModel.tags, id: \.self) { tag in
                                Button(action: {
                                    selectedTag = (selectedTag == tag) ? nil : tag
                                }) {
                                    HStack {
                                        Circle()
                                            .fill(colorFromString(tag.color ?? "blue"))
                                            .frame(width: 8, height: 8)
                                        
                                        Text(tag.name ?? "")
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedTag == tag ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedTag == tag ? .white : .primary)
                                    .cornerRadius(20)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Sort options
                HStack {
                    Text("Sort by:")
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: $sortOption) {
                        ForEach(SortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                // Memory list
                if viewModel.isLoadingData {
                    ProgressView("Loading memories...")
                        .padding()
                } else if filteredMemories.isEmpty {
                    VStack {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                            .padding()
                        
                        Text("No memories found")
                            .foregroundColor(.secondary)
                        
                        if !searchText.isEmpty || selectedTag != nil {
                            Text("Try adjusting your filters")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Button(action: {
                                showingCreateMemory = true
                            }) {
                                Text("Create your first memory")
                                    .fontWeight(.bold)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .padding()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredMemories, id: \.self) { memory in
                            MemoryListItemView(memory: memory)
                                .onTapGesture {
                                    viewModel.selectedMemory = memory
                                    viewModel.isShowingMemoryDetail = true
                                }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Memories")
            .navigationBarItems(trailing: 
                Button(action: {
                    showingCreateMemory = true
                }) {
                    Image(systemName: "plus")
                }
            )
            .searchable(text: $searchText, prompt: "Search memories")
            .sheet(isPresented: $showingCreateMemory) {
                CreateMemoryView()
                    .environmentObject(viewModel)
            }
            .sheet(isPresented: $viewModel.isShowingMemoryDetail) {
                if let memory = viewModel.selectedMemory {
                    MemoryDetailView(memory: memory)
                        .environmentObject(viewModel)
                }
            }
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
}

struct MemoryListItemView: View {
    let memory: MemoryItem
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon based on memory type
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: iconForMemoryType(memory.contentType ?? "text"))
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(memory.title ?? "Untitled Memory")
                    .font(.headline)
                
                if let createdAt = memory.createdAt {
                    Text(createdAt, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let content = memory.contentText, !content.isEmpty {
                    Text(content)
                        .lineLimit(2)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }
                
                if let tags = memory.tags as? Set<Tag>, !tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(Array(tags).prefix(3), id: \.self) { tag in
                                Text(tag.name ?? "")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(10)
                            }
                            
                            if tags.count > 3 {
                                Text("+\(tags.count - 3)")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(10)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(.vertical, 8)
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

#Preview {
    MemoryListView()
        .environmentObject(MemoryViewModel())
} 