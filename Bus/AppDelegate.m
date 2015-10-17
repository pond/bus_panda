//
//  AppDelegate.m
//  Bus
//
//  Created by Andrew Hodgkinson on 24/03/15.
//  Copyright (c) 2015 Andrew Hodgkinson. All rights reserved.
//

#import "AppDelegate.h"
#import "DetailViewController.h"
#import "MasterViewController.h"

@interface AppDelegate () <UISplitViewControllerDelegate>

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    [ self iCloudAccountAvailabilityChanged: nil ];

    [
        [ NSNotificationCenter defaultCenter ] addObserver: self
                                                  selector: @selector( iCloudAccountAvailabilityChanged: )
                                                      name: NSUbiquityIdentityDidChangeNotification
                                                    object: nil
    ];

    UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
    UINavigationController *navigationController = [splitViewController.viewControllers lastObject];
    navigationController.topViewController.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem;
    splitViewController.delegate = self;

    UINavigationController *masterNavigationController = splitViewController.viewControllers[0];
    MasterViewController *controller = (MasterViewController *)masterNavigationController.topViewController;
    controller.managedObjectContext = self.managedObjectContext;

    return YES;
}

// "notification" parameter is ignored.
//
- ( void ) iCloudAccountAvailabilityChanged: ( NSNotification * ) notification
{
    ( void ) notification;

    NSUserDefaults * defaults           = [ NSUserDefaults standardUserDefaults ];
    NSFileManager  * fileManager        = [ NSFileManager defaultManager ];
    id               currentiCloudToken = fileManager.ubiquityIdentityToken;

    if ( currentiCloudToken )
    {
        NSData *newTokenData = [
            NSKeyedArchiver archivedDataWithRootObject: currentiCloudToken
        ];

        [ defaults setObject: newTokenData
                      forKey: @"uk.org.pond.Bus.UbiquityIdentityToken" ];
    }
    else
    {
        [ defaults removeObjectForKey: @"uk.org.pond.Bus.UbiquityIdentityToken"];
    }

    NSLog( @"iCloud ubiquity token: %@", currentiCloudToken );
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    // Saves changes in the application's managed object context before the application terminates.
    [self saveContext];
}

#pragma mark - Split view

- (BOOL)splitViewController:(UISplitViewController *)splitViewController collapseSecondaryViewController:(UIViewController *)secondaryViewController ontoPrimaryViewController:(UIViewController *)primaryViewController {
    if ([secondaryViewController isKindOfClass:[UINavigationController class]] && [[(UINavigationController *)secondaryViewController topViewController] isKindOfClass:[DetailViewController class]] && ([(DetailViewController *)[(UINavigationController *)secondaryViewController topViewController] detailItem] == nil)) {
        // Return YES to indicate that we have handled the collapse by doing nothing; the secondary controller will be discarded.
        return YES;
    } else {
        return NO;
    }
}

#pragma mark - Core Data stack

@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

- (NSURL *)applicationDocumentsDirectory {
    // The directory the application uses to store the Core Data store file. This code uses a directory named "uk.org.pond.Bus" in the application's documents directory.
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

- (NSManagedObjectModel *)managedObjectModel {
    // The managed object model for the application. It is a fatal error for the application not to be able to find and load its model.
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"Bus" withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

// http://timroadley.com/2012/04/03/core-data-in-icloud/
//
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {

    if((_persistentStoreCoordinator != nil)) {
        return _persistentStoreCoordinator;
    }

    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel: [self managedObjectModel]];
    NSPersistentStoreCoordinator *psc = _persistentStoreCoordinator;

    // Set up iCloud in another thread:

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        // ** Note: if you adapt this code for your own use, you MUST change this variable:
        NSString *iCloudEnabledAppID = @"XT4V976D8Y~uk~org~pond~Bus";

        // ** Note: if you adapt this code for your own use, you should change this variable:
        NSString *dataFileName = @"Bus.sqlite";

        // ** Note: For basic usage you shouldn't need to change anything else

        NSString *iCloudDataDirectoryName = @"Data.nosync";
        NSString *iCloudLogsDirectoryName = @"Logs";
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSURL *localStore = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:dataFileName];
        NSURL *iCloud = [fileManager URLForUbiquityContainerIdentifier: @"iCloud.uk.org.pond.Bus"];

        if (iCloud) {

            NSLog(@"iCloud is working");

            NSURL *iCloudLogsPath = [NSURL fileURLWithPath:[[iCloud path] stringByAppendingPathComponent:iCloudLogsDirectoryName]];

            NSLog(@"iCloudEnabledAppID = %@",iCloudEnabledAppID);
            NSLog(@"dataFileName = %@", dataFileName);
            NSLog(@"iCloudDataDirectoryName = %@", iCloudDataDirectoryName);
            NSLog(@"iCloudLogsDirectoryName = %@", iCloudLogsDirectoryName);
            NSLog(@"iCloud = %@", iCloud);
            NSLog(@"iCloudLogsPath = %@", iCloudLogsPath);

            if([fileManager fileExistsAtPath:[[iCloud path] stringByAppendingPathComponent:iCloudDataDirectoryName]] == NO) {
                NSError *fileSystemError;
                [fileManager createDirectoryAtPath:[[iCloud path] stringByAppendingPathComponent:iCloudDataDirectoryName]
                       withIntermediateDirectories:YES
                                        attributes:nil
                                             error:&fileSystemError];
                if(fileSystemError != nil) {
                    NSLog(@"Error creating database directory %@", fileSystemError);
                }
            }

            NSString *iCloudData = [[[iCloud path]
                                     stringByAppendingPathComponent:iCloudDataDirectoryName]
                                    stringByAppendingPathComponent:dataFileName];

            NSLog(@"iCloudData = %@", iCloudData);

            NSMutableDictionary *options = [NSMutableDictionary dictionary];
            [options setObject:[NSNumber numberWithBool:YES] forKey:NSMigratePersistentStoresAutomaticallyOption];
            [options setObject:[NSNumber numberWithBool:YES] forKey:NSInferMappingModelAutomaticallyOption];
            [options setObject:iCloudEnabledAppID            forKey:NSPersistentStoreUbiquitousContentNameKey];
            [options setObject:iCloudLogsPath                forKey:NSPersistentStoreUbiquitousContentURLKey];

            [
                psc performBlockAndWait: ^ ( void ) {
                    [ psc addPersistentStoreWithType: NSSQLiteStoreType
                                       configuration: nil
                                                 URL: [ NSURL fileURLWithPath: iCloudData ]
                                             options: options
                                               error: nil ];
                }
            ];
        }
        else {
            NSLog(@"iCloud is NOT working - using a local store");
            NSMutableDictionary *options = [NSMutableDictionary dictionary];
            [options setObject:[NSNumber numberWithBool:YES] forKey:NSMigratePersistentStoresAutomaticallyOption];
            [options setObject:[NSNumber numberWithBool:YES] forKey:NSInferMappingModelAutomaticallyOption];

            [
                psc performBlockAndWait: ^ ( void ) {
                    [ psc addPersistentStoreWithType: NSSQLiteStoreType
                                       configuration: nil
                                                 URL: localStore
                                             options: options
                                               error: nil ];
                }
            ];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"SomethingChanged" object:self userInfo:nil];
        });
    });
    
    return _persistentStoreCoordinator;



//    // The persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it.
//    if (_persistentStoreCoordinator != nil) {
//        return _persistentStoreCoordinator;
//    }
//    
//    // Create the coordinator and store
//    
//    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
//    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"Bus.sqlite"];
//    NSError *error = nil;
//    NSString *failureReason = @"There was an error creating or loading the application's saved data.";
//    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
//        // Report any error we got.
//        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
//        dict[NSLocalizedDescriptionKey] = @"Failed to initialize the application's saved data";
//        dict[NSLocalizedFailureReasonErrorKey] = failureReason;
//        dict[NSUnderlyingErrorKey] = error;
//        error = [NSError errorWithDomain:@"YOUR_ERROR_DOMAIN" code:9999 userInfo:dict];
//        // Replace this with code to handle the error appropriately.
//        // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
//        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
//        abort();
//    }
//    
//    return _persistentStoreCoordinator;
}

// http://timroadley.com/2012/04/03/core-data-in-icloud/
//
- (NSManagedObjectContext *)managedObjectContext {

    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }

    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];

    if (coordinator != nil) {
        NSManagedObjectContext* moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];

        [moc performBlockAndWait:^{
            [moc setPersistentStoreCoordinator: coordinator];
            [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(mergeChangesFrom_iCloud:) name:NSPersistentStoreDidImportUbiquitousContentChangesNotification object:coordinator];
        }];
        _managedObjectContext = moc;
    }

    return _managedObjectContext;

//    // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.)
//    if (_managedObjectContext != nil) {
//        return _managedObjectContext;
//    }
//    
//    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
//    if (!coordinator) {
//        return nil;
//    }
//    _managedObjectContext = [[NSManagedObjectContext alloc] init];
//    [_managedObjectContext setPersistentStoreCoordinator:coordinator];
//    return _managedObjectContext;
}

// http://timroadley.com/2012/04/03/core-data-in-icloud/
//
- (void)mergeChangesFrom_iCloud:(NSNotification *)notification {

    NSLog(@"Merging in changes from iCloud...");

    NSManagedObjectContext* moc = [self managedObjectContext];

    [moc performBlock:^{

        [moc mergeChangesFromContextDidSaveNotification:notification];

        NSNotification* refreshNotification = [NSNotification notificationWithName:@"SomethingChanged"
                                                                            object:self
                                                                          userInfo:[notification userInfo]];

        [[NSNotificationCenter defaultCenter] postNotification:refreshNotification];
    }];
}

#pragma mark - Core Data Saving support

- (void)saveContext {
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil) {
        NSError *error = nil;
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }
}

@end
