//
//  ProfilePicturePicker.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import SwiftUI
import PhotosUI
import UIKit

struct ProfilePicturePicker: View {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) var dismiss
    
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var editingImage: UIImage?
    @State private var cropScale: CGFloat = 1
    @State private var lastCropScale: CGFloat = 1
    @State private var cropOffset: CGSize = .zero
    @State private var lastCropOffset: CGSize = .zero
    
    private let previewSize: CGFloat = 260
    private let outputSize: CGFloat = 600
    
    private var previewImage: UIImage? {
        editingImage ?? selectedImage
    }
    
    private var hasSelectedImage: Bool {
        previewImage != nil
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.cartoonCream
                    .ignoresSafeArea()
                
                VStack(spacing: AppSpacing.xl) {
                    Spacer()
                    
                    // Preview
                    if let image = previewImage {
                        cropPreview(image)
                    } else {
                        CartoonMedallion(background: AppColors.grassPrimary, size: 180, borderWidth: 4) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 82, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                    
                    // Source Selection
                    VStack(spacing: AppSpacing.md) {
                        Button(action: {
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                showCamera = true
                            } else {
                                showPhotoLibrary = true
                            }
                        }) {
                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 18, weight: .black, design: .rounded))
                                Text("Take Photo")
                            }
                        }
                        .buttonStyle(CartoonButtonStyle(accent: AppColors.grassPrimary))
                        .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
                        
                        PhotosPicker(selection: $photoPickerItem, matching: .images) {
                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 18, weight: .black, design: .rounded))
                                Text("Choose from Library")
                            }
                        }
                        .buttonStyle(CartoonButtonStyle(accent: AppColors.grassSecondary))
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    
                    Spacer()
                    
                    // Action Buttons
                    HStack(spacing: AppSpacing.md) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(CartoonButtonStyle(accent: AppColors.error, textColor: .white))
                        
                        Button("Use") {
                            selectedImage = croppedProfileImage() ?? previewImage
                            dismiss()
                        }
                        .buttonStyle(CartoonButtonStyle(accent: AppColors.grassPrimary, textColor: .white, isDisabled: !hasSelectedImage))
                        .disabled(!hasSelectedImage)
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.md)
                }
                .padding()
            }
            .navigationTitle("Choose Profile Picture")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(sourceType: .camera, selectedImage: $editingImage)
        }
        .sheet(isPresented: $showPhotoLibrary) {
            ImagePicker(sourceType: .photoLibrary, selectedImage: $editingImage)
        }
        .onChange(of: photoPickerItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    editingImage = image
                    resetCrop()
                }
            }
        }
        .onChange(of: editingImage) { _, newImage in
            if newImage != nil {
                resetCrop()
            }
        }
        .onAppear {
            editingImage = selectedImage
        }
    }
    
    private func cropPreview(_ image: UIImage) -> some View {
        let dragGesture = DragGesture()
            .onChanged { value in
                cropOffset = clampedOffset(
                    CGSize(
                        width: lastCropOffset.width + value.translation.width,
                        height: lastCropOffset.height + value.translation.height
                    ),
                    scale: cropScale,
                    imageSize: image.size
                )
            }
            .onEnded { _ in
                cropOffset = clampedOffset(cropOffset, scale: cropScale, imageSize: image.size)
                lastCropOffset = cropOffset
            }
        
        let zoomGesture = MagnificationGesture()
            .onChanged { value in
                cropScale = min(max(lastCropScale * value, 1), 4)
                cropOffset = clampedOffset(cropOffset, scale: cropScale, imageSize: image.size)
            }
            .onEnded { _ in
                cropScale = min(max(cropScale, 1), 4)
                cropOffset = clampedOffset(cropOffset, scale: cropScale, imageSize: image.size)
                lastCropScale = cropScale
                lastCropOffset = cropOffset
            }
        
        return VStack(spacing: AppSpacing.sm) {
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: previewSize, height: previewSize)
                    .scaleEffect(cropScale)
                    .offset(cropOffset)
            }
            .frame(width: previewSize, height: previewSize)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(AppColors.cartoonInk, lineWidth: 4)
            )
            .background(
                Circle()
                    .fill(Color(white: 0.18))
                    .offset(x: 5, y: 5)
            )
            .contentShape(Circle())
            .gesture(dragGesture)
            .simultaneousGesture(zoomGesture)
            
            Text("Pinch to zoom. Drag to reposition.")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundColor(AppColors.cartoonInk.opacity(0.55))
        }
    }
    
    private func resetCrop() {
        cropScale = 1
        lastCropScale = 1
        cropOffset = .zero
        lastCropOffset = .zero
    }
    
    private func clampedOffset(_ offset: CGSize, scale: CGFloat, imageSize: CGSize) -> CGSize {
        let baseScale = max(previewSize / imageSize.width, previewSize / imageSize.height)
        let displayedWidth = imageSize.width * baseScale * scale
        let displayedHeight = imageSize.height * baseScale * scale
        let maxXOffset = max((displayedWidth - previewSize) / 2, 0)
        let maxYOffset = max((displayedHeight - previewSize) / 2, 0)
        
        return CGSize(
            width: min(max(offset.width, -maxXOffset), maxXOffset),
            height: min(max(offset.height, -maxYOffset), maxYOffset)
        )
    }
    
    private func croppedProfileImage() -> UIImage? {
        guard let image = previewImage?.normalizedImage() else { return nil }
        
        let renderSize = CGSize(width: outputSize, height: outputSize)
        let renderer = UIGraphicsImageRenderer(size: renderSize)
        return renderer.image { _ in
            let baseScale = max(renderSize.width / image.size.width, renderSize.height / image.size.height)
            let finalScale = baseScale * cropScale
            let scaledSize = CGSize(
                width: image.size.width * finalScale,
                height: image.size.height * finalScale
            )
            let offsetScale = renderSize.width / previewSize
            let origin = CGPoint(
                x: (renderSize.width - scaledSize.width) / 2 + cropOffset.width * offsetScale,
                y: (renderSize.height - scaledSize.height) / 2 + cropOffset.height * offsetScale
            )
            
            image.draw(in: CGRect(origin: origin, size: scaledSize))
        }
    }
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.selectedImage = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.selectedImage = originalImage
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

private extension UIImage {
    func normalizedImage() -> UIImage {
        guard imageOrientation != .up else { return self }
        
        return UIGraphicsImageRenderer(size: size).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

