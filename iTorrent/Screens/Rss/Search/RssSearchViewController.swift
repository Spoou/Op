//
//  RssSearchViewController.swift
//  iTorrent
//
//  Created by Daniil Vinogradov on 22/04/2024.
//

import UIKit

class RssSearchViewController<VM: RssSearchViewModel>: BaseCollectionViewController<VM> {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        disposeBag.bind {
            viewModel.emptyContentType.sink { [unowned self] emptyType in
                if #available(iOS 17.0, *) {
                    switch emptyType {
                    case .noData:
                        var config = UIContentUnavailableConfiguration.empty()
                        config.image = .icRss
                        config.text = %"rssSearch.empty.title"
                        config.secondaryText = %"rssSearch.empty.subtitle" 
                        contentUnavailableConfiguration = config
                    case .badSearch(let search):
                        var configuration = UIContentUnavailableConfiguration.search()
                        configuration.text = %"noContent.search.\(search)"
                        contentUnavailableConfiguration = configuration
                    case .badFilter:
                        contentUnavailableConfiguration = UIContentUnavailableConfiguration.empty()
                    case nil:
                        contentUnavailableConfiguration = nil
                    }
                }
            }
        }
    }
}
