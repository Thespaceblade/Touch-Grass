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
    
    @State private var showImageSourcePicker = false
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var croppedImage: UIImage?
    @State private var showCropView = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundPrimary
                    .ignoresSafeArea()
                
                VStack(spacing: AppSpacing.xl) {
                    // Preview
                    if let image = croppedImage ?? selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 200, height: 200)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(AppColors.manhuntPrimary, lineWidth: 4)
                            )
                            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 100))
                            .foregroundColor(AppColors.manhuntPrimary)
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
                                    .font(.title3)
                                Text("Take Photo")
                                    .font(AppTypography.labelLarge())
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppColors.manhuntPrimary)
                            .cornerRadius(12)
                        }
                        .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
                        
                        PhotosPicker(selection: $photoPickerItem, matching: .images) {
                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.title3)
                                Text("Choose from Library")
                                    .font(AppTypography.labelLarge())
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppColors.manhuntSecondary)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    
                    Spacer()
                    
                    // Action Buttons
                    HStack(spacing: AppSpacing.md) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .font(AppTypography.labelLarge())
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.cardBackground)
                        )
                        
                        Button("Use Photo") {
                            selectedImage = croppedImage ?? selectedImage
                            dismiss()
                        }
                        .font(AppTypography.labelLarge())
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.manhuntPrimary)
                        )
                        .disabled(croppedImage == nil && selectedImage == nil)
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
            ImagePicker(sourceType: .camera, selectedImage: $selectedImage)
        }
        .sheet(isPresented: $showPhotoLibrary) {
            ImagePicker(sourceType: .photoLibrary, selectedImage: $selectedImage)
        }
        .onChange(of: photoPickerItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                    // Auto-crop to square
                    croppedImage = cropToSquare(image)
                }
            }
        }
        .onChange(of: selectedImage) { _, newImage in
            if let image = newImage {
                croppedImage = cropToSquare(image)
            }
        }
    }
    
    private func cropToSquare(_ image: UIImage) -> UIImage {
        let size = min(image.size.width, image.size.height)
        let x = (image.size.width - size) / 2
        let y = (image.size.height - size) / 2
        let rect = CGRect(x: x, y: y, width: size, height: size)
        
        guard let cgImage = image.cgImage?.cropping(to: rect) else {
            return image
        }
        
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
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
        picker.allowsEditing = true
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


