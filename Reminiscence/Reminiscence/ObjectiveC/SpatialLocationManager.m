//
//  SpatialLocationManager.m
//  Reminiscence
//
//  Created for Spatial Memory App
//

#import "SpatialLocationManager.h"

// Constants for power optimization
#define kHighAccuracy kCLLocationAccuracyBest
#define kMediumAccuracy kCLLocationAccuracyNearestTenMeters
#define kLowAccuracy kCLLocationAccuracyHundredMeters
#define kDefaultExpirationInterval (60 * 60 * 24 * 30) // 30 days

@interface SpatialLocationManager ()

@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, readwrite) CLLocation *lastKnownLocation;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *memoryProximityMap;
@property (nonatomic, strong) NSTimer *locationUpdateTimer;

@end

@implementation SpatialLocationManager

#pragma mark - Initialization

+ (SpatialLocationManager *)sharedInstance {
    static SpatialLocationManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[SpatialLocationManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
        _locationManager.desiredAccuracy = kMediumAccuracy; // Default accuracy
        _locationManager.activityType = CLActivityTypeOther;
        _locationManager.pausesLocationUpdatesAutomatically = YES;
        // Don't enable background updates until we have permission
        // _locationManager.allowsBackgroundLocationUpdates = YES;
        _memoryProximityMap = [NSMutableDictionary dictionary];
        
        // Initial power-saving configuration
        if (@available(iOS 14.0, *)) {
            _locationManager.activityType = CLActivityTypeOtherNavigation;
        }
    }
    return self;
}

#pragma mark - Authorization Methods

- (void)requestWhenInUseAuthorization {
    [self.locationManager requestWhenInUseAuthorization];
}

- (void)requestAlwaysAuthorization {
    [self.locationManager requestAlwaysAuthorization];
}

- (CLAuthorizationStatus)authorizationStatus {
    if (@available(iOS 14.0, *)) {
        return self.locationManager.authorizationStatus;
    } else {
        return [CLLocationManager authorizationStatus];
    }
}

#pragma mark - Location Tracking Methods

- (void)startUpdatingLocation {
    [self.locationManager startUpdatingLocation];
}

- (void)stopUpdatingLocation {
    [self.locationManager stopUpdatingLocation];
}

- (void)startMonitoringSignificantLocationChanges {
    if ([CLLocationManager significantLocationChangeMonitoringAvailable]) {
        [self.locationManager startMonitoringSignificantLocationChanges];
    }
}

- (void)stopMonitoringSignificantLocationChanges {
    if ([CLLocationManager significantLocationChangeMonitoringAvailable]) {
        [self.locationManager stopMonitoringSignificantLocationChanges];
    }
}

#pragma mark - Power Optimization Methods

- (void)configureAccuracyForActivity:(NSString *)activityType {
    // Configure accuracy and update interval based on current activity
    if ([activityType isEqualToString:@"stationary"]) {
        self.locationManager.desiredAccuracy = kLowAccuracy;
        self.locationManager.distanceFilter = 100.0; // Only update after 100m of movement
    } else if ([activityType isEqualToString:@"walking"]) {
        self.locationManager.desiredAccuracy = kMediumAccuracy;
        self.locationManager.distanceFilter = 10.0;
    } else if ([activityType isEqualToString:@"navigation"]) {
        self.locationManager.desiredAccuracy = kHighAccuracy;
        self.locationManager.distanceFilter = 5.0;
    } else {
        // Default
        self.locationManager.desiredAccuracy = kMediumAccuracy;
        self.locationManager.distanceFilter = 20.0;
    }
    
    if (@available(iOS 14.0, *)) {
        if ([activityType isEqualToString:@"stationary"]) {
            self.locationManager.activityType = CLActivityTypeOther;
        } else if ([activityType isEqualToString:@"walking"]) {
            self.locationManager.activityType = CLActivityTypeFitness;
        } else if ([activityType isEqualToString:@"navigation"]) {
            self.locationManager.activityType = CLActivityTypeAutomotiveNavigation;
        }
    }
}

#pragma mark - Geofence Methods

- (BOOL)isMonitoringAvailable {
    return [CLLocationManager isMonitoringAvailableForClass:[CLCircularRegion class]];
}

- (BOOL)isRangingAvailable {
    return [CLLocationManager isRangingAvailable];
}

- (BOOL)startMonitoringForRegion:(CLRegion *)region {
    if ([self isMonitoringAvailable]) {
        [self.locationManager startMonitoringForRegion:region];
        return YES;
    }
    return NO;
}

- (void)stopMonitoringForRegion:(CLRegion *)region {
    [self.locationManager stopMonitoringForRegion:region];
}

- (void)stopMonitoringAllRegions {
    for (CLRegion *region in self.locationManager.monitoredRegions) {
        [self.locationManager stopMonitoringForRegion:region];
    }
}

- (NSArray<CLRegion *> *)monitoredRegions {
    return [self.locationManager.monitoredRegions allObjects];
}

- (BOOL)startMonitoringForMemoryWithIdentifier:(NSString *)identifier
                                     latitude:(double)latitude
                                    longitude:(double)longitude
                                       radius:(double)radius
                                   expiration:(NSDate *)expiration {
    
    if (![self isMonitoringAvailable]) {
        return NO;
    }
    
    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(latitude, longitude);
    
    // Ensure coordinate is valid
    if (!CLLocationCoordinate2DIsValid(coordinate)) {
        NSLog(@"Invalid coordinates provided: %f, %f", latitude, longitude);
        return NO;
    }
    
    // Create a circular region
    CLCircularRegion *region = [[CLCircularRegion alloc] initWithCenter:coordinate
                                                                 radius:radius
                                                             identifier:identifier];
    region.notifyOnEntry = YES;
    region.notifyOnExit = YES;
    
    // Start monitoring this region
    [self.locationManager startMonitoringForRegion:region];
    
    // Set expiration if provided
    if (expiration) {
        NSTimeInterval expirationInterval = [expiration timeIntervalSinceNow];
        if (expirationInterval > 0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(expirationInterval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self.locationManager stopMonitoringForRegion:region];
            });
        }
    }
    
    return YES;
}

#pragma mark - CLLocationManagerDelegate Methods

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    CLLocation *mostRecentLocation = [locations lastObject];
    self.lastKnownLocation = mostRecentLocation;
    
    // Forward to Swift delegate
    if (self.delegate && [self.delegate respondsToSelector:@selector(didUpdateToLocation:)]) {
        [self.delegate didUpdateToLocation:mostRecentLocation];
    }
    
    // Implement smart power management - if user hasn't moved significantly, reduce update frequency
    static CLLocation *lastSignificantLocation = nil;
    if (!lastSignificantLocation || [mostRecentLocation distanceFromLocation:lastSignificantLocation] > 100.0) {
        lastSignificantLocation = mostRecentLocation;
        // User has moved significantly, adjust tracking precision as needed
    }
}

- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region {
    // Forward to Swift delegate
    if (self.delegate && [self.delegate respondsToSelector:@selector(didEnterRegion:)]) {
        [self.delegate didEnterRegion:region];
    }
}

- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region {
    // Forward to Swift delegate
    if (self.delegate && [self.delegate respondsToSelector:@selector(didExitRegion:)]) {
        [self.delegate didExitRegion:region];
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    // Forward to Swift delegate
    if (self.delegate && [self.delegate respondsToSelector:@selector(didFailWithError:)]) {
        [self.delegate didFailWithError:error];
    }
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    // Only enable background updates when we have appropriate permission
    if (status == kCLAuthorizationStatusAuthorizedAlways) {
        manager.allowsBackgroundLocationUpdates = YES;
    }
    
    if ([self.delegate respondsToSelector:@selector(spatialLocationManager:didChangeAuthorizationStatus:)]) {
        [self.delegate spatialLocationManager:self didChangeAuthorizationStatus:status];
    }
}

@end 