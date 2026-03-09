import Foundation
import SwiftUI

@MainActor
final class StorageManagerViewModel: ObservableObject {

    // MARK: - Tab Selection

    enum Tab: Hashable {
        case deadFolders
        case unusedSimulators
        case appStorage
    }

    @Published var selectedTab: Tab = .deadFolders

    // MARK: - Dead Folders

    @Published var deadFolders: [DeadFolder] = []
    @Published var isScanning = false

    // MARK: - Unused Simulators

    @Published var simulatorStorageInfos: [SimulatorStorageInfo] = []
    @Published var isLoadingSimulators = false

    // MARK: - App Storage

    @Published var appStorageInfos: [AppStorageInfo] = []
    @Published var isLoadingAppStorage = false

    // MARK: - Common

    @Published var errorMessage: String?
    @Published var showError = false
    @Published var showDeleteConfirmation = false
    @Published var deleteConfirmationMessage = ""
    var pendingDeleteAction: (@MainActor () async -> Void)?

    // MARK: - Dependencies

    private let storageService = StorageService()

    // MARK: - Dead Folder Actions

    func scanDeadFolders() async {
        isScanning = true
        deadFolders = await storageService.scanDeadFolders()
        isScanning = false
    }

    func toggleDeadFolder(_ folder: DeadFolder) {
        guard let index = deadFolders.firstIndex(where: { $0.id == folder.id }) else { return }
        deadFolders[index].isSelected.toggle()
    }

    func selectAllDeadFolders() {
        for index in deadFolders.indices {
            deadFolders[index].isSelected = true
        }
    }

    func confirmDeleteSelectedDeadFolders() {
        let selected = deadFolders.filter(\.isSelected)
        guard !selected.isEmpty else { return }

        let totalSize = selected.reduce(Int64(0)) { $0 + $1.size }
        let formatted = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        deleteConfirmationMessage = "\(selected.count)개 폴더(\(formatted))를 삭제하시겠습니까?\n삭제된 항목은 휴지통으로 이동됩니다."
        pendingDeleteAction = { [weak self] in
            await self?.deleteSelectedDeadFolders()
        }
        showDeleteConfirmation = true
    }

    func confirmDeleteAllDeadFolders() {
        selectAllDeadFolders()
        confirmDeleteSelectedDeadFolders()
    }

    private func deleteSelectedDeadFolders() async {
        let selected = deadFolders.filter(\.isSelected)
        for folder in selected {
            do {
                try storageService.moveToTrash(at: folder.path)
                deadFolders.removeAll { $0.id == folder.id }
            } catch {
                errorMessage = "삭제 실패: \(folder.path.lastPathComponent) - \(error.localizedDescription)"
                showError = true
                return
            }
        }
    }

    // MARK: - Unused Simulator Actions

    func loadSimulatorStorage() async {
        isLoadingSimulators = true
        simulatorStorageInfos = await storageService.getSimulatorStorageInfo()
        isLoadingSimulators = false
    }

    func confirmDeleteSimulator(_ info: SimulatorStorageInfo) {
        let formatted = ByteCountFormatter.string(fromByteCount: info.totalSize, countStyle: .file)
        deleteConfirmationMessage = "\(info.simulator.name)(\(formatted))을 삭제하시겠습니까?\n삭제된 항목은 휴지통으로 이동됩니다."
        pendingDeleteAction = { [weak self] in
            await self?.deleteSimulator(info)
        }
        showDeleteConfirmation = true
    }

    func confirmDeleteRecommendedSimulators() {
        let recommended = simulatorStorageInfos.filter(\.isRecommendedForCleanup)
        guard !recommended.isEmpty else { return }

        let totalSize = recommended.reduce(Int64(0)) { $0 + $1.totalSize }
        let formatted = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        deleteConfirmationMessage = "추천 항목 \(recommended.count)개(\(formatted))를 삭제하시겠습니까?\n삭제된 항목은 휴지통으로 이동됩니다."
        pendingDeleteAction = { [weak self] in
            await self?.deleteRecommendedSimulators()
        }
        showDeleteConfirmation = true
    }

    private func deleteSimulator(_ info: SimulatorStorageInfo) async {
        let path = URL(fileURLWithPath: info.simulator.dataPath)
        do {
            try storageService.moveToTrash(at: path)
            simulatorStorageInfos.removeAll { $0.id == info.id }
        } catch {
            errorMessage = "삭제 실패: \(info.simulator.name) - \(error.localizedDescription)"
            showError = true
        }
    }

    private func deleteRecommendedSimulators() async {
        let recommended = simulatorStorageInfos.filter(\.isRecommendedForCleanup)
        for info in recommended {
            let path = URL(fileURLWithPath: info.simulator.dataPath)
            do {
                try storageService.moveToTrash(at: path)
                simulatorStorageInfos.removeAll { $0.id == info.id }
            } catch {
                errorMessage = "삭제 실패: \(info.simulator.name) - \(error.localizedDescription)"
                showError = true
                return
            }
        }
    }

    // MARK: - App Storage Actions

    func loadAppStorage() async {
        isLoadingAppStorage = true
        appStorageInfos = await storageService.getAppStorageInfo()
            .sorted { $0.size > $1.size }
        isLoadingAppStorage = false
    }

    func openAppInFinder(_ info: AppStorageInfo) {
        NSWorkspace.shared.open(info.sandboxPath)
    }

    // MARK: - Helpers

    func executePendingDelete() async {
        await pendingDeleteAction?()
        pendingDeleteAction = nil
    }
}
