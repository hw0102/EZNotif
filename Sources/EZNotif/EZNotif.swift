import Foundation
import UserNotifications
import SwiftUI
import UIKit

/// An instance of EZNotif where you can manage local notifications
@Observable
public class EZNotif: NSObject {
    
    /* Properties */
    
    private var notificationCenter = UNUserNotificationCenter.current()
    
    /// property: false if notifcation is not allowed. true otherwise
    var isAuthroized: Bool = false
    
    /// property: the list of all notifications scheduled for future
    private var pendingRequests: [UNNotificationRequest] = []
    
    /// property: the list of all notifications that have been delivered
    private var deliveredNotifications: [UNNotification] = []
        
    /// computed var: return the number of currently scheduled notifications
    var numOfPendingNotifications: Int {
        pendingRequests.count
    }
    
    /// initialize an instance of EZNotif with actions to run after user interacts with notification
    public init(onDelivered: (() -> Void)? = nil, onTapped: ((UNNotificationResponse) -> Void)? = nil) {
        super.init()
        self.onDelivered = onDelivered
        self.onTapped = onTapped
        notificationCenter.delegate = self
    }
    
    /* Custom Handling */
    
    /// run after a notification is delivered
    var onDelivered: (() -> Void)?
    
    /// run after a notification is tapped on
    var onTapped: ((UNNotificationResponse) -> Void)?
    
    
    /* Functions */
    
    /// request authorization to send push notification
    func requestAuthorization() async  {
        do {
            if !isAuthroized {
                try await notificationCenter.requestAuthorization(
                    options: [
                        .alert,
                        .badge,
                        .sound
                    ]
                )
                await updateCurrentSettings()
            }
        }
        catch {
            print(error.localizedDescription)
        }
    }
    
    /// sync badge count on icon with number of delivered notifications
    func syncBadgeCount() async {
        do {
            await updateDeliveredNotifications()
            let count = self.deliveredNotifications.count
            try await notificationCenter.setBadgeCount(count)
        }
        catch {
            print(error.localizedDescription)
        }
    }
    
    /// update tracked list of delivered notifications
    private func updateDeliveredNotifications() async {
        self.deliveredNotifications = await notificationCenter.deliveredNotifications()
    }
    
    /// sync tracked list of pending notifications
    func updatePendingRequests() async {
        self.pendingRequests = await notificationCenter.pendingNotificationRequests()
    }
    
    /// sync stored authorization status with user's app settings
    func updateCurrentSettings() async {
        let currentSettings = await notificationCenter.notificationSettings()
        isAuthroized = currentSettings.authorizationStatus == .authorized
    }
    
    /* Extra Helper */
    
    /// helper: navigate to the App page in Settings
    @MainActor
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            if UIApplication.shared.canOpenURL(url) {
                Task {
                    await UIApplication.shared.open(url)
                }
            }
        }
    }
}

extension EZNotif: UNUserNotificationCenterDelegate {
    /* Notification Tap Handling */
    // Delegate func - this is called after a notification delivers
    public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        await updatePendingRequests()
        await syncBadgeCount()
        // user-defined action
        onDelivered?()
        
        return [.sound, .badge, .banner]
    }
    
    
    // Delegate func - this handles what to do after user taps on a notification
    public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        await updatePendingRequests()
        await syncBadgeCount()
        // user-defined action
        onTapped?(response)
    }
}

