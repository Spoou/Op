//
//  TorrentsListViewModel.swift
//  iTorrent
//
//  Created by Даниил Виноградов on 28.03.2022.
//

import MVVMFoundation
import ReactiveKit
import TorrentKit

struct TorrentListSortingModel: Codable {
    var type: `Type`
    var grouped: Bool = false
    var reversed: Bool = false

    enum `Type`: Equatable, Codable {
        case name
        case dateAdded
        case dateCreated
        case size
    }
}

class TorrentsListViewModel: MvvmViewModel {
    private let propertyManager = MVVM.resolve() as PropertyStorage
    private let torrentManager = MVVM.resolve() as TorrentManager
    @Bindable public var sections = [SectionModel<TorrentsListTorrentModel>]()
    @Bindable public var searchQuery: String?
    @Bindable public var selectedIndexPaths: [IndexPath] = []

    @Bindable public var sortingType: TorrentListSortingModel = .init(type: .name)

    var selectedTorrents: [TorrentHandle] {
        selectedIndexPaths.map { sections[$0.section].items[$0.row].torrent }
    }

    public var canResumeAny: SafeSignal<Bool> {
        $selectedIndexPaths.map { [unowned self] indexPaths -> Bool in
            indexPaths.contains { sections[$0.section].items[$0.row].torrent.canResume }
        }
    }

    public var canPauseAny: SafeSignal<Bool> {
        $selectedIndexPaths.map { [unowned self] indexPaths -> Bool in
            indexPaths.contains { sections[$0.section].items[$0.row].torrent.canPause }
        }
    }

    required init() {
        super.init()
        title.value = "iTorrent"
    }

    override func binding() {
        bind(in: bag) {
            propertyManager.$torrentListSortingType <=> $sortingType
            combineLatest($searchQuery, $sortingType, torrentManager.$torrents).map { [unowned self] query, sortingType, torrents -> [SectionModel<TorrentsListTorrentModel>] in
                var torrents = Array(torrents.values)
                torrents = torrents.filter({ torrent in
                    query?.lowercased().split(separator: " ").allSatisfy { torrent.name.lowercased().contains($0) } ?? true
                })
                return mapTorrentsIntoSections(torrents, sorting: sortingType)
            } => $sections
        }
    }

    func openPreferences() {
        navigate(to: TorrentSettingsViewModel.self)
    }

    func openTorrentDetails(at indexPath: IndexPath) {
        navigate(to: TorrentDetailsViewModel.self, prepare: sections[indexPath.section].items[indexPath.row].torrent, with: .detail)
    }

    func addTorrent(_ torrent: Downloadable) {
        MVVM.resolve(type: TorrentAddingService.self).addTorrent(torrent, from: .VM(self))
    }

    func removeTorrent(at index: IndexPath, deleteFiles: Bool) {
        let torrent = sections[index.section].items[index.row].torrent
        torrentManager.removeTorrent(torrent, deleteFiles: deleteFiles)
    }

    func resumeSelected() {
        selectedIndexPaths
            .filter {sections[$0.section].items[$0.row].torrent.canResume}
            .forEach { sections[$0.section].items[$0.row].torrent.resume() }
        selectedIndexPaths = selectedIndexPaths
    }

    func pauseSelected() {
        selectedIndexPaths
            .filter {sections[$0.section].items[$0.row].torrent.canPause}
            .forEach { sections[$0.section].items[$0.row].torrent.pause() }
        selectedIndexPaths = selectedIndexPaths
    }

    func rehashSelected() {
        selectedIndexPaths
            .forEach { sections[$0.section].items[$0.row].torrent.rehash() }
    }

    func removeSelected(withFiles: Bool) {
        selectedIndexPaths
            .forEach { torrentManager.removeTorrent(sections[$0.section].items[$0.row].torrent, deleteFiles: withFiles) }
    }
}

private extension TorrentsListViewModel {
    func mapTorrentsIntoSections(_ torrents: [TorrentHandle], sorting sortingType: TorrentListSortingModel) -> [SectionModel<TorrentsListTorrentModel>] {
        if !sortingType.grouped {
            var section = SectionModel<TorrentsListTorrentModel>()
            section.items = torrents.sorted(by: { sortTorrents($0, $1, sortingType) }).map { torrent in
                TorrentsListTorrentModel(torrent: torrent)
            }
            return [section]
        } else {
            let groups = Dictionary(grouping: torrents, by: { $0.displayState })
            return groups.map { section in
                SectionModel(header: section.key.description, items: section.value.sorted(by: { sortTorrents($0, $1, sortingType) }).map{ TorrentsListTorrentModel(torrent: $0) } )
            }.sorted(by: { $0.header ?? "" < $1.header ?? "" })
        }
    }

    func sortTorrents(_ lhs: TorrentHandle, _ rhs: TorrentHandle, _ sortingType: TorrentListSortingModel) -> Bool {
        switch sortingType.type {
        case .name:
            if !sortingType.reversed {
                return lhs.name < rhs.name
            } else {
                return lhs.name > rhs.name
            }
        case .dateAdded:
            let lhsDate = lhs.addedDate
            let rhsDate = rhs.addedDate
            if !sortingType.reversed {
                return lhsDate > rhsDate
            } else {
                return lhsDate < rhsDate
            }
        case .dateCreated:
            let lhsDate = lhs.creationDate ?? Date()
            let rhsDate = rhs.creationDate ?? Date()
            if !sortingType.reversed {
                return lhsDate > rhsDate
            } else {
                return lhsDate < rhsDate
            }
        case .size:
            if !sortingType.reversed {
                return lhs.totalWanted > rhs.totalWanted
            } else {
                return lhs.totalWanted < rhs.totalWanted
            }
        }
    }
}