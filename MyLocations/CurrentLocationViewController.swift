//
//  FirstViewController.swift
//  MyLocations
//
//  Created by Alex Fedoseev on 24.07.2018.
//  Copyright © 2018 Alex Fedoseev. All rights reserved.
//

import UIKit
import CoreLocation
import CoreData

class CurrentLocationViewController: UIViewController, CLLocationManagerDelegate {

    
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var latitudeLabel: UILabel!
    @IBOutlet weak var longitudeLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var tagButton: UIButton!
    @IBOutlet weak var getButton: UIButton!
    
    let locationManager = CLLocationManager()
    var location: CLLocation?
    
    var updatingLocation = false
    var lastLocationError: Error?
    
    let geocoder = CLGeocoder()
    var placemark: CLPlacemark?
    var performingReverseGeocoding = false
    var lastGeocodingError: Error?
    
    var timer: Timer?
    
    var managedObjectContext: NSManagedObjectContext!
    
    @IBOutlet weak var latitudeTextLabel: UILabel!
    @IBOutlet weak var longitudeTextLabel: UILabel!
    
    @IBOutlet weak var containerView: UIView!
    
    var logoVisible = false
    
    lazy var logoButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setBackgroundImage(UIImage(named: "Logo"), for: .normal)
        button.sizeToFit()
        button.addTarget(self, action: #selector(getLocation),
                         for: .touchUpInside)
        button.center.x = self.view.bounds.midX
        button.center.y = 220
        return button
    }()
    
    @IBAction func getLocation() {
        
        let authStatus = CLLocationManager.authorizationStatus()
        
        if authStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
            return
        }
        
        if authStatus == .denied || authStatus == .restricted {
            showLocationServicesDeniedAlert()
            return
        }
        
        if updatingLocation {
            stopLocationManager()
        } else {
            location = nil
            lastLocationError = nil
            startLocationManager()
        }
        placemark = nil
        lastGeocodingError = nil
        updateLabels()
        configureGetButton()
        
    }
    
    func showLocationServicesDeniedAlert() {
        let alert = UIAlertController(title: "Location Services Disabled",
                                      message:
            "Please enable location services for this app in Settings.",
                                      preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default,
                                     handler: nil)
        present(alert, animated: true, completion: nil)
        alert.addAction(okAction)
    }
    
    func updateLabels() {
        if let location = location {
            latitudeLabel.text =
                String(format: "%.8f", location.coordinate.latitude)
            longitudeLabel.text =
                String(format: "%.8f", location.coordinate.longitude)
            tagButton.isHidden = false
            messageLabel.text = ""
            
            if let placemark = placemark {
                addressLabel.text = string(from: placemark)
            } else if performingReverseGeocoding {
                addressLabel.text = "Searching for Address..."
            } else if lastGeocodingError != nil {
                addressLabel.text = "Error Finding Address"
            } else {
                addressLabel.text = "No Address Found"
            }
            
            latitudeTextLabel.isHidden = false
            longitudeTextLabel.isHidden = false
                
        } else {
            latitudeLabel.text = ""
            longitudeLabel.text = ""
            addressLabel.text = ""
            tagButton.isHidden = true
            
            let statusMessage: String
            if let error = lastLocationError as? NSError {
                if error.domain == kCLErrorDomain &&
                    error.code == CLError.denied.rawValue {
                    statusMessage = "Location Services Disabled"
                } else {
                    statusMessage = "Error Getting Location"
                }
            } else if !CLLocationManager.locationServicesEnabled() {
                statusMessage = "Location Services Disabled"
            } else if updatingLocation {
                statusMessage = "Searching..."
            } else {
                statusMessage = ""
                showLogoView()
            }
            messageLabel.text = statusMessage
            
            latitudeTextLabel.isHidden = true
            longitudeTextLabel.isHidden = true
        }
    }
    
    func string(from placemark: CLPlacemark) -> String {
        var line1 = ""
        line1.add(text: placemark.subThoroughfare)
        line1.add(text: placemark.thoroughfare, separatedBy: " ")
        var line2 = ""
        line2.add(text: placemark.locality)
        line2.add(text: placemark.administrativeArea, separatedBy: " ")
        line2.add(text: placemark.postalCode, separatedBy: " ")
        line1.add(text: line2, separatedBy: "\n")
        return line1
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateLabels()
        configureGetButton()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func startLocationManager() {
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.startUpdatingLocation()
            updatingLocation = true
            
            timer = Timer.scheduledTimer(timeInterval: 60, target: self,
                                         selector: #selector(didTimeOut), userInfo: nil, repeats: false)
        }
    }
    
    func stopLocationManager() {
        if updatingLocation {
            locationManager.stopUpdatingLocation()
            locationManager.delegate = nil
            updatingLocation = false
            
            if let timer = timer {
                timer.invalidate()
            }
        }
    }
    
    @objc func didTimeOut() {
        print("*** Time out")
        //if location == nil { //alexfed
            stopLocationManager()
            lastLocationError = NSError(domain: "MyLocationsErrorDomain",
                                        code: 1, userInfo: nil)
            updateLabels()
            configureGetButton()
        //}
    }

    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager,
                         didFailWithError error: Error) {
        print("didFailWithError \(error)")
        if (error as NSError).code == CLError.locationUnknown.rawValue {
            return
        }
        lastLocationError = error
        stopLocationManager()
        updateLabels()
        configureGetButton()
    }
    
    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        let newLocation = locations.last!
        print("didUpdateLocations \(newLocation)")
        // 1
        if newLocation.timestamp.timeIntervalSinceNow < -5 {
            return
        }
        // 2
        if newLocation.horizontalAccuracy < 0 {
            return
        }
        
        // This section is new!
        var distance = CLLocationDistance(DBL_MAX)
        if let location = location {
            distance = newLocation.distance(from: location)
        }
        
        // 3
        if location == nil ||
            location!.horizontalAccuracy > newLocation.horizontalAccuracy {
            // 4
            lastLocationError = nil
            location = newLocation
            updateLabels()
            // 5
            if newLocation.horizontalAccuracy <= locationManager.desiredAccuracy {
                print("*** We're done!")
                stopLocationManager()
                configureGetButton()
                // This statement is new!
                if distance > 0 {
                    performingReverseGeocoding = false
                }
            }
            
            
                if !performingReverseGeocoding {
                    print("*** Going to geocode")
                    performingReverseGeocoding = true
                    geocoder.reverseGeocodeLocation(newLocation, completionHandler: {
                        placemarks, error in
                        print("*** Found placemarks: \(placemarks), error: \(error)")
                        
                        self.lastGeocodingError = error
                        if error == nil, let p = placemarks, !p.isEmpty {
                            self.placemark = p.last!
                        } else {
                            self.placemark = nil
                        }
                        self.performingReverseGeocoding = false
                        self.updateLabels()
                    })
                } else if distance < 1 {
                    let timeInterval = newLocation.timestamp.timeIntervalSince(location!.timestamp)
                    if timeInterval > 10 {
                        print("*** Force done!")
                        stopLocationManager()
                        updateLabels()
                        configureGetButton()
                    }
            }
            
        }
    }
    
    func configureGetButton() {
        if updatingLocation {
            getButton.setTitle("Stop", for: .normal)
        } else {
            getButton.setTitle("Get My Location", for: .normal)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "TagLocation" {
            let navigationController = segue.destination
                as! UINavigationController
            let controller = navigationController.topViewController
                as! LocationDetailsViewController
            controller.coordinate = location!.coordinate
            controller.placemark = placemark
            controller.managedObjectContext = managedObjectContext
        }
    }
    
    // MARK: - Logo View
    func showLogoView() {
        if !logoVisible {
            logoVisible = true
            containerView.isHidden = true
            view.addSubview(logoButton)
        }
        
    }
    
}
