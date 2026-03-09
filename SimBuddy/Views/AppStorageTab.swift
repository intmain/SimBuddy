import SwiftUI

struct AppStorageTab: View {
    @ObservedObject var viewModel: StorageManagerViewModel

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoadingAppStorage {
                Spacer()
                ProgressView("앱 용량 분석 중...")
                Spacer()
            } else if viewModel.appStorageInfos.isEmpty {
                Spacer()
                emptyState
                Spacer()
            } else {
                appList
                Divider()
                bottomBar
            }
        }
        .task {
            if viewModel.appStorageInfos.isEmpty {
                await viewModel.loadAppStorage()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "app.dashed")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("앱 데이터가 없습니다")
                .font(.headline)
            Button("다시 스캔") {
                Task { await viewModel.loadAppStorage() }
            }
        }
    }

    // MARK: - App List

    private var appList: some View {
        List {
            ForEach(viewModel.appStorageInfos) { (info: AppStorageInfo) in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(info.appName)
                            .font(.callout)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        HStack(spacing: 8) {
                            Text(info.simulatorName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(info.bundleIdentifier)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Text(ByteCountFormatter.string(fromByteCount: info.size, countStyle: .file))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()

                    Button {
                        viewModel.openAppInFinder(info)
                    } label: {
                        Image(systemName: "folder")
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.borderless)
                    .help("Finder에서 열기")
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            let totalSize = viewModel.appStorageInfos.reduce(Int64(0)) { $0 + $1.size }

            Text("총 \(viewModel.appStorageInfos.count)개 앱, \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button("다시 스캔") {
                Task { await viewModel.loadAppStorage() }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
