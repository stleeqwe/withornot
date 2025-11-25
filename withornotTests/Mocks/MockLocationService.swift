//
//  MockLocationService.swift
//  withornotTests
//

import Foundation
import Combine
import CoreLocation
@testable import withornot

class MockLocationService: ObservableObject {
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocationAvailable = false

    // 호출 추적
    var requestLocationPermissionCalled = false
    var startUpdatingLocationCalled = false
    var stopUpdatingLocationCalled = false

    func requestLocationPermission() {
        requestLocationPermissionCalled = true
        // 시뮬레이션: 권한 승인
        authorizationStatus = .authorizedWhenInUse
        isLocationAvailable = true
    }

    func startUpdatingLocation() {
        startUpdatingLocationCalled = true
    }

    func stopUpdatingLocation() {
        stopUpdatingLocationCalled = true
    }

    func getDistanceText(from location: CLLocation) -> String {
        guard let currentLocation = currentLocation else {
            return "거리 측정 불가"
        }

        let distance = currentLocation.distance(from: location) / 1000
        return String(format: "%.1fkm", distance)
    }

    // 테스트 헬퍼 메서드
    func setMockLocation(latitude: Double, longitude: Double) {
        currentLocation = CLLocation(latitude: latitude, longitude: longitude)
        isLocationAvailable = true
        authorizationStatus = .authorizedWhenInUse
    }

    func setMockLocation(_ location: CLLocation) {
        currentLocation = location
        isLocationAvailable = true
        authorizationStatus = .authorizedWhenInUse
    }

    func setAuthorizationDenied() {
        authorizationStatus = .denied
        isLocationAvailable = false
        currentLocation = nil
    }

    func reset() {
        currentLocation = nil
        authorizationStatus = .notDetermined
        isLocationAvailable = false
        requestLocationPermissionCalled = false
        startUpdatingLocationCalled = false
        stopUpdatingLocationCalled = false
    }
}
