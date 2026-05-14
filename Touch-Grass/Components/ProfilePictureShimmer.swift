//
//  ProfilePictureShimmer.swift
//  Touch-Grass
//
//  Created on 12/31/25.
//

import SwiftUI

/// Circular shimmer placeholder for profile pictures
struct ProfilePictureShimmer: View {
    let size: CGFloat
    
    init(size: CGFloat = 120) {
        self.size = size
    }
    
    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        AppColors.grassPrimary.opacity(0.2),
                        AppColors.grassSecondary.opacity(0.3),
                        AppColors.grassPrimary.opacity(0.2)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .shimmer()
    }
}










