import UIKit
import CoreLocation

// MARK: - PermissionViewController

// This is a dedicated view controller JUST for permissions
class PermissionViewController: UIViewController, CLLocationManagerDelegate {
    private var locationManager: CLLocationManager?
    private var completion: ((Bool) -> Void)?
    private var permissionExplanationLabel: UILabel!
    private var requestButton: UIButton!
    private var skipButton: UIButton!
    
    init(completion: @escaping (Bool) -> Void) {
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
        
        // Make it modal and non-dismissible
        self.modalPresentationStyle = .fullScreen
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        // Initialize location manager
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        
        // Check if location services are enabled at all
        if !CLLocationManager.locationServicesEnabled() {
            permissionExplanationLabel.text = "Location services are disabled on your device. Please enable them in Settings to use location features."
            requestButton.setTitle("Open Settings", for: .normal)
        }
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        
        // App logo
        let logoImageView = UIImageView(image: UIImage(named: "AppLogo"))
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Explanation label
        permissionExplanationLabel = UILabel()
        permissionExplanationLabel.text = "Reminiscence uses your location to associate memories with places. This makes your experience more meaningful.\n\nPlease tap 'Allow' when prompted."
        permissionExplanationLabel.numberOfLines = 0
        permissionExplanationLabel.textAlignment = .center
        permissionExplanationLabel.font = UIFont.systemFont(ofSize: 16)
        permissionExplanationLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Request button
        requestButton = UIButton(type: .system)
        requestButton.setTitle("Allow Location Access", for: .normal)
        requestButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        requestButton.backgroundColor = UIColor.systemBlue
        requestButton.setTitleColor(.white, for: .normal)
        requestButton.layer.cornerRadius = 10
        requestButton.translatesAutoresizingMaskIntoConstraints = false
        requestButton.addTarget(self, action: #selector(requestButtonTapped), for: .touchUpInside)
        
        // Skip button
        skipButton = UIButton(type: .system)
        skipButton.setTitle("Skip for Now", for: .normal)
        skipButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        skipButton.addTarget(self, action: #selector(skipButtonTapped), for: .touchUpInside)
        
        // Add views
        view.addSubview(logoImageView)
        view.addSubview(permissionExplanationLabel)
        view.addSubview(requestButton)
        view.addSubview(skipButton)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            logoImageView.widthAnchor.constraint(equalToConstant: 100),
            logoImageView.heightAnchor.constraint(equalToConstant: 100),
            
            permissionExplanationLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            permissionExplanationLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 40),
            permissionExplanationLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            permissionExplanationLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            
            requestButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            requestButton.topAnchor.constraint(equalTo: permissionExplanationLabel.bottomAnchor, constant: 40),
            requestButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            requestButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            requestButton.heightAnchor.constraint(equalToConstant: 50),
            
            skipButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            skipButton.topAnchor.constraint(equalTo: requestButton.bottomAnchor, constant: 20)
        ])
    }
    
    @objc private func requestButtonTapped() {
        if CLLocationManager.locationServicesEnabled() {
            if let status = locationManager?.authorizationStatus, status == .notDetermined {
                print("PERMISSION VC: Requesting location authorization")
                locationManager?.requestWhenInUseAuthorization()
            } else {
                // Location services enabled but authorization already determined
                // Open settings
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } else {
            // Open iOS Settings app for location services
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
    }
    
    @objc private func skipButtonTapped() {
        dismiss(animated: true) {
            self.completion?(false)
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        
        print("PERMISSION VC: Authorization changed to: \(status.rawValue)")
        
        // If we got a definitive answer (not notDetermined), dismiss
        if status != .notDetermined {
            let hasPermission = (status == .authorizedWhenInUse || status == .authorizedAlways)
            dismiss(animated: true) {
                self.completion?(hasPermission)
            }
        }
    }
}

// MARK: - LocationPermissionHelper

class LocationPermissionHelper: NSObject {
    // Singleton instance
    static let shared = LocationPermissionHelper()
    
    private override init() {
        super.init()
    }
    
    // Force show the permission screen
    func showPermissionViewController(completion: @escaping (Bool) -> Void) {
        let permissionVC = PermissionViewController(completion: completion)
        
        // Find the top view controller and present
        DispatchQueue.main.async {
            if let rootVC = UIApplication.shared.windows.first?.rootViewController {
                // Dismiss any currently presented view controller
                if let presented = rootVC.presentedViewController {
                    presented.dismiss(animated: false) {
                        rootVC.present(permissionVC, animated: true)
                    }
                } else {
                    rootVC.present(permissionVC, animated: true)
                }
            }
        }
    }
    
    // Legacy methods
    func forceLocationPermissionRequest() {
        // Directly request using our own controller
        showPermissionViewController { _ in
            // No additional action needed - the PermissionViewController will handle everything
        }
    }
    
    func showLocationExplanationDialog(from viewController: UIViewController) {
        // Now just show our unified permission screen
        showPermissionViewController { _ in
            // No additional action needed
        }
    }
}

// Helper to find the topmost view controller
extension UIApplication {
    class func topViewController(base: UIViewController? = UIApplication.shared.windows.first?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(base: selected)
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
} 