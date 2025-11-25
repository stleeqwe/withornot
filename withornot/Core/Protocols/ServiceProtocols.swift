//
//  ServiceProtocols.swift
//  withornot
//
//  서비스 추상화를 위한 프로토콜 정의
//

import Foundation
import CoreLocation
import Combine

// MARK: - Auth Service Protocol

protocol AuthServiceProtocol: ObservableObject {
    var currentUser: User? { get }
    var isAuthenticated: Bool { get }

    func signInAnonymously()
    func updateFCMToken(_ token: String)
}

// MARK: - Post Service Protocol

protocol PostServiceProtocol: ObservableObject {
    var posts: [Post] { get }
    var isLoading: Bool { get }
    var error: String? { get }

    func startListening()
    func stopListening()
    func hasActivePost(userId: String) -> Bool
    func createPost(message: String, locationText: String, meetTime: Date, userLocation: CLLocation?, userId: String) async throws
    func toggleParticipation(postId: String, userId: String) async throws
    func deletePost(postId: String) async throws
    func reportPost(postId: String) async throws
}

// MARK: - Chat Service Protocol

protocol ChatServiceProtocol: ObservableObject {
    var messages: [Message] { get }
    var isLoading: Bool { get }
    var chatEndTime: Date? { get }

    func joinChat(postId: String, meetTime: Date)
    func leaveChat()
    func sendMessage(postId: String, text: String, userId: String) async throws
    func reportMessage(postId: String, messageId: String) async throws
}

// MARK: - Location Service Protocol

protocol LocationServiceProtocol: ObservableObject {
    var currentLocation: CLLocation? { get }
    var authorizationStatus: CLAuthorizationStatus { get }
    var isLocationAvailable: Bool { get }

    func requestLocationPermission()
    func startUpdatingLocation()
    func stopUpdatingLocation()
    func getDistanceText(from location: CLLocation) -> String
}

// MARK: - Notification Service Protocol

protocol NotificationServiceProtocol: ObservableObject {
    var hasPermission: Bool { get }

    func checkPermission()
    func requestPermission()
    func scheduleChatNotification(for post: Post)
    func cancelNotification(for postId: String)
    func notifyChatParticipants(postId: String) async throws
}

// MARK: - Configurable ViewModel Protocol

protocol ConfigurableViewModel {
    associatedtype Dependencies
    var isConfigured: Bool { get }
    func configure(with dependencies: Dependencies)
}

// MARK: - App Error Protocol

protocol AppError: LocalizedError {
    var userMessage: String { get }
    var logMessage: String { get }
    var isRetryable: Bool { get }
}

extension AppError {
    var isRetryable: Bool { false }
    var logMessage: String { localizedDescription }
}
