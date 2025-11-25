//
//  CreatePostSections.swift
//  withornot
//
//  CreatePostView의 섹션 컴포넌트들
//

import SwiftUI

// MARK: - Message Section

struct CreatePostMessageSection: View {
    @Binding var message: String
    let quickMessages: [String]
    let onQuickSelect: (String) -> Void
    var focusedField: FocusState<CreatePostView.Field?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("메시지", systemImage: "text.bubble")
                .font(.googleSans(size: 13, weight: .medium))
                .foregroundColor(.secondaryText)

            TextField("자유롭게 한마디 (선택사항)", text: $message, axis: .vertical)
                .textFieldStyle(CustomTextFieldStyle())
                .lineLimit(3...5)
                .focused(focusedField, equals: .message)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickMessages, id: \.self) { quickMessage in
                        QuickSelectButton(
                            title: quickMessage,
                            isSelected: message == quickMessage
                        ) {
                            onQuickSelect(quickMessage)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Location Section

struct CreatePostLocationSection: View {
    @Binding var locationText: String
    let quickLocations: [String]
    let onQuickSelect: (String) -> Void
    var focusedField: FocusState<CreatePostView.Field?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("만남 장소", systemImage: "mappin.circle")
                .font(.googleSans(size: 13, weight: .medium))
                .foregroundColor(.secondaryText)

            TextField("예: 한강공원 뚝섬지구", text: $locationText)
                .textFieldStyle(CustomTextFieldStyle())
                .focused(focusedField, equals: .location)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickLocations, id: \.self) { location in
                        QuickSelectButton(
                            title: location,
                            isSelected: locationText == location
                        ) {
                            onQuickSelect(location)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Time Section

struct CreatePostTimeSection: View {
    @Binding var meetTime: Date
    let minimumDate: Date
    let maximumDate: Date
    let quickTimes: [(label: String, minutes: Int)]
    let onQuickSelect: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("만남 시간 (오늘)", systemImage: "clock")
                .font(.googleSans(size: 13, weight: .medium))
                .foregroundColor(.secondaryText)

            DatePicker(
                "",
                selection: $meetTime,
                in: minimumDate...maximumDate,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(WheelDatePickerStyle())
            .labelsHidden()
            .frame(height: 120)
            .clipped()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickTimes, id: \.minutes) { time in
                        QuickSelectButton(
                            title: time.label,
                            isSelected: false
                        ) {
                            onQuickSelect(time.minutes)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Info Section

struct CreatePostInfoSection: View {
    let isLocationAvailable: Bool

    var body: some View {
        VStack(spacing: 16) {
            if isLocationAvailable {
                LocationStatusView()
            }

            ChatInfoView()
        }
    }
}

// MARK: - Helper Views

private struct LocationStatusView: View {
    var body: some View {
        HStack {
            Image(systemName: "location.fill")
                .foregroundColor(.green)
            Text("현재 위치 기반 거리 표시 활성화")
                .font(.googleSans(size: 13))
            Spacer()
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(10)
    }
}

private struct ChatInfoView: View {
    var body: some View {
        HStack {
            Image(systemName: "info.circle.fill")
                .foregroundColor(Color.mainBlue)
                .font(.googleSans(size: 16))
            Text("약속시간 5분 전, 채팅창이 열려요!")
                .font(.googleSans(size: 14, weight: .medium))
                .foregroundColor(.primaryText)
            Spacer()
        }
        .padding()
        .background(Color.mainBlue.opacity(0.1))
        .cornerRadius(10)
    }
}
