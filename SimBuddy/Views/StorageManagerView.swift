import SwiftUI

struct StorageManagerView: View {
    @StateObject private var viewModel = StorageManagerViewModel()

    var body: some View {
        TabView(selection: $viewModel.selectedTab) {
            DeadFolderTab(viewModel: viewModel)
                .tabItem {
                    Label("Dead Folders", systemImage: "trash")
                }
                .tag(StorageManagerViewModel.Tab.deadFolders)

            UnusedSimulatorsTab(viewModel: viewModel)
                .tabItem {
                    Label("미사용 시뮬레이터", systemImage: "iphone.slash")
                }
                .tag(StorageManagerViewModel.Tab.unusedSimulators)

            AppStorageTab(viewModel: viewModel)
                .tabItem {
                    Label("앱 용량", systemImage: "app.badge.checkmark")
                }
                .tag(StorageManagerViewModel.Tab.appStorage)
        }
        .frame(minWidth: 500, minHeight: 350)
        .alert("오류", isPresented: $viewModel.showError) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "알 수 없는 오류가 발생했습니다.")
        }
        .alert("삭제 확인", isPresented: $viewModel.showDeleteConfirmation) {
            Button("취소", role: .cancel) {
                viewModel.pendingDeleteAction = nil
            }
            Button("삭제", role: .destructive) {
                Task {
                    await viewModel.executePendingDelete()
                }
            }
        } message: {
            Text(viewModel.deleteConfirmationMessage)
        }
    }
}

#Preview {
    StorageManagerView()
}
