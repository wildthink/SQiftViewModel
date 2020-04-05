//
//  MapViewController.swift
//
//
//  Created by Jobe, Jason on 9/14/19.
//  Copyright © 2019 Jason Jobe. All rights reserved.
//
// https://github.com/efremidze/Cluster
//
import UIKit
import MapKit
import CoreLocation
import SQift

public class MapViewController: UIViewController {

    @IBInspectable
    var selectionKey: String?

    @IBInspectable
    var filter: String?

    @IBInspectable
    var fetchLimit: Int = 100

    @IBInspectable
    var cellIdentifier: String = ""

    @IBInspectable
    var itemSegue: String = ""

    var _mapView: MKMapView?

    @IBOutlet var mapView: MKMapView? {
        get { return _mapView ?? self.viewIfLoaded as? MKMapView }
        set { _mapView = newValue }
    }

    var items: [MKAnnotation] = []

    override public func viewDidLoad() {
        super.viewDidLoad()
        guard let mapView = mapView else { return }
        mapView.delegate = self

        let locationLabel = NSLocalizedString("CurrentLocation", value: "Current Location", comment: "Informs the user that the blue dot on the map is their current location.")
        mapView.userLocation.title = locationLabel
        mapView.userTrackingMode = .follow
        mapView.showsUserLocation = true
    }

//    func centerMapOnLocation(location: CLLocationCoordinate2D, regionRadius: CLLocationDistance? = nil) {
//        let regionRadius = regionRadius ?? 2500
//        let coordinateRegion = MKCoordinateRegion(center: location,
//                                                  latitudinalMeters: regionRadius, longitudinalMeters: regionRadius)
//        mapView?.setRegion(coordinateRegion, animated: true)
//    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let viewModel = viewModel else { return }
        refresh(from: viewModel)
    }
    
    public override func refresh(from model: ViewModel) {
        guard let table = modelId else { return }
        guard let mapView = mapView else { return }

        if fetchLimit <= 0 { fetchLimit = 10 }

        let allItems: [MapAnnotation] = model.fetch (from: table, filter: filter, limit: fetchLimit)

        items = allItems
        if mapView.userLocation.location != nil {
            let userLocation = mapView.userLocation
            items.append(userLocation)
        }
        mapView.addAnnotations(items)
        mapView.showAnnotations(items, animated: true)
//        if let center = state?.searchLocation {
//            centerMapOnLocation(location: center, regionRadius: state?.regionRadius)
//        }
    }

    func saveSelectedLocation() {
        if let viewModel = viewModel,
            let locations = mapView?.selectedAnnotations,
            let id = (locations.first as? MapAnnotation)?.id,
            let selectionKey = selectionKey
        {
            try? viewModel.set(env: "selected.\(selectionKey)", to: id)
        }
    }

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override public func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        saveSelectedLocation()
    }

}

extension MapViewController: MKMapViewDelegate {

    public func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
    }

    @IBAction
    open func selectMapItem(_ sender: Any) {
        guard !itemSegue.isEmpty else {
            saveSelectedLocation()
            return
        }
        self.performSegue(withIdentifier: itemSegue, sender: sender )
    }

    public func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let view: MKAnnotationView
            = mapView.dequeueReusableAnnotationView(withIdentifier: cellIdentifier)
                ?? MKPinAnnotationView(annotation: annotation, reuseIdentifier: cellIdentifier)
        configureMapAnnotation(annotation, view)
        return view
    }

    func configureMapAnnotation(_ location: MKAnnotation, _ annotationView: MKAnnotationView) {
//        let image = location.mapImage()
//        annotationView.image = image

        // adjust the annotation so that the point of the pin lands at the exact coordinate
//        annotationView.centerOffset = CGPoint(x: 0, y: -image.size.height / 2)

        // Creates call out (bubble shown upon tapping annotation)
        annotationView.canShowCallout = true

        // Setup accessibility label for the annotation
//        annotationView.accessibilityLabel = location.defaultAccessibilityLabel

        // Creates arrow button on right side of the call out
        // UIButtonTypeDetailDisclosure needs to be used to be able to tap anywhere on the call out
        let arrowButton = UIButton(type: .detailDisclosure)
        let chevronImage = UIImage(named: "chevron_gray", in: Bundle(for: type(of: self)), compatibleWith: nil)
        let arrowImage = chevronImage?.withRenderingMode(.alwaysOriginal)
        arrowButton.frame = CGRect(x: 25, y: 25, width: 25, height: 25)
        arrowButton.setImage(arrowImage, for: UIControl.State())

        // Passing nil, nil will cause it to call mapView(mapView: MKMapView!, annotationView view: MKAnnotationView!, calloutAccessoryControlTapped control: UIControl!)
        arrowButton.removeTarget(nil, action: nil, for: .touchUpInside)
        arrowButton.addTarget(self, action: #selector(selectMapItem(_:)), for: .touchUpInside)
        annotationView.rightCalloutAccessoryView = arrowButton
    }

}

@objc class MapAnnotation : NSObject, MKAnnotation, ExpressibleByRow {

    var id: Int
    // Title and subtitle for use by selection UI.
    var title: String?
    var subtitle: String?
    var coordinate: CLLocationCoordinate2D

    init(id: Int, title: String?, subtitle: String?, lat: Double, lon: Double) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    required init(row: Row) {
        self.id = row.value(forColumnName: "id") ?? 0
        self.title = row.value(forColumnName: "title")!
        self.subtitle = row.value(forColumnName: "subtitle")
        let lat: Double = row.value(forColumnName: "lat") ?? 0
        let lon: Double = row.value(forColumnName: "lon") ?? 0
        self.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

public extension MKMapItem {
  convenience init(coordinate: CLLocationCoordinate2D, name: String) {
    self.init(placemark: .init(coordinate: coordinate))
    self.name = name
  }
}

/*
let source = MKMapItem(coordinate: .init(latitude: lat, longitude: lng), name: "Source")
let destination = MKMapItem(coordinate: .init(latitude: lat, longitude: lng), name: "Destination")

MKMapItem.openMaps(
  with: [source, destination],
  launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
*/

