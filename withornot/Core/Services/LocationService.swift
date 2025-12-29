import Foundation
import CoreLocation
import Combine

/// 위치 관련 에러 타입
enum LocationError: LocalizedError {
    case permissionDenied
    case locationUnavailable
    case updateFailed(Error)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "위치 권한이 거부되었습니다. 설정에서 위치 권한을 허용해주세요."
        case .locationUnavailable:
            return "현재 위치를 확인할 수 없습니다."
        case .updateFailed:
            return "위치 업데이트에 실패했습니다."
        }
    }
}

class LocationService: NSObject, ObservableObject, LocationServiceProtocol {
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocationAvailable = false
    @Published var error: String?

    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        setupLocationManager()
    }

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.distanceFilter = 1000 // 1km 변화 시 업데이트
    }

    func requestLocationPermission() {
        error = nil
        locationManager.requestWhenInUseAuthorization()
    }

    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }

    func getDistanceText(from location: CLLocation) -> String {
        guard let currentLocation = currentLocation else {
            return "거리 측정 불가"
        }

        let distance = currentLocation.distance(from: location) / 1000
        return String(format: "%.1fkm", distance)
    }

    /// 에러 상태 초기화
    func clearError() {
        DispatchQueue.main.async {
            self.error = nil
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async { [weak self] in
            self?.authorizationStatus = manager.authorizationStatus

            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self?.isLocationAvailable = true
                self?.error = nil
                self?.startUpdatingLocation()
            case .denied, .restricted:
                self?.isLocationAvailable = false
                self?.error = LocationError.permissionDenied.localizedDescription
            case .notDetermined:
                self?.isLocationAvailable = false
            @unknown default:
                break
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async { [weak self] in
            self?.currentLocation = location
            self?.error = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location error: \(error.localizedDescription)")

        DispatchQueue.main.async { [weak self] in
            // CLError 처리
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    self?.error = LocationError.permissionDenied.localizedDescription
                case .locationUnknown:
                    self?.error = LocationError.locationUnavailable.localizedDescription
                default:
                    self?.error = LocationError.updateFailed(error).localizedDescription
                }
            } else {
                self?.error = LocationError.updateFailed(error).localizedDescription
            }
        }
    }
}
