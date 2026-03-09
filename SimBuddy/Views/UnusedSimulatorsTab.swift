import SwiftUI

struct UnusedSimulatorsTab: View {
    @ObservedObject var viewModel: StorageManagerViewModel

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter
    }()

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoadingSimulators {
                Spacer()
                ProgressView("시뮬레이터 정보 로딩 중...")
                Spacer()
            } else if viewModel.simulatorStorageInfos.isEmpty {
                Spacer()
                emptyState
                Spacer()
            } else {
                simulatorList
                Divider()
                bottomBar
            }
        }
        .task {
            if viewModel.simulatorStorageInfos.isEmpty {
                await viewModel.loadSimulatorStorage()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 40))
                .foregroundStyle(.green)
            Text("미사용 시뮬레이터가 없습니다")
                .font(.headline)
            Button("다시 스캔") {
                Task { await viewModel.loadSimulatorStorage() }
            }
        }
    }

    // MARK: - Simulator List

    private var simulatorList: some View {
        List {
            ForEach(viewModel.simulatorStorageInfos) { info in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(info.simulator.name)
                                .font(.callout)
                                .fontWeight(.medium)
                            Text(info.simulator.runtimeVersion)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if info.isRecommendedForCleanup {
                                Text("정리 추천")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.orange.opacity(0.2))
                                    .foregroundStyle(.orange)
                                    .clipShape(Capsule())
                            }
                        }
                        HStack(spacing: 12) {
                            if let lastBooted = info.lastBootedAt {
                                Text("마지막 사용: \(Self.dateFormatter.string(from: lastBooted))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("사용 기록 없음")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Spacer()

                    Text(ByteCountFormatter.string(fromByteCount: info.totalSize, countStyle: .file))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()

                    Button {
                        viewModel.confirmDeleteSimulator(info)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                    .help("시뮬레이터 삭제")
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            let recommendedCount = viewModel.simulatorStorageInfos.filter(\.isRecommendedForCleanup).count
            let totalSize = viewModel.simulatorStorageInfos.filter(\.isRecommendedForCleanup)
                .reduce(Int64(0)) { $0 + $1.totalSize }

            Text("추천 정리: \(recommendedCount)개 (\(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button("다시 스캔") {
                Task { await viewModel.loadSimulatorStorage() }
            }

            Button("추천 항목 전체 삭제") {
                viewModel.confirmDeleteRecommendedSimulators()
            }
            .disabled(viewModel.simulatorStorageInfos.filter(\.isRecommendedForCleanup).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
