//
//  Firestore+Extensions.swift
//  withornot
//
//  Firestore 트랜잭션 헬퍼 및 유틸리티
//

import Foundation
import FirebaseFirestore

// MARK: - Transaction Helper

extension Firestore {
    /// 간편한 트랜잭션 실행 헬퍼
    /// - Parameters:
    ///   - block: 트랜잭션 내에서 실행할 클로저
    /// - Returns: 트랜잭션 결과
    func executeTransaction<T>(
        _ block: @escaping (Transaction) throws -> T
    ) async throws -> T {
        try await runTransaction { (transaction, errorPointer) -> T? in
            do {
                return try block(transaction)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        } as! T
    }
}

// MARK: - Document Reference Helper

extension DocumentReference {
    /// 문서를 가져와서 디코딩
    func getDecodedDocument<T: Decodable>(as type: T.Type) async throws -> T {
        let snapshot = try await getDocument()
        guard snapshot.exists else {
            throw FirestoreError.documentNotFound
        }
        return try snapshot.data(as: type)
    }

    /// 트랜잭션 내에서 문서를 가져와서 디코딩
    func getDecodedDocument<T: Decodable>(
        in transaction: Transaction,
        as type: T.Type
    ) throws -> T {
        let snapshot = try transaction.getDocument(self)
        guard snapshot.exists else {
            throw FirestoreError.documentNotFound
        }
        return try snapshot.data(as: type)
    }
}

// MARK: - Firestore Error

enum FirestoreError: LocalizedError {
    case documentNotFound
    case decodingFailed
    case transactionFailed

    var errorDescription: String? {
        switch self {
        case .documentNotFound:
            return "문서를 찾을 수 없습니다"
        case .decodingFailed:
            return "데이터 변환에 실패했습니다"
        case .transactionFailed:
            return "트랜잭션 처리에 실패했습니다"
        }
    }
}

// MARK: - Report Threshold

enum ReportThreshold {
    static let deleteAt: Int = 3
}
