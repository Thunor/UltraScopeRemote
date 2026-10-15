import CoreLocation
import Observation

/// Fetches a single location fix: the observer's position is all that's needed to work out what's above the horizon.
@MainActor
@Observable
final class LocationProvider {
    private(set) var location: CLLocation?
    private(set) var isDenied = false

    func start() async {
        let session = CLServiceSession(authorization: .whenInUse)
        defer { session.invalidate() }
        do {
            for try await update in CLLocationUpdate.liveUpdates() {
                if update.authorizationDenied || update.authorizationDeniedGlobally || update.authorizationRestricted {
                    isDenied = true
                    return
                }
                if let fix = update.location {
                    location = fix
                    isDenied = false
                    return
                }
            }
        } catch {
            print("Location updates failed: \(error.localizedDescription)")
        }
    }
}
