import SwiftUI

struct PostListView: View {
    @StateObject private var viewModel = PostListViewModel()
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var locationService: LocationService
    @State private var selectedCategory: Post.Category?
    @State private var selectedPost: Post?
    @State private var showDuplicateAlert = false
    @State private var postToDelete: Post?
    @State private var showDeleteAlert = false
    @State private var showAccessDeniedAlert = false
    @State private var autoOpenedChatPostId: String? // 자동 입장한 채팅방 ID 추적
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 카테고리 필터 탭
                    HStack(spacing: 0) {
                        ForEach(PostListViewModel.CategoryFilter.allCases, id: \.self) { filter in
                            categoryFilterButton(filter: filter)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // 정렬 옵션
                    HStack {
                        sortButton(title: "시간순", type: .time)
                        sortButton(title: "거리순", type: .distance)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    
                    // 위치 권한 안내
                    if !locationService.isLocationAvailable {
                        locationRequiredBanner
                    }

                    // 게시글 목록
                    if viewModel.posts.isEmpty && !viewModel.isLoading {
                        emptyStateView
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.posts) { post in
                                    PostCardView(
                                        post: post,
                                        isParticipating: viewModel.isUserParticipating(in: post),
                                        currentLocation: locationService.currentLocation,
                                        currentUserId: authService.currentUser?.id,
                                        isLocationAvailable: locationService.isLocationAvailable,
                                        onParticipationToggle: {
                                            viewModel.toggleParticipation(for: post)
                                        },
                                        onDelete: {
                                            postToDelete = post
                                            showDeleteAlert = true
                                        }
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        handlePostTap(post)
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                }
                
                // FAB
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            // 위치 권한 확인
                            guard locationService.isLocationAvailable else {
                                locationService.requestLocationPermission()
                                return
                            }
                            // 이미 활성 게시글이 있는지 확인
                            if let userId = authService.currentUser?.id,
                               viewModel.hasActivePost(userId: userId) {
                                showDuplicateAlert = true
                            } else {
                                // 현재 탭에 맞는 카테고리로 약속 생성
                                selectedCategory = viewModel.categoryFilter == .run ? .run : .meal
                            }
                        }) {
                            Image(systemName: "plus")
                                .font(.googleSans(size: 24, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(locationService.isLocationAvailable ? Color.mainBlue : Color.gray)
                                .clipShape(Circle())
                                .shadow(color: (locationService.isLocationAvailable ? Color.mainBlue : Color.gray).opacity(0.3), radius: 8, y: 4)
                        }
                        .accessibilityLabel("새 약속 만들기")
                        .accessibilityHint(locationService.isLocationAvailable ? "탭하여 \(viewModel.categoryFilter.rawValue)을 만듭니다" : "위치 권한이 필요합니다")
                        .padding()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 28)
                }
            }
            .onAppear {
                setupViewModel()
                locationService.requestLocationPermission()
            }
            .onChange(of: viewModel.posts) { _, newPosts in
                checkAndAutoOpenChat(posts: newPosts)
            }
            .sheet(item: $selectedCategory) { category in
                CreatePostView(category: category)
            }
            .sheet(item: $selectedPost) { post in
                if post.shouldOpenChat {
                    ChatView(post: post)
                }
            }
            .errorAlert(error: $viewModel.error)
            .loadingOverlay(viewModel.isLoading)
            .modifier(PostListAlertsModifier(
                showDuplicateAlert: $showDuplicateAlert,
                showDeleteAlert: $showDeleteAlert,
                showAccessDeniedAlert: $showAccessDeniedAlert,
                postToDelete: postToDelete,
                onDelete: { post in
                    // 삭제할 게시글의 채팅방 자동 입장 방지
                    autoOpenedChatPostId = post.id
                    selectedPost = nil
                    viewModel.deletePost(post)
                }
            ))
        }
    }
    
    private func setupViewModel() {
        // EnvironmentObject 서비스를 ViewModel에 주입
        viewModel.configure(
            locationService: locationService,
            authService: authService
        )
    }
    
    private func sortButton(title: String, type: PostListViewModel.SortType) -> some View {
        Button(action: { viewModel.sortType = type }) {
            Text(title)
                .font(.googleSans(size: 14, weight: .medium))
                .foregroundColor(viewModel.sortType == type ? .white : .secondaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(
                    viewModel.sortType == type ? Color.mainBlue : Color.cardBackground
                )
                .cornerRadius(16)
        }
        .accessibilityLabel("\(title) 정렬")
        .accessibilityHint(viewModel.sortType == type ? "현재 선택됨" : "탭하여 \(title)로 정렬")
        .accessibilityAddTraits(viewModel.sortType == type ? .isSelected : [])
    }

    private func categoryFilterButton(filter: PostListViewModel.CategoryFilter) -> some View {
        Button(action: { viewModel.categoryFilter = filter }) {
            Text(filter.rawValue)
                .font(.googleSans(size: 15, weight: .medium))
                .foregroundColor(viewModel.categoryFilter == filter ? .mainBlue : .secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    VStack {
                        Spacer()
                        if viewModel.categoryFilter == filter {
                            Rectangle()
                                .fill(Color.mainBlue)
                                .frame(height: 2)
                        }
                    }
                )
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Text(viewModel.categoryFilter == .meal ? "🍽️" : "🏃")
                .font(.googleSans(size: 64))
                .accessibilityHidden(true)
            Text("아직 \(viewModel.categoryFilter.rawValue)이 없어요")
                .font(.googleSans(size: 17, weight: .semibold))
                .foregroundColor(.primaryText)
            Text("첫 번째 \(viewModel.categoryFilter.rawValue)을 만들어보세요")
                .font(.googleSans(size: 15))
                .foregroundColor(.secondaryText)
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("아직 \(viewModel.categoryFilter.rawValue)이 없어요. 첫 번째 \(viewModel.categoryFilter.rawValue)을 만들어보세요.")
    }

    private var locationRequiredBanner: some View {
        Button(action: {
            locationService.requestLocationPermission()
        }) {
            HStack {
                Image(systemName: "location.slash.fill")
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("위치 권한이 필요해요")
                        .font(.googleSans(size: 14, weight: .semibold))
                        .foregroundColor(.primaryText)
                    Text("약속 생성 및 참가를 위해 위치 권한을 허용해주세요")
                        .font(.googleSans(size: 12))
                        .foregroundColor(.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.googleSans(size: 12))
                    .foregroundColor(.secondaryText)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(10)
        }
        .padding(.horizontal)
    }
    
    private func handlePostTap(_ post: Post) {
        if post.shouldOpenChat {
            // 참가자만 채팅방 입장 가능
            if viewModel.isUserParticipating(in: post) {
                selectedPost = post
            } else {
                showAccessDeniedAlert = true
            }
        }
        // 참가하기/취소는 버튼으로만 처리
    }

    /// 참가 중인 약속의 채팅방이 열리면 자동 입장
    private func checkAndAutoOpenChat(posts: [Post]) {
        guard let userId = authService.currentUser?.id else { return }
        guard selectedPost == nil else { return } // 이미 채팅방 열려있으면 스킵

        // 내가 참가 중이고, 채팅방이 열렸고, 아직 자동 입장 안한 게시글 찾기
        if let postToOpen = posts.first(where: { post in
            post.participantIds.contains(userId) &&
            post.shouldOpenChat &&
            post.id != autoOpenedChatPostId
        }) {
            autoOpenedChatPostId = postToOpen.id
            selectedPost = postToOpen
        }
    }
}

// MARK: - Alerts Modifier
struct PostListAlertsModifier: ViewModifier {
    @Binding var showDuplicateAlert: Bool
    @Binding var showDeleteAlert: Bool
    @Binding var showAccessDeniedAlert: Bool
    let postToDelete: Post?
    let onDelete: (Post) -> Void

    func body(content: Content) -> some View {
        content
            .alert("이미 진행 중인 약속이 있습니다", isPresented: $showDuplicateAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("기존 약속이 끝난 후 새로운 약속을 만들어주세요.")
            }
            .alert("약속 삭제", isPresented: $showDeleteAlert) {
                Button("취소", role: .cancel) {}
                Button("삭제", role: .destructive) {
                    if let post = postToDelete {
                        onDelete(post)
                    }
                }
            } message: {
                Text("정말로 이 약속을 삭제하시겠습니까?")
            }
            .alert("채팅방 입장 불가", isPresented: $showAccessDeniedAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("약속에 참가한 사람만 채팅방에 입장할 수 있습니다.")
            }
    }
}

// MARK: - Post.Category Identifiable
extension Post.Category: Identifiable {
    var id: String { rawValue }
}
