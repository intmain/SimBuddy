import SwiftUI

struct DeadFolderTab: View {
    @ObservedObject var viewModel: StorageManagerViewModel

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isScanning {
                Spacer()
                ProgressView("Dead folder 스캔 중...")
                Spacer()
            } else if viewModel.deadFolders.isEmpty {
                Spacer()
                emptyState
                Spacer()
            } else {
                folderList
                Divider()
                bottomBar
            }
        }
        .task {
            if viewModel.deadFolders.isEmpty {
                await viewModel.scanDeadFolders()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 40))
                .foregroundStyle(.green)
            Text("Dead folder가 없습니다")
                .font(.headline)
            Text("모든 시뮬레이터 폴더가 정상입니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("다시 스캔") {
                Task { await viewModel.scanDeadFolders() }
            }
        }
    }

    // MARK: - Folder List

    private var folderList: some View {
        List {
            ForEach(viewModel.deadFolders) { folder in
                HStack {
                    Toggle(isOn: Binding(
                        get: { folder.isSelected },
                        set: { _ in viewModel.toggleDeadFolder(folder) }
                    )) {
                        EmptyView()
                    }
                    .toggleStyle(.checkbox)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(folder.path.lastPathComponent)
                            .font(.callout)
                            .lineLimit(1)
                        Text(folder.path.path)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Spacer()

                    Text(ByteCountFormatter.string(fromByteCount: folder.size, countStyle: .file))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            let selectedCount = viewModel.deadFolders.filter(\.isSelected).count
            let totalSize = viewModel.deadFolders.filter(\.isSelected)
                .reduce(Int64(0)) { $0 + $1.size }

            Text("선택: \(selectedCount)개 (\(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button("다시 스캔") {
                Task { await viewModel.scanDeadFolders() }
            }

            Button("전체 삭제") {
                viewModel.confirmDeleteAllDeadFolders()
            }
            .disabled(viewModel.deadFolders.isEmpty)

            Button("선택 삭제") {
                viewModel.confirmDeleteSelectedDeadFolders()
            }
            .disabled(viewModel.deadFolders.filter(\.isSelected).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
