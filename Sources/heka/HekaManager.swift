public class HekaManager {

  public init() {}

  let healthStore = HealthStore()

  public func requestAuthorization(completion: @escaping (Bool) -> Void) {
    healthStore.requestAuthorization { success in
      completion(success)
    }
  }

  public func stopSyncing() -> Bool {
    // TODO: we need to mark the connection as logged out too
    healthStore.stopObserverQuery()
    return true
  }

  public func syncIosHealthData(
    apiKey: String, userUuid: String, completion: @escaping (Bool) -> Void
  ) {
    healthStore.requestAuthorization { success in
      if success {
        // Setup observer query
        self.healthStore.setupStepsObserverQuery(apiKey: apiKey, userUuid: userUuid)
        completion(true)
      } else {
        completion(false)
      }
    }
  }
}
