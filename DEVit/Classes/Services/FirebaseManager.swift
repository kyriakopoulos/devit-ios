//
//  FirebaseManager.swift
//  DEVit
//
//  Created by Athanasios Theodoridis on 27/10/2016.
//  Copyright © 2016 devitconf. All rights reserved.
//

import Foundation

import Firebase
import FirebaseDatabase
import FirebaseStorage
import ObjectMapper

public class FirebaseManager {
    
    // MARK: - Storage
    let speakerProfilePicsRef = FIRStorage.storage()
                                .reference(forURL: "gs://devit-15a6e.appspot.com")
                                .child("speaker_profile_pics")
    
    let sponsorLogosRef = FIRStorage.storage()
        .reference(forURL: "gs://devit-15a6e.appspot.com")
        .child("sponsors")
    
    // MARK: - Database
    let rootDbRef = FIRDatabase.database().reference()
    let attendeesDbRef = FIRDatabase.database().reference(withPath: "attendees")
    let talksDbRef = FIRDatabase.database().reference(withPath: "talks")
    let speakersDbRef = FIRDatabase.database().reference(withPath: "speakers")
    let workshopsDbRef = FIRDatabase.database().reference(withPath: "workshops")
    let ratingsDbRef = FIRDatabase.database().reference(withPath: "ratings")
    let sponsorsDbRef = FIRDatabase.database().reference(withPath: "sponsors")
    
    // MARK: - Singleton
    static let sharedInstance = FirebaseManager()
    public init() {
        _registerNotifications()
    }
    
    // MARK: - Public Properties
    public var user:FIRUser? = nil
    public var talks:[Talk] = []
    public var speakers:[Speaker] = []
    public var workshops:[Workshop] = []
    public var ratings:[Rating] = []
    
    // MARK: - Private Properties
    private lazy var Defaults = {
        return UserDefaults.standard
    }()
    
    private var talksObserverHandler: UInt = 0
    private var speakersObserverHandler: UInt = 0
    private var workshopsObserverHandler: UInt = 0
    private var ratingsObserverHandler: UInt = 0
    
    private var attendees: [Attendee] = []
    
    // MARK: - Private Methods
    private func _sanitizedEmailFromUserDefaults() -> String {
        
        var email = UserDefaults.standard.value(forKey: Constants.UserDefaults.userEmail) as! String
        
        email = email.replacingOccurrences(of: "#", with: "-")
        email = email.replacingOccurrences(of: ".", with: "__")
        
        return email
    
    }
    
    // MARK: - Public Methods
    public func getAttendeesEmails(
        withCompletionHandler handler: @escaping (_ attendees: [Attendee]?, _ error: Error? )-> Void)
    {
        
        l.verbose("Getting atteendees list")
        
        attendeesDbRef.observeSingleEvent(of: .value, with: { (snapshot) in
        
            guard let attendeesJSON = snapshot.value as? NSArray else {
                handler([], nil)
                return
            }
            
            let attendees = Mapper<Attendee>().mapArray(JSONArray: attendeesJSON as! [[String : Any]])
            self.attendees = attendees!
            
            handler(attendees, nil)
            
        }) { (error) in
            handler(nil, error)
        }
    
    }
    
    public func performLogin(
        withEmail email: String?,
        handler: @escaping (_ isLoggedIn: Bool) -> Void)
    {
        
        l.verbose("Performing login")
        
        getAttendeesEmails { attendees, error in
            
            guard let attendees = attendees,
                    let currentEmail = email,
                    error == nil,
                    attendees.count > 0 else
            {
                    handler(false)
                    return
            }
            
            let tmp = attendees.filter { $0.email! == currentEmail && $0.isLoggedIn == false }
            
            // Atttendee e-mail found
            if tmp.count == 1 {
                
                // Sign-in anonymously just to have a token
                FIRAuth.auth()?.signInAnonymously { (user, error) in
                    
                    l.verbose("Signing in anonymously with Firebase")
                    
                    if (error != nil) {
                        handler(false)
                    } else {
                        self.user = user
                        handler(true)
                    }
                
                }
                
            } else {
                handler(false)
            }
            
        }
        
    }
    
    public func startObservingTalkSnapshots() {
        
        l.verbose("Start observing `talks` snapshots")
        
        talksObserverHandler = talksDbRef.observe(.value, with: { (snapshot) in
        
            guard let talksJSON = snapshot.value as? [String: AnyObject] else {
                return
            }
            
            self.talks.removeAll()
            
            talksJSON.forEach { talk in
        
                if let talk = Mapper<Talk>().map(JSONObject: talk.value) {
                    self.talks.append(talk)
                }

            }
            
            self.talks.sort { $0.order! < $1.order! }
            
            NotificationCenter.default.post(
                name: Constants.Notifications.talksSnapshotUpdated,
                object: nil)
            
            l.verbose("Fetched talks.")
            
        
        })
        
    }
    
    public func stopObservingTalksSnapshots() {
        talksDbRef.removeObserver(withHandle: talksObserverHandler)
    }
    
    public func startObservingSpeakerSnaphots() {
       
        l.verbose("Getting speakers list")
        
        speakersObserverHandler = speakersDbRef.observe(.value, with: { (snapshot) in
            
            guard let speakersJSON = snapshot.value as? NSDictionary else {
                return
            }
            
            self.speakers.removeAll()
            
            speakersJSON.forEach { speaker in
                if let speaker = Mapper<Speaker>().map(JSONObject: speaker.value) {
                    self.speakers.append(speaker)
                }
            }
            
            NotificationCenter.default.post(
                name: Constants.Notifications.speakersSnapshotUpdated,
                object: nil)
            
            l.verbose("Fetched speakers.")
            
        })
        
    }
    
    public func stopObservingSpeakersSnapshots() {
        speakersDbRef.removeObserver(withHandle: speakersObserverHandler)
    }
    
    public func startObservingWorkshopSnapshots() {
        
        l.verbose("Getting workshops")
        
        workshopsObserverHandler = workshopsDbRef.observe(.value, with: { (snapshot) in
            
            guard let workshopsJSON = snapshot.value as? [String: AnyObject] else {
                return
            }
            
            self.workshops.removeAll()
            
            workshopsJSON.forEach { workshop in
                
                if let workshop = Mapper<Workshop>().map(JSONObject: workshop.value) {

                    self.workshops.append(workshop)
                }
            }
            
            self.workshops.sort { $0.order! < $1.order! }
            
            NotificationCenter.default.post(
                name: Constants.Notifications.workshopsSnapshotUpdated,
                object: nil)
            
            l.verbose("Fetched workshops.")
            
        })
        
    }
    
    public func stopObservingWorkshopSnapshots() {
        workshopsDbRef.removeObserver(withHandle: workshopsObserverHandler)
    }
    
    public func startObservingRatingSnapshots() {
     
        l.verbose("Getting talk ratings")
        
        ratingsObserverHandler = ratingsDbRef.observe(.value, with: { (snapshot) in
        
            guard let ratingsJSON = snapshot.value as? [String: AnyObject] else {
                return
            }
            
            self.ratings.removeAll()
            
            ratingsJSON.forEach { key, value in
                
                let email = self._sanitizedEmailFromUserDefaults()
                if let rating = Mapper<Rating>().map(JSONObject: value[email]!) {
                
                    rating.id = key
                    self.ratings.append(rating)
                
                }
            
            }
            
            l.verbose("Fetched ratings.")
            
        })
    }
    
    public func stopObservingRatingSnapshots() {
        ratingsDbRef.removeObserver(withHandle: ratingsObserverHandler)
    }
    
    public func getSponsors(withCompletionHandler handler:
        @escaping (_ sponsors: [String : [Sponsor]]?, _ error: Error? )-> Void)
    {
        
        l.verbose("Getting sponsors list")
        
        sponsorsDbRef.observeSingleEvent(of: .value, with: { (snapshot) in
            
            guard let sponsorsJSON = snapshot.value as? [String: AnyObject] else {
                handler([:], nil)
                return
            }
            
            var sponsorsResult: [String: [Sponsor]] = [:]
            
            sponsorsJSON.forEach { key, sponsors in
                
                sponsorsResult[key] = []
                let sponsors = sponsors as! Array<Any>
                
                sponsors.forEach { sponsor in
                    
                    if let sponsor = Mapper<Sponsor>().map(JSONObject: sponsor) {
                        sponsorsResult[key]?.append(sponsor)
                    }

                }
            }
            
            handler(sponsorsResult, nil)
            
        }) { (error) in
            handler(nil, error)
        }
        
    }

    public func addTopicRating(forTalkId id: String, rating: Double) {
        
        ratingsDbRef
            .child(id)
            .child(_sanitizedEmailFromUserDefaults())
            .updateChildValues(["topic": rating])
    
    }
    
    public func addPresentationRating(forTalkId id: String, rating: Double) {
        
        ratingsDbRef
            .child(id)
            .child(_sanitizedEmailFromUserDefaults())
            .updateChildValues(["presentation": rating])
        
    }
    
    // MARK: - Notifications
    private func _registerNotifications() {
        
        let nc = NotificationCenter.default
        
        nc.addObserver(self,
                       selector: #selector(self._associateTalksWithSpeakers),
                       name: Constants.Notifications.speakersSnapshotUpdated,
                       object: nil)
        
        nc.addObserver(self,
                       selector: #selector(self._associateTalksWithSpeakers),
                       name: Constants.Notifications.talksSnapshotUpdated,
                       object: nil)
        
        nc.addObserver(self,
                       selector: #selector(self._associateWorkshopsWithSpeakers),
                       name: Constants.Notifications.workshopsSnapshotUpdated,
                       object: nil)
        
        nc.addObserver(self,
                       selector: #selector(self._associateWorkshopsWithSpeakers),
                       name: Constants.Notifications.speakersSnapshotUpdated,
                       object: nil)
    
    }
    
    // MARK: Selectors
    @objc private func _associateTalksWithSpeakers() {
        
        l.verbose("Associating talks with speakers")
        
        guard speakers.count > 0, talks.count > 0 else {
            l.verbose("Speakers or talks is still empty")
            return
        }
        
        for talk in talks {
            
            guard let speakerId = talk.speakerId else {
                continue
            }
            
            if let speaker = speakers.filter({ $0.id == speakerId }).first {
                talk.speaker = speaker
                speaker.talk = talk
            }
       
        }
        
        speakers.sort {
            if let talk1 = $0.talk, let talk2 = $1.talk {
                return talk1.order! < talk2.order!
            }
            return true
        }
        
        l.verbose("Finished associating talks with speakers")

        NotificationCenter.default.post(
            name: Constants.Notifications.speakersTalksAssociationFinished,
            object: nil)
        
    }
    
    @objc private func _associateWorkshopsWithSpeakers() {
        
        l.verbose("Associating workshops with speakers")
        
        guard speakers.count > 0, workshops.count > 0 else {
            l.verbose("Speakers or workshops still empty")
            return
        }
        
        for workshop in workshops {
            
            guard let speakerId = workshop.speakerId else {
                continue
            }
            
            if let speaker = speakers.filter ( { $0.id == speakerId }).first {
                workshop.speaker = speaker
                speaker.workshop = workshop
            }
        }
        
        l.verbose("Finished associating workshops with speakers")
        
        NotificationCenter.default.post(
            name: Constants.Notifications.speakersWorkshopsAssociationFinished,
            object: nil)
        
    }

       
}
