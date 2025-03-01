//
//  SpatialLocationManager.h
//  Reminiscence
//
//  Created for Spatial Memory App
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

// Protocol for Swift to receive location updates
@protocol SpatialLocationDelegate <NSObject>

- (void)didUpdateToLocation:(CLLocation *)location;
- (void)didEnterRegion:(CLRegion *)region;
- (void)didExitRegion:(CLRegion *)region;
- (void)locationAuthorizationDidChange:(CLAuthorizationStatus)status;
- (void)spatialLocationManager:(id)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status;
- (void)didFailWithError:(NSError *)error;

@end

// Main location manager class
@interface SpatialLocationManager : NSObject <CLLocationManagerDelegate>

@property (nonatomic, weak, nullable) id<SpatialLocationDelegate> delegate;
@property (nonatomic, readonly) BOOL isMonitoringAvailable;
@property (nonatomic, readonly) BOOL isRangingAvailable;
@property (nonatomic, readonly) CLAuthorizationStatus authorizationStatus;
@property (nonatomic, readonly) CLLocation * _Nullable lastKnownLocation;
@property (nonatomic, readonly) NSArray<CLRegion *> *monitoredRegions;

// Singleton instance
+ (SpatialLocationManager *)sharedInstance;

// Location permission methods
- (void)requestWhenInUseAuthorization;
- (void)requestAlwaysAuthorization;

// Location monitoring methods
- (void)startUpdatingLocation;
- (void)stopUpdatingLocation;
- (void)startMonitoringSignificantLocationChanges;
- (void)stopMonitoringSignificantLocationChanges;

// Power-efficient location methods
- (void)configureAccuracyForActivity:(NSString *)activityType;

// Geofence methods
- (BOOL)startMonitoringForRegion:(CLRegion *)region;
- (void)stopMonitoringForRegion:(CLRegion *)region;
- (void)stopMonitoringAllRegions;

// Memory-related geofencing
- (BOOL)startMonitoringForMemoryWithIdentifier:(NSString *)identifier
                                     latitude:(double)latitude
                                    longitude:(double)longitude
                                       radius:(double)radius
                                   expiration:(NSDate * _Nullable)expiration;

@end

NS_ASSUME_NONNULL_END 