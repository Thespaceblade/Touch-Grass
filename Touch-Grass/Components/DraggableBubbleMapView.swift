//
//  DraggableBubbleMapView.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import SwiftUI
import MapKit
import CoreLocation
import UIKit

struct DraggableBubbleMapView: UIViewRepresentable {
    let userLocation: CLLocationCoordinate2D
    @Binding var bubbleCenter: CLLocationCoordinate2D
    @Binding var bubbleRadius: Double
    let onCenterChanged: (CLLocationCoordinate2D) -> Void
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        
        // Validate bubble center before using
        guard bubbleCenter.latitude.isFinite && bubbleCenter.longitude.isFinite,
              bubbleCenter.latitude >= -90 && bubbleCenter.latitude <= 90,
              bubbleCenter.longitude >= -180 && bubbleCenter.longitude <= 180 else {
            print("⚠️ Invalid bubble center in makeUIView - using default")
            // Use a default location if invalid
            let defaultCenter = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194) // San Francisco
            let region = calculateRegion(center: defaultCenter, radius: bubbleRadius)
            mapView.setRegion(region, animated: false)
            
            let annotation = DraggableCenterAnnotation(coordinate: defaultCenter)
            mapView.addAnnotation(annotation)
            let circle = MKCircle(center: defaultCenter, radius: bubbleRadius)
            mapView.addOverlay(circle)
            
            context.coordinator.mapView = mapView
            context.coordinator.centerAnnotation = annotation
            context.coordinator.lastMapCenter = defaultCenter
            
            return mapView
        }
        
        // Set initial region - mark as programmatic to prevent regionDidChange from firing
        context.coordinator.isUpdatingRegionProgrammatically = true
        context.coordinator.mapView = mapView
        context.coordinator.lastMapCenter = bubbleCenter // Initialize to prevent immediate update
        context.coordinator.lastRadius = bubbleRadius // Initialize radius tracking
        
        let region = calculateRegion(center: bubbleCenter, radius: bubbleRadius)
        mapView.setRegion(region, animated: false)
        
        // Add draggable center marker
        let annotation = DraggableCenterAnnotation(coordinate: bubbleCenter)
        mapView.addAnnotation(annotation)
        context.coordinator.centerAnnotation = annotation
        
        // Add zone circle overlay after a brief delay to ensure map view has rendered
        // This ensures the overlay is visible on initial load
        DispatchQueue.main.async {
            let circle = MKCircle(center: bubbleCenter, radius: bubbleRadius)
            mapView.addOverlay(circle)
            // Force map view to update its display
            mapView.setNeedsDisplay()
            
            // Reset the flag after map has had time to settle (give extra time for initial render)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                context.coordinator.isUpdatingRegionProgrammatically = false
            }
        }
        
        print("📍 DraggableBubbleMapView initialized with center: \(bubbleCenter.latitude), \(bubbleCenter.longitude), radius: \(bubbleRadius)m")
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Ensure circle overlay exists on first update (in case it wasn't rendered in makeUIView)
        // Check if we have any circle overlays, and if not, add one
        let circles = mapView.overlays.filter { $0 is MKCircle }
        if circles.isEmpty {
            let circle = MKCircle(center: bubbleCenter, radius: bubbleRadius)
            mapView.addOverlay(circle)
        }
        
        // Don't interfere if user is currently dragging the annotation
        guard !context.coordinator.isDragging else { return }
        
        // Get current annotation coordinate (or fallback to binding value)
        let currentAnnotationCoord = context.coordinator.centerAnnotation?.coordinate ?? bubbleCenter
        
        // Check if bubble center changed significantly (from external source)
        let centerDistance = CLLocation(latitude: currentAnnotationCoord.latitude, longitude: currentAnnotationCoord.longitude)
            .distance(from: CLLocation(latitude: bubbleCenter.latitude, longitude: bubbleCenter.longitude))
        
        // Update annotation and circle if center changed significantly (>10m)
        if centerDistance > 10 {
            // Update annotation position
            if let annotation = context.coordinator.centerAnnotation {
                annotation.coordinate = bubbleCenter
            }
            
            // Update circle overlay
            updateCircleOverlay(mapView: mapView, center: bubbleCenter, radius: bubbleRadius)
            
            // Mark that we're updating programmatically to prevent regionDidChange from firing
            context.coordinator.isUpdatingRegionProgrammatically = true
            context.coordinator.lastMapCenter = bubbleCenter
            
            // Update map region to keep bubble visible (without animation to avoid conflicts)
            let region = calculateRegion(center: bubbleCenter, radius: bubbleRadius)
            mapView.setRegion(region, animated: false)
            
            // Reset flag after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                context.coordinator.isUpdatingRegionProgrammatically = false
            }
        }
        
        // Update circle if radius changed significantly (>5m threshold)
        let lastRadius = context.coordinator.lastRadius ?? bubbleRadius
        if abs(bubbleRadius - lastRadius) > 5 {
            context.coordinator.lastRadius = bubbleRadius
            
            // Update circle overlay with new radius
            updateCircleOverlay(mapView: mapView, center: bubbleCenter, radius: bubbleRadius)
            
            // Mark that we're updating programmatically
            context.coordinator.isUpdatingRegionProgrammatically = true
            context.coordinator.lastMapCenter = bubbleCenter
            
            // Update map region when radius changes (to keep zone visible)
            let region = calculateRegion(center: bubbleCenter, radius: bubbleRadius)
            mapView.setRegion(region, animated: true)
            
            // Reset flag after animation completes (give extra time for region animation)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                context.coordinator.isUpdatingRegionProgrammatically = false
            }
        }
    }
    
    // Helper to update circle overlay
    private func updateCircleOverlay(mapView: MKMapView, center: CLLocationCoordinate2D, radius: Double) {
        let circles = mapView.overlays.filter { $0 is MKCircle }
        mapView.removeOverlays(circles)
        let circle = MKCircle(center: center, radius: radius)
        mapView.addOverlay(circle)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(bubbleCenter: $bubbleCenter, bubbleRadius: $bubbleRadius, onCenterChanged: onCenterChanged)
    }
    
    private func calculateRegion(center: CLLocationCoordinate2D, radius: Double) -> MKCoordinateRegion {
        let radiusInDegrees = radius / 111000.0
        let span = MKCoordinateSpan(
            latitudeDelta: radiusInDegrees * 2.5,
            longitudeDelta: radiusInDegrees * 2.5
        )
        return MKCoordinateRegion(center: center, span: span)
    }
    
    final class Coordinator: NSObject, MKMapViewDelegate {
        @Binding var bubbleCenter: CLLocationCoordinate2D
        @Binding var bubbleRadius: Double
        let onCenterChanged: (CLLocationCoordinate2D) -> Void
        weak var mapView: MKMapView?
        var centerAnnotation: DraggableCenterAnnotation?
        var lastRadius: Double?
        var isDragging: Bool = false // Track drag state to prevent interference
        var lastMapCenter: CLLocationCoordinate2D?
        var isUpdatingRegionProgrammatically: Bool = false // Track programmatic region updates
        
        init(bubbleCenter: Binding<CLLocationCoordinate2D>, bubbleRadius: Binding<Double>, onCenterChanged: @escaping (CLLocationCoordinate2D) -> Void) {
            self._bubbleCenter = bubbleCenter
            self._bubbleRadius = bubbleRadius
            self.onCenterChanged = onCenterChanged
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                return nil
            }
            
            if annotation is DraggableCenterAnnotation {
                let identifier = "DraggableCenter"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                
                if annotationView == nil {
                    annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.isDraggable = true
                    annotationView?.canShowCallout = false
                } else {
                    annotationView?.annotation = annotation
                }
                
                // Custom marker appearance
                let size: CGFloat = 24
                annotationView?.frame = CGRect(x: 0, y: 0, width: size, height: size)
                
                let containerView = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
                containerView.backgroundColor = .clear
                
                // Outer circle
                let outerCircle = UIView(frame: containerView.bounds)
                outerCircle.backgroundColor = UIColor(AppColors.manhuntPrimary).withAlphaComponent(0.2)
                outerCircle.layer.cornerRadius = size / 2
                outerCircle.layer.borderWidth = 3
                outerCircle.layer.borderColor = UIColor(AppColors.manhuntPrimary).cgColor
                containerView.addSubview(outerCircle)
                
                // Inner circle
                let innerSize: CGFloat = 16
                let innerCircle = UIView(frame: CGRect(
                    x: (size - innerSize) / 2,
                    y: (size - innerSize) / 2,
                    width: innerSize,
                    height: innerSize
                ))
                innerCircle.backgroundColor = UIColor(AppColors.manhuntPrimary)
                innerCircle.layer.cornerRadius = innerSize / 2
                innerCircle.layer.shadowColor = UIColor.black.cgColor
                innerCircle.layer.shadowOffset = CGSize(width: 0, height: 2)
                innerCircle.layer.shadowRadius = 4
                innerCircle.layer.shadowOpacity = 0.3
                containerView.addSubview(innerCircle)
                
                annotationView?.addSubview(containerView)
                annotationView?.centerOffset = CGPoint(x: 0, y: -size / 2)
                
                return annotationView
            }
            
            return nil
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                renderer.strokeColor = UIColor(AppColors.bubbleSafe)
                renderer.fillColor = UIColor(AppColors.bubbleSafe).withAlphaComponent(0.15)
                renderer.lineWidth = 3
                // Make the circle non-interactive (not tappable)
                return renderer
            }
            return MKOverlayRenderer()
        }
        
        // Track when map region changes (user pans/zooms)
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Don't update if user is dragging the annotation
            guard !isDragging else { 
                return
            }
            
            // Don't update if this is a programmatic region update
            if isUpdatingRegionProgrammatically {
                // Still update lastMapCenter to track where we set it programmatically
                // Use the intended bubble center, not the map's current center (which might be stale/default)
                lastMapCenter = bubbleCenter
                return
            }
            
            let mapCenter = mapView.region.center
            
            // Validate the map center coordinate
            guard mapCenter.latitude.isFinite && mapCenter.longitude.isFinite,
                  mapCenter.latitude >= -90 && mapCenter.latitude <= 90,
                  mapCenter.longitude >= -180 && mapCenter.longitude <= 180 else {
                print("⚠️ Invalid map center in regionDidChange - ignoring")
                return
            }
            
            // Check if the map center matches our bubble center (within 50m tolerance for initial setup)
            // If it does, this was likely a programmatic change - don't update bubble center
            let currentBubbleCenter = bubbleCenter
            let distanceToBubble = CLLocation(latitude: mapCenter.latitude, longitude: mapCenter.longitude)
                .distance(from: CLLocation(latitude: currentBubbleCenter.latitude, longitude: currentBubbleCenter.longitude))
            
            // Use a larger tolerance (50m) to account for map rendering delays and coordinate precision
            if distanceToBubble < 50 {
                // Map center is very close to bubble center - this was programmatic
                lastMapCenter = mapCenter
                return
            }
            
            // This appears to be a user-initiated pan - update bubble center
            // Check if the map center has changed significantly from last known position
            if let lastCenter = lastMapCenter {
                let distance = CLLocation(latitude: mapCenter.latitude, longitude: mapCenter.longitude)
                    .distance(from: CLLocation(latitude: lastCenter.latitude, longitude: lastCenter.longitude))
                
                // Only update if moved more than 10 meters (to avoid constant updates during zoom)
                if distance > 10 {
                    updateBubbleCenterToMapCenter(mapCenter: mapCenter, animated: false)
                } else {
                    // Small movement - just update tracking
                    lastMapCenter = mapCenter
                }
            } else {
                // First time, update immediately (no animation to avoid conflicts)
                updateBubbleCenterToMapCenter(mapCenter: mapCenter, animated: false)
            }
        }
        
        // Helper to update bubble center to match map center
        private func updateBubbleCenterToMapCenter(mapCenter: CLLocationCoordinate2D, animated: Bool) {
            // Validate coordinate before updating
            guard mapCenter.latitude.isFinite && mapCenter.longitude.isFinite,
                  mapCenter.latitude >= -90 && mapCenter.latitude <= 90,
                  mapCenter.longitude >= -180 && mapCenter.longitude <= 180 else {
                print("⚠️ Invalid map center coordinate - skipping update")
                return
            }
            
            // Update the binding (this will trigger SwiftUI updates)
            bubbleCenter = mapCenter
            
            // Update the annotation position
            if let annotation = centerAnnotation {
                annotation.coordinate = mapCenter
            }
            
            // Update circle overlay to follow the center
            if let mapView = mapView {
                let circles = mapView.overlays.filter { $0 is MKCircle }
                mapView.removeOverlays(circles)
                let circle = MKCircle(center: mapCenter, radius: bubbleRadius)
                mapView.addOverlay(circle)
            }
            
            // Update tracking
            lastMapCenter = mapCenter
            
            // Notify that center changed (this is separate from binding update to avoid conflicts)
            onCenterChanged(mapCenter)
            
            print("📍 Map panned: Updated bubble center to \(mapCenter.latitude), \(mapCenter.longitude)")
        }
        
        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, didChange newState: MKAnnotationView.DragState, fromOldState oldState: MKAnnotationView.DragState) {
            guard let annotation = view.annotation as? DraggableCenterAnnotation else { return }
            
            switch newState {
            case .starting:
                // Drag started - provide haptic feedback and set flag
                isDragging = true
                HapticFeedbackManager.shared.selection()
                
            case .dragging:
                // During drag - update bubble center binding immediately for smooth movement
                let newCoordinate = annotation.coordinate
                
                // Validate coordinate
                guard newCoordinate.latitude.isFinite && newCoordinate.longitude.isFinite,
                      newCoordinate.latitude >= -90 && newCoordinate.latitude <= 90,
                      newCoordinate.longitude >= -180 && newCoordinate.longitude <= 180 else {
                    return
                }
                
                bubbleCenter = newCoordinate
                
                // Update circle overlay smoothly to follow the drag
                let circles = mapView.overlays.filter { $0 is MKCircle }
                mapView.removeOverlays(circles)
                let circle = MKCircle(center: newCoordinate, radius: bubbleRadius)
                mapView.addOverlay(circle)
                
                // Update lastMapCenter to prevent regionDidChange from interfering
                lastMapCenter = newCoordinate
                
                print("📍 Dragging: Updated bubble center to \(newCoordinate.latitude), \(newCoordinate.longitude)")
                
            case .ending, .canceling:
                // Drag ended - finalize position and clear drag flag
                isDragging = false
                
                // Validate coordinate before updating
                let finalCoordinate = annotation.coordinate
                guard finalCoordinate.latitude.isFinite && finalCoordinate.longitude.isFinite,
                      finalCoordinate.latitude >= -90 && finalCoordinate.latitude <= 90,
                      finalCoordinate.longitude >= -180 && finalCoordinate.longitude <= 180 else {
                    print("⚠️ Invalid coordinate after drag - reverting to previous")
                    // Revert annotation to last valid position
                    if let lastValid = lastMapCenter {
                        annotation.coordinate = lastValid
                        bubbleCenter = lastValid
                    }
                    return
                }
                
                // Update binding and tracking
                bubbleCenter = finalCoordinate
                lastMapCenter = finalCoordinate
                
                // Update circle overlay
                let circles = mapView.overlays.filter { $0 is MKCircle }
                mapView.removeOverlays(circles)
                let circle = MKCircle(center: finalCoordinate, radius: bubbleRadius)
                mapView.addOverlay(circle)
                
                // Notify that center changed
                onCenterChanged(finalCoordinate)
                
                print("📍 Drag ended: Final bubble center \(finalCoordinate.latitude), \(finalCoordinate.longitude)")
                
            default:
                break
            }
        }
        
    }
}

// Draggable annotation for the bubble center
class DraggableCenterAnnotation: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    
    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        super.init()
    }
}

