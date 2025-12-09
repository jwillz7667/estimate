//
//  ImageEditorView.swift
//  ProjectEstimate
//
//  AI-powered image editor for renovation visualization
//  Upload project photos and use natural language to modify them
//

import SwiftUI
import PhotosUI
import UIKit

// MARK: - Image Editor View

struct ImageEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var originalImage: UIImage?
    @State private var editedImages: [EditedImage] = []
    @State private var currentPrompt: String = ""
    @State private var isProcessing = false
    @State private var showCamera = false
    @State private var selectedEditIndex: Int?
    @State private var zoomScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero

    // Prompt suggestions based on common renovation tasks
    private let promptSuggestions = [
        "Change wall paint to blue",
        "Add hardwood flooring",
        "Install white cabinets",
        "Add a modern backsplash",
        "Replace with granite countertops",
        "Add recessed lighting",
        "Install crown molding",
        "Add a wooden deck",
        "Replace roof tiles",
        "Add landscaping"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if originalImage == nil {
                        imageUploadView
                    } else {
                        imageEditorContent
                    }
                }
            }
            .navigationTitle("Image Editor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }

                if originalImage != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button {
                                saveAllImages()
                            } label: {
                                Label("Save All", systemImage: "square.and.arrow.down")
                            }

                            Button {
                                clearAll()
                            } label: {
                                Label("Start Over", systemImage: "arrow.counterclockwise")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraView { image in
                    originalImage = image
                }
            }
            .onChange(of: selectedPhotoItem) { _, newValue in
                loadImage(from: newValue)
            }
        }
    }

    // MARK: - Image Upload View

    private var imageUploadView: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 70))
                    .foregroundStyle(.blue)

                Text("Upload Project Photo")
                    .font(.title2.bold())

                Text("Take a photo or choose from your library to start editing with AI")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            VStack(spacing: 16) {
                // Camera button
                Button {
                    showCamera = true
                } label: {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("Take Photo")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                // Photo picker
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text("Choose from Library")
                    }
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            // Tips section
            VStack(alignment: .leading, spacing: 12) {
                Text("Tips for best results:")
                    .font(.subheadline.bold())

                VStack(alignment: .leading, spacing: 8) {
                    TipRow(icon: "sun.max", text: "Use well-lit photos")
                    TipRow(icon: "arrow.up.left.and.arrow.down.right", text: "Capture the full area you want to modify")
                    TipRow(icon: "viewfinder", text: "Keep the camera steady for sharp images")
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Image Editor Content

    private var imageEditorContent: some View {
        VStack(spacing: 0) {
            // Image display area
            ZStack {
                Color.black

                if let currentImage = selectedEditIndex != nil ? editedImages[selectedEditIndex!].image : originalImage {
                    Image(uiImage: currentImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(zoomScale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    zoomScale = value
                                }
                                .onEnded { _ in
                                    withAnimation(.spring()) {
                                        zoomScale = max(1.0, min(zoomScale, 3.0))
                                        if zoomScale == 1.0 {
                                            offset = .zero
                                        }
                                    }
                                }
                        )
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    if zoomScale > 1.0 {
                                        offset = value.translation
                                    }
                                }
                                .onEnded { _ in
                                    if zoomScale == 1.0 {
                                        withAnimation(.spring()) {
                                            offset = .zero
                                        }
                                    }
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring()) {
                                if zoomScale > 1.0 {
                                    zoomScale = 1.0
                                    offset = .zero
                                } else {
                                    zoomScale = 2.0
                                }
                            }
                        }
                }

                // Processing overlay
                if isProcessing {
                    Color.black.opacity(0.6)

                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)

                        Text("Generating...")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(height: 300)

            // Edit history thumbnails
            if !editedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // Original
                        ThumbnailButton(
                            image: originalImage,
                            label: "Original",
                            isSelected: selectedEditIndex == nil
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedEditIndex = nil
                            }
                        }

                        ForEach(Array(editedImages.enumerated()), id: \.element.id) { index, edit in
                            ThumbnailButton(
                                image: edit.image,
                                label: "Edit \(index + 1)",
                                isSelected: selectedEditIndex == index
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedEditIndex = index
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(Color(.secondarySystemGroupedBackground))
            }

            // Prompt input area
            VStack(spacing: 16) {
                // Suggestion chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(promptSuggestions, id: \.self) { suggestion in
                            SuggestionChip(text: suggestion) {
                                currentPrompt = suggestion
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                // Prompt text field
                HStack(spacing: 12) {
                    TextField("Describe what to change...", text: $currentPrompt, axis: .vertical)
                        .lineLimit(1...3)
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button {
                        generateEdit()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(currentPrompt.isEmpty ? .gray : .blue)
                    }
                    .disabled(currentPrompt.isEmpty || isProcessing)
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 16)
        }
    }

    // MARK: - Actions

    private func loadImage(from item: PhotosPickerItem?) {
        guard let item = item else { return }

        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    originalImage = image
                }
            }
        }
    }

    private func generateEdit() {
        guard !currentPrompt.isEmpty, !isProcessing else { return }

        isProcessing = true

        Task {
            do {
                let baseImage = selectedEditIndex != nil ? editedImages[selectedEditIndex!].image : originalImage!

                // Build the edit prompt
                let fullPrompt = buildEditPrompt(currentPrompt)

                // Call AI service
                let geminiService = GeminiAPIService()
                let imageData = try await geminiService.generateImage(
                    prompt: fullPrompt,
                    style: .photorealistic,
                    aspectRatio: .landscape
                )

                if let editedImage = UIImage(data: imageData) {
                    let edit = EditedImage(
                        image: editedImage,
                        prompt: currentPrompt,
                        timestamp: Date()
                    )

                    await MainActor.run {
                        editedImages.append(edit)
                        selectedEditIndex = editedImages.count - 1
                        currentPrompt = ""
                        isProcessing = false
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    // Handle error
                }
            }
        }
    }

    private func buildEditPrompt(_ userPrompt: String) -> String {
        """
        Modify this home renovation image with the following change: \(userPrompt).

        Requirements:
        - Maintain the same perspective and room layout
        - Apply the requested change realistically
        - Preserve unmodified elements of the room
        - Ensure natural lighting and shadows
        - High quality, photorealistic result
        """
    }

    private func saveAllImages() {
        let imagesToSave = [originalImage].compactMap { $0 } + editedImages.map { $0.image }

        for image in imagesToSave {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        }
    }

    private func clearAll() {
        withAnimation {
            originalImage = nil
            editedImages = []
            selectedEditIndex = nil
            currentPrompt = ""
        }
    }
}

// MARK: - Edited Image Model

struct EditedImage: Identifiable {
    let id = UUID()
    let image: UIImage
    let prompt: String
    let timestamp: Date
}

// MARK: - Supporting Views

struct TipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.blue)
                .frame(width: 20)

            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct ThumbnailButton: View {
    let image: UIImage?
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(isSelected ? Color.blue : Color.clear, lineWidth: 3)
                        )
                }

                Text(label)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .blue : .secondary)
            }
        }
    }
}

struct SuggestionChip: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.caption)
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(Capsule())
        }
    }
}

// MARK: - Camera View

struct CameraView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void

        init(onCapture: @escaping (UIImage) -> Void) {
            self.onCapture = onCapture
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Full Image Viewer

struct FullImageViewer: View {
    let image: UIImage
    @Binding var isPresented: Bool

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = lastScale * value
                        }
                        .onEnded { _ in
                            lastScale = scale
                            if scale < 1.0 {
                                withAnimation(.spring()) {
                                    scale = 1.0
                                    lastScale = 1.0
                                }
                            }
                        }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring()) {
                        if scale > 1.0 {
                            scale = 1.0
                            lastScale = 1.0
                            offset = .zero
                            lastOffset = .zero
                        } else {
                            scale = 2.5
                            lastScale = 2.5
                        }
                    }
                }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding()
                }
                Spacer()
            }
        }
    }
}

// MARK: - Preview

#Preview("Image Editor") {
    ImageEditorView()
}
