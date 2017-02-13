//
//  ViewController.swift
//  caravan-ios
//
//  Created by Nancy on 1/25/17.
//  Copyright © 2017 Nancy. All rights reserved.
//

import UIKit
import Mapbox
import MapboxDirections
import Firebase
import MapboxGeocoder

enum menuState {
    case Collapsed
    case Expanded
}

class ViewController: UIViewController, MGLMapViewDelegate, CLLocationManagerDelegate, UIGestureRecognizerDelegate {
    
    @IBOutlet var mapView: MGLMapView!
    
    var ref: FIRDatabaseReference!
    let locationManager = CLLocationManager()
    var locValue: CLLocationCoordinate2D!
    let geocoder = Geocoder.sharedGeocoder
    let directions = Directions.shared
    
    var menuView: UITableView?
    var menuState: menuState = .Collapsed
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        // set up menu
        menuView = UITableView.init(frame: CGRect.init(x: -400, y: 0, width: 400, height: self.view.frame.height))
        
        //menuView!.backgroundColor = UIColor.black
        
        self.view.addSubview(menuView!)
        
        // create & add the screen edge gesture recognizer to open the menu
        let edgePanGR = UIScreenEdgePanGestureRecognizer(target: self,
                                                         action: #selector(self.handleEdgePan(recognizer:)))
        edgePanGR.edges = .left
        edgePanGR.delegate = self
        self.view.addGestureRecognizer(edgePanGR)
        
        //create & add the tap gesutre recognizer to close the menu
        let tapGR = UITapGestureRecognizer(target: self,
                                           action: #selector(self.handleTap(recognizer:)))
        tapGR.delegate = self
        self.view.addGestureRecognizer(tapGR)
    
        // FIREBASE DATABASE STUFF
        ref = FIRDatabase.database().reference()
        
        // Ask for Authorisation from the User.
        self.locationManager.requestAlwaysAuthorization()
        
        // For use in foreground
        self.locationManager.requestWhenInUseAuthorization()
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.startUpdatingLocation()
        }
        
        mapView.delegate = self
        
        let point = MGLPointAnnotation()
        point.coordinate = CLLocationCoordinate2D(latitude: 35.301355, longitude: -120.660459)
        point.title = "California Polytechnic San Luis Obispo"
        point.subtitle = "1 Grand Ave San Luis Obispo CA, U.S.A"
        mapView.addAnnotation(point)
    }
    

    // GESTURE RECOGNIZERS
    func handleEdgePan(recognizer: UIScreenEdgePanGestureRecognizer) {
        // open animation of menu
        self.openMenu()
    
        // TODO: should also disable all buttons on the groups view
    }

    func handleTap(recognizer: UITapGestureRecognizer) {
        // check if menu is expanded & if tap is in correct area
        let point = recognizer.location(in: self.view)
        if (menuState == .Expanded && point.x >= 300){
            // close the menu
            self.closeMenu()
        }
    }

    // ANIMATIONS
    func closeMenu() {
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut,
                       animations: {
                        self.menuView!.frame.origin.x = -400 // <= replace this magic number
                       },
                       completion: { finished in
                        self.menuState = .Collapsed
                       }
        )
    }

    func openMenu() {
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut,
                       animations: {
                        self.menuView!.frame.origin.x = -100 // <= replace this magic number
                       },
                       completion: { finished in
                        self.menuState = .Expanded
                       }
        )
    }

    // BUTTON ACTION
    @IBAction func menuTapped(_ sender: UIButton) {
        if (menuState == .Collapsed) {
            openMenu()
            menuState = .Expanded
        } else {
            closeMenu()
            menuState = .Collapsed
        }
    }

    @IBAction func sendLocationPressed(_ sender: Any) {
        //let username = "Spud"
        //ref.child("users/1/username").setValue(username)
        print("sending long: \(locValue.longitude) lat: \(locValue.latitude)")
        ref.child("users/1/coord/longitude").setValue(locValue.longitude)
        ref.child("users/1/coord/latitude").setValue(locValue.latitude)
    }
    
    func mapbox() {
        let waypoints = [
            Waypoint(
                coordinate: CLLocationCoordinate2D(latitude: 38.9131752, longitude: -77.0324047),
                name: "Mapbox"
            ),
            Waypoint(
                coordinate: CLLocationCoordinate2D(latitude: 38.8977, longitude: -77.0365),
                name: "White House"
            ),
            ]
        let options = RouteOptions(waypoints: waypoints, profileIdentifier: MBDirectionsProfileIdentifierAutomobile)
        options.includesSteps = true
        
        _ = directions.calculate(options) { (waypoints, routes, error) in
            guard error == nil else {
                print("Error calculating directions: \(error!)")
                return
            }
            
            if let route = routes?.first, let leg = route.legs.first {
                print("Route via \(leg):")
                
                let distanceFormatter = LengthFormatter()
                let formattedDistance = distanceFormatter.string(fromMeters: route.distance)
                
                let travelTimeFormatter = DateComponentsFormatter()
                travelTimeFormatter.unitsStyle = .short
                let formattedTravelTime = travelTimeFormatter.string(from: route.expectedTravelTime)
                
                print("Distance: \(formattedDistance); ETA: \(formattedTravelTime!)")
                
                for step in leg.steps {
                    print("\(step.instructions)")
                    let formattedDistance = distanceFormatter.string(fromMeters: step.distance)
                    print("— \(formattedDistance) —")
                }
                
                
                
                if route.coordinateCount > 0 {
                    // Convert the route’s coordinates into a polyline.
                    var routeCoordinates = route.coordinates!
                    let routeLine = MGLPolyline(coordinates: &routeCoordinates, count: route.coordinateCount)
                    
                    // Add the polyline to the map and fit the viewport to the polyline.
                    self.mapView.addAnnotation(routeLine)
                    self.mapView.setVisibleCoordinates(&routeCoordinates, count: route.coordinateCount, edgePadding: .zero, animated: true)
                }
                
                
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        locValue = (manager.location?.coordinate)!
        //print("locations = \(locValue.latitude) \(locValue.longitude)")
    }
    
    func mapView(_ mapView: MGLMapView, annotationCanShowCallout annotation: MGLAnnotation) -> Bool {
        // Always try to show a callout when an annotation is tapped.
        return true
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

