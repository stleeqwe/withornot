import Foundation

extension Error {
    /// 사용자 친화적인 에러 메시지로 변환
    var userFriendlyMessage: String {
        // Firebase 에러 처리
        if let nsError = self as NSError? {
            // Firebase 오프라인 캐시 버전 충돌
            if nsError.domain == "FIRFirestoreErrorDomain" {
                if nsError.localizedDescription.contains("stored version") &&
                   nsError.localizedDescription.contains("does not match") {
                    return "네트워크 연결이 불안정합니다.\n잠시 후 다시 시도해주세요."
                }

                // 네트워크 오류
                if nsError.localizedDescription.contains("offline") ||
                   nsError.localizedDescription.contains("network") {
                    return "네트워크에 연결할 수 없습니다.\n인터넷 연결을 확인해주세요."
                }

                // 권한 오류
                if nsError.localizedDescription.contains("permission") ||
                   nsError.localizedDescription.contains("denied") {
                    return "접근 권한이 없습니다."
                }
            }

            // 네트워크 관련 에러
            if nsError.domain == NSURLErrorDomain {
                switch nsError.code {
                case NSURLErrorNotConnectedToInternet:
                    return "인터넷에 연결되어 있지 않습니다."
                case NSURLErrorTimedOut:
                    return "요청 시간이 초과되었습니다.\n잠시 후 다시 시도해주세요."
                case NSURLErrorNetworkConnectionLost:
                    return "네트워크 연결이 끊어졌습니다."
                default:
                    return "네트워크 오류가 발생했습니다.\n잠시 후 다시 시도해주세요."
                }
            }
        }

        // PostError 처리
        if let postError = self as? PostError {
            return postError.errorDescription ?? "알 수 없는 오류가 발생했습니다."
        }

        // ChatError 처리
        if let chatError = self as? ChatError {
            return chatError.errorDescription ?? "알 수 없는 오류가 발생했습니다."
        }

        // 기본 에러 메시지가 기술적이면 변환
        let message = localizedDescription

        // 기술적인 메시지 패턴 감지
        if message.contains("Error Domain") ||
           message.contains("Code=") ||
           message.contains("UserInfo") ||
           message.lowercased().contains("null") ||
           message.lowercased().contains("nil") {
            return "일시적인 오류가 발생했습니다.\n잠시 후 다시 시도해주세요."
        }

        return message
    }
}
