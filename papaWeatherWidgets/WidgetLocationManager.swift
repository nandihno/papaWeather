//
//  WidgetLocationManager.swift
//  papaWeatherWidgets
//

import CoreLocation
import Foundation

@MainActor
final class WidgetLocationManager: NSObject {
    private let locationManager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func currentLocation(timeoutSeconds: Double = 4.0) async -> CLLocation? {
        guard CLLocationManager.locationServicesEnabled() else {
            return locationManager.location
        }

        let status = locationManager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            return locationManager.location
        }

        guard locationManager.isAuthorizedForWidgetUpdates else {
            return locationManager.location
        }

        // Use cached location if available and recent (< 10 min)
        if let cached = locationManager.location,
           abs(cached.timestamp.timeIntervalSinceNow) < 600,
           cached.horizontalAccuracy >= 0 {
            return cached
        }

        return await withTaskGroup(of: CLLocation?.self) { group in
            group.addTask { @MainActor [weak self] in
                guard let self else { return nil }
                return await withCheckedContinuation { cont in
                    self.continuation = cont
                    self.locationManager.requestLocation()
                }
            }

            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                return nil
            }

            let result = await group.next() ?? nil
            group.cancelAll()
            return result ?? self.locationManager.location
        }
    }
}

extension WidgetLocationManager: @preconcurrency CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let valid = locations.filter { $0.horizontalAccuracy >= 0 }
        let best = valid.min(by: { $0.horizontalAccuracy < $1.horizontalAccuracy }) ?? locations.last
        Task { @MainActor in
            self.continuation?.resume(returning: best)
            self.continuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.continuation?.resume(returning: manager.location)
            self.continuation = nil
        }
    }
}
