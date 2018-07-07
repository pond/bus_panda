//
//  Constants.h
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 1/07/18.
//  Copyright © 2018 Andrew Hodgkinson. All rights reserved.
//

#ifndef Constants_h
#define Constants_h

// Define this and run in the simulator for screenshots on the App Store.
//
#undef SCREENSHOT_BUILD

#pragma mark - User default keys

// Internal operational flags.
//
#define HAVE_SHOWN_ICLOUD_SIGNIN_WARNING @"haveShownICloudSignInWarning"
#define ICLOUD_IS_AVAILABLE              @"iCloudIsAvailable"
#define HAVE_RECEIVED_CLOUDKIT_DATA      @"cloudKitUpdatesReceived"
#define HAVE_READ_LEGACY_ICLOUD_DATA     @"haveReadLegacyICloudData"
#define CLOUDKIT_STOP_IDS_PENDING        @"cloudKitStopIDsPending"
#define CLOUDKIT_FETCHED_CHANGES_TOKEN   @"cloudKitChangesToken"

// User-facing preferences.
//
#define SHORTEN_DISPLAYED_NAMES          @"shorten_names_preference"
#define WEATHER_PROVIDER                 @"weather_provider"
#define WEATHER_PROVIDER_METSERVICE      @"metservice"
#define WEATHER_PROVIDER_DARK_SKY        @"darksky"
#define WEATHER_PROVIDER_WEATHER_COM     @"weathercom"
#define WEATHER_PROVIDER_WUNDERGROUND    @"wunderground"

#pragma mark - Data management

// * App ID for general iCloud access
// * Ubiquity token for pre-V2 iCloud / Core Data sync
// * Core Data filename for local <-> remote store with pre-V2 iCloud code
//
#define ICLOUD_ENABLED_APP_ID            @"XT4V976D8Y~uk~org~pond~Bus-Panda"
#define ICLOUD_TOKEN_ID_DEFAULTS_KEY     @"uk.org.pond.Bus-Panda.UbiquityIdentityToken"
#define OLD_CORE_DATA_FILE_NAME          @"Bus-Panda.sqlite"

// * V2 local Core Data store, to cache data from CloudKit
// * Custom zone name so we can use the CloudKit 'getChanges' method etc.
// * Custom subscription ID for subscription to changes in the custom zone
//
#define NEW_CORE_DATA_FILE_NAME          @"Bus-Panda-2.sqlite"
#define CLOUDKIT_ZONE_NAME               @"busPanda"
#define CLOUDKIT_SUBSCRIPTION_ID         @"busPandaChanges"

// * Core Data entity name and CloudKit record name for Bus Stop model
//   - In Core Data, there's a "stopID" field
//   - In CloudKit, the record ID is the stop ID (CKRecordID.recordName)
// * Custom notification used when the local store is updated by any means
//   (pre-V2 Core Data iCloud sync, or from CloudKit updates)
//
#define ENTITY_AND_RECORD_NAME           @"BusStop"
#define DATA_CHANGED_NOTIFICATION_NAME   @"BusPandaDataChanged"

#endif /* Constants_h */
