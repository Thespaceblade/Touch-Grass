//
//  ActiveGameStatusChrome.swift
//  Touch-Grass
//
//  Full-width top strip with time and battery for active map gameplay.
//

import SwiftUI
import UIKit

// MARK: - Metrics (align HUD row + map controls)

enum ActiveGameTopChromeMetrics {
    static let rowHeight: CGFloat = 22
    static let minTopPadding: CGFloat = 4
    static let minBottomPadding: CGFloat = 6
    static let statusAreaBottomBreathingRoom: CGFloat = 4

    static func topPadding(for safeAreaTop: CGFloat) -> CGFloat {
        max(minTopPadding, (safeAreaTop - rowHeight) / 2)
    }

    static func bottomPadding(for safeAreaTop: CGFloat) -> CGFloat {
        let paddingToClearStatusArea = safeAreaTop - topPadding(for: safeAreaTop) - rowHeight + statusAreaBottomBreathingRoom
        return max(minBottomPadding, paddingToClearStatusArea)
    }

    static func stripHeight(for safeAreaTop: CGFloat) -> CGFloat {
        topPadding(for: safeAreaTop) + rowHeight + bottomPadding(for: safeAreaTop)
    }
}

// MARK: - Status strip

struct ActiveGameStatusStrip: View {
    let safeAreaTop: CGFloat

    @State private var batteryLevel: Float = -1
    @State private var batteryState: UIDevice.BatteryState = .unknown

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            HStack(alignment: .center, spacing: AppSpacing.md) {
                Text(context.date, style: .time)
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .accessibilityLabel("Current time")
                    .accessibilityValue(context.date.formatted(date: .omitted, time: .shortened))

                Spacer(minLength: 100)

                batteryCluster
                    .accessibilityElement(children: .combine)
            }
            .padding(.horizontal, AppSpacing.md)
            .frame(height: ActiveGameTopChromeMetrics.rowHeight)
            .padding(.top, ActiveGameTopChromeMetrics.topPadding(for: safeAreaTop))
            .padding(.bottom, ActiveGameTopChromeMetrics.bottomPadding(for: safeAreaTop))
            .background {
                ZStack(alignment: .bottom) {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .background(AppColors.cartoonInk.opacity(0.32))
                    Rectangle()
                        .fill(AppColors.cartoonInk)
                        .frame(height: 2.5)
                }
                    .ignoresSafeArea(edges: [.top, .horizontal])
            }
        }
        .onAppear {
            UIDevice.current.isBatteryMonitoringEnabled = true
            refreshBattery()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)) { _ in
            refreshBattery()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.batteryStateDidChangeNotification)) { _ in
            refreshBattery()
        }
        .onDisappear {
            UIDevice.current.isBatteryMonitoringEnabled = false
        }
    }

    @ViewBuilder
    private var batteryCluster: some View {
        HStack(spacing: 4) {
            if batteryState == .charging || batteryState == .full {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppColors.grassLight)
            }

            Image(systemName: batterySymbolName)
                .font(.system(size: 16, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)

            if batteryLevel >= 0 {
                Text("\(Int(batteryLevel * 100))%")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
            } else {
                Text("—")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .accessibilityLabel("Battery")
        .accessibilityValue(batteryAccessibilityValue)
    }

    private var batterySymbolName: String {
        if batteryLevel < 0 {
            return "battery.100"
        }
        let pct = batteryLevel
        switch pct {
        case ..<0.05: return "battery.0"
        case ..<0.25: return "battery.25"
        case ..<0.5: return "battery.50"
        case ..<0.75: return "battery.75"
        default: return "battery.100"
        }
    }

    private var batteryAccessibilityValue: String {
        if batteryLevel < 0 {
            return "Level unknown"
        }
        let pct = Int(batteryLevel * 100)
        switch batteryState {
        case .charging:
            return "\(pct) percent, charging"
        case .full:
            return "Full"
        case .unplugged:
            return "\(pct) percent"
        case .unknown:
            return "\(pct) percent"
        @unknown default:
            return "\(pct) percent"
        }
    }

    private func refreshBattery() {
        batteryLevel = UIDevice.current.batteryLevel
        batteryState = UIDevice.current.batteryState
    }
}

// MARK: - UIKit status bar (hidden + light when system bar would clash with map)

final class ActiveGameStatusBarViewController: UIViewController {
    override var prefersStatusBarHidden: Bool { true }
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation { .fade }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        propagateStatusBarUpdate()
    }

    func propagateStatusBarUpdate() {
        setNeedsStatusBarAppearanceUpdate()
        var parentVC = parent
        while let p = parentVC {
            p.setNeedsStatusBarAppearanceUpdate()
            parentVC = p.parent
        }
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController?
            .setNeedsStatusBarAppearanceUpdate()
    }
}

struct ActiveGameStatusBarConfigurator: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ActiveGameStatusBarViewController {
        ActiveGameStatusBarViewController()
    }

    func updateUIViewController(_ uiViewController: ActiveGameStatusBarViewController, context: Context) {
        uiViewController.propagateStatusBarUpdate()
    }
}

extension View {
    /// Hides the system status bar during active gameplay; the in-app `ActiveGameStatusStrip` shows time and battery.
    /// Screenshot scenarios use the same chrome as a real session so marketing captures match shipped UI.
    @ViewBuilder
    func activeGameStatusBarHidden() -> some View {
        self
            .statusBarHidden(true)
            .background {
                ActiveGameStatusBarConfigurator()
                    .frame(width: 0, height: 0)
            }
    }
}
