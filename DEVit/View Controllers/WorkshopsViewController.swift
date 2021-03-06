//
//  WorkshopsViewController.swift
//  DEVit
//
//  Created by Athanasios Theodoridis on 28/10/2016.
//  Copyright © 2016 devitconf. All rights reserved.
//

import Foundation
import UIKit

import PKHUD

class WorkshopsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    // MARK: - IBOutlets
    @IBOutlet weak var workshopTypeSegmentedControl: UISegmentedControl!
    @IBOutlet weak var workshopsTableView: UITableView!
    
    class func instantiateFromStoryboard() -> WorkshopsViewController {
        
        let storyboardId = Constants.Storyboards.mainStoryboard
        let sceneId = Constants.Storyboards.Scenes.mainStoryboardWorkshopsViewControllerScene
        
        let storyboard = UIStoryboard(name: storyboardId, bundle: nil)
        return storyboard.instantiateViewController(
            withIdentifier: sceneId) as! WorkshopsViewController
    
    }
    
    // MARL: - Private Properties
    private lazy var ModelsManager = {
        FirebaseManager.sharedInstance
    }()

    private var _workshops:[Workshop] = []
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        _registerNotifications()
        _configureView()
        
        _loadWorkshops()
        
    }
    
    // MARK: - IBActions
    @IBAction func workshopTypeSegmentedControlDidChangeValue(sender: UISegmentedControl) {
        _populateWorkshopsBasedOnSegmentedControl()
    }
    
    // MARK: - Private Methods
    private func _loadWorkshops() {
        
        HUD.show(.progress)
        
        ModelsManager.startObservingWorkshopSnapshots()
        ModelsManager.startObservingSpeakerSnaphots()
        
    }
    
    private func _configureView() {
        
        title = "Workshops"
        
        view.backgroundColor = Colors.lightBlue
        workshopTypeSegmentedControl.tintColor = Colors.darkBlue
    
    }
    
    private func _populateWorkshopsBasedOnSegmentedControl() {
        
        _workshops.removeAll()
        
        switch workshopTypeSegmentedControl.selectedSegmentIndex {
        case 0:
            _workshops = ModelsManager.workshops
        case 1:
            _workshops = ModelsManager.workshops.filter( { $0.isAllDay == true })
        case 2:
            _workshops = ModelsManager.workshops.filter( { $0.isAllDay == false })
        
        default:
            _workshops = ModelsManager.workshops
        }
        
        workshopsTableView.reloadData()
        
    }
    
    // MARK: - UITableView Delegate/Datasource
    private enum WorkshopsTableViewCells {
        
        case workshop
        
        var reuseIdentifier: String {
            switch self {
            case .workshop:
                return "WorkshopCell"
            }
        }
        
        // TODO: Revisit to make use of UITableViewAutomaticDimension
        var cellHeight: CGFloat {
            switch self {
            case .workshop:
                return 100
            }
        }
        
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return _workshops.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let reuseId = WorkshopsTableViewCells.workshop.reuseIdentifier
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseId) as! WorkshopCell
        cell.workshop = _workshops[indexPath.row]
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return WorkshopsTableViewCells.workshop.cellHeight
    }
    
    // MARK: - Notifications
    private func _registerNotifications() {
        
        let nc = NotificationCenter.default
        nc.addObserver(self,
                       selector: #selector(self._reloadWorkshopsTableView),
                       name: Constants.Notifications.speakersWorkshopsAssociationFinished,
                       object: nil)
        
    }
    
    // MARK: Notification Selectors
    @objc private func _reloadWorkshopsTableView() {
        
        HUD.hide()
        _populateWorkshopsBasedOnSegmentedControl()
    
    }


}
