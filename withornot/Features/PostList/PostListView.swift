import SwiftUI

struct PostListView: View {
    @StateObject private var viewModel = PostListViewModel(
        locationService: LocationService(),
        authService: AuthService()
    )
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var locationService: LocationService
    @State private var showCreatePost = false
    @State private var selectedPost: Post?
    @State private var showDuplicateAlert = false
    @State private var postToDelete: Post?
    @State private var showDeleteAlert = false
    @State private var showAccessDeniedAlert = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 정렬 옵션
                    HStack {
                        sortButton(title: "시간순", type: .time)
                        sortButton(title: "거리순", type: .distance)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    
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
                            // 이미 활성 게시글이 있는지 확인
                            if let userId = authService.currentUser?.id,
                               viewModel.hasActivePost(userId: userId) {
                                showDuplicateAlert = true
                            } else {
                                showCreatePost = true
                            }
                        }) {
                            Image(systemName: "plus")
                                .font(.googleSans(size: 24, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.mainBlue)
                                .clipShape(Circle())
                                .shadow(color: Color.mainBlue.opacity(0.3), radius: 8, y: 4)
                        }
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
                        .frame(height: 30)
                }
            }
            .onAppear {
                setupViewModel()
                locationService.requestLocationPermission()
            }
            .sheet(isPresented: $showCreatePost) {
                CreatePostView()
            }
            .sheet(item: $selectedPost) { post in
                if post.shouldOpenChat {
                    ChatView(post: post)
                }
            }
            .errorAlert(error: $viewModel.error)
            .loadingOverlay(viewModel.isLoading)
            .alert("이미 진행 중인 약속이 있습니다", isPresented: $showDuplicateAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("기존 약속이 끝난 후 새로운 약속을 만들어주세요.")
            }
            .alert("약속 삭제", isPresented: $showDeleteAlert) {
                Button("취소", role: .cancel) {}
                Button("삭제", role: .destructive) {
                    if let post = postToDelete {
                        viewModel.deletePost(post)
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
    
    private func setupViewModel() {
        // ViewModel already starts listening in init
        // No additional setup needed
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
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("🏃")
                .font(.googleSans(size: 64))
            Text("아직 런닝 약속이 없어요")
                .font(.googleSans(size: 17, weight: .semibold))
                .foregroundColor(.primaryText)
            Text("첫 번째 러너가 되어보세요")
                .font(.googleSans(size: 15))
                .foregroundColor(.secondaryText)
            Spacer()
        }
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
}
