//
//  HealthStore.swift
//  Runner
//
//  Created by Moksh Mahajan on 09/12/22.
//

import Foundation
import HealthKit
import PromiseKit

class HealthStore {
  var healthStore: HKHealthStore?
  var query: HKStatisticsCollectionQuery?
  var obsQuery: HKObserverQuery?
  var healthkitDataTypes: HealthKitDataTypes?

  private let hekaKeyChainHelper = HekaKeychainHelper()
  private var uploadClient: FileUploadClinet?
  private let fileHandler = JSONFileHandler()

  init() {
    if HKHealthStore.isHealthDataAvailable() {
      healthStore = HKHealthStore()
      healthkitDataTypes = HealthKitDataTypes()
      healthkitDataTypes.initWorkoutTypes()
      healthkitDataTypes.initDataTypeToUnit()
      healthkitDataTypes.initDataTypesDict()
    }
  }

  func requestAuthorization(completion: @escaping (Bool) -> Void) {
    guard let healthStore = self.healthStore else {
      return completion(false)
    }

    healthStore.requestAuthorization(
      toShare: [], read: Set(self.healthkitDataTypes.healthDataTypes)
    ) { bool, error in
      if error != nil {
        return completion(false)
      } else if bool == true {
        return completion(true)
      } else {
        return completion(false)
      }

    }
  }

  func stopObserverQuery() {
    if let query = obsQuery {
      healthStore?.stop(query)
    }
    obsQuery = nil
  }

  // Public function to start syncing health data to server
  // This needs to be called in AppDelegate.swift
  public func setupObserverQuery() {
    if !hekaKeyChainHelper.connected {
      return
    }
    var userUuid = hekaKeyChainHelper.userUuid
    var apiKey = hekaKeyChainHelper.apiKey
    setupStepsObserverQuery(apiKey: apiKey, userUuid: userUuid)
  }

  func setupStepsObserverQuery(apiKey: String, userUuid: String) {
    let stepCountType = HKObjectType.quantityType(forIdentifier: .stepCount)!

    obsQuery = HKObserverQuery(sampleType: stepCountType, predicate: nil) {
      (query, completionHandler, errorOrNil) in

      // Get steps and upload to server
      firstly {
        self.combineResults(healthDataTypes: [
          self.STEPS, self.HEART_RATE, self.DISTANCE_WALKING_RUNNING, self.ACTIVE_ENERGY_BURNED,
          self.BLOOD_PRESSURE_SYSTOLIC, self.BLOOD_OXYGEN, self.BLOOD_GLUCOSE,
          self.BODY_TEMPERATURE, self.HEIGHT, self.WEIGHT, self.BODY_MASS_INDEX, self.WATER,
          self.BODY_FAT_PERCENTAGE,
        ])
      }.done { samples in
        if !samples.isEmpty {
          self.handleUserData(with: samples, apiKey: apiKey, uuid: userUuid) {
          }
        }
      }
      completionHandler()
    }

    healthStore!.execute(obsQuery!)
    healthStore!.enableBackgroundDelivery(
      for: stepCountType, frequency: .immediate,
      withCompletion: { (succeeded, error) in
        if succeeded {
          print("Enabled background delivery of step changes")
        } else {
          if let theError = error {
            print("Failed to enable background delivery of steps changes. ")
            print("Error = \(theError)")
          }
        }
      })
  }

  private func handleUserData(
    with samples: [String: Any],
    apiKey: String, uuid: String,
    with completion: @escaping () -> Void
  ) {
    fileHandler.createJSONFile(with: samples) { filePath in
      self.uploadClient = FileUploadClinet(
        apiKey: apiKey, userUUID: uuid
      )

      self.uploadClient?.uploadUserDataFile(
        from: filePath, with: FileDetails()
      ) { syncSuccessful in
        switch syncSuccessful {
        case true:
          self.hekaKeyChainHelper.markFirstUpload()
          print("Data synced successfully")
        case false:
          print("Data synced failed")
        }
        self.fileHandler.deleteJSONFile()
        completion()
      }
    }
  }

  func combineResults(healthDataTypes: [String]) -> Promise<[String: [NSDictionary]]> {
    var promises = [Promise<[NSDictionary]>]()
    var results: [String: [NSDictionary]] = [:]

    for healthDataType in healthDataTypes {
      promises.append(getSamples(type: healthDataType))
    }

    return when(fulfilled: promises).map { value in
      for (index, type) in healthDataTypes.enumerated() {
        if !value[index].isEmpty {
          results[type.lowercased()] = value[index]
        }
      }
      return results
    }
  }

  func getSamples(type: String) -> Promise<[NSDictionary]> {
    return Promise<[NSDictionary]> { seal in
      getDataFromType(
        dataTypeKey: type,
        completion: { dict in
          seal.fulfill(dict)
        })
    }
  }

  func getDataFromType(dataTypeKey: String, completion: @escaping ([NSDictionary]) -> Void) {
    let dataType = self.healthkitDataTypes.dataTypesDict[dataTypeKey]
    var predicate: NSPredicate? = nil

    if let lastSync = hekaKeyChainHelper.lastSyncDate {
      predicate = HKQuery.predicateForSamples(
        withStart: lastSync, end: Date(), options: .strictStartDate)
    } else {
      let today = Date()
      let start = Calendar.current.date(byAdding: .day, value: -120, to: today)!
      predicate = HKQuery.predicateForSamples(
        withStart: start, end: today, options: .strictStartDate)
    }

    let q = HKSampleQuery(
      sampleType: dataType!, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil
    ) {
      x, samplesOrNil, error in

      switch samplesOrNil {
      case let (samples as [HKQuantitySample]) as Any:
        print("HKQuantity Sample type data found: ")
        let unit = self.healthkitDataTypes.dataTypeToUnit[dataTypeKey]

        let dictionaries = samples.map { sample -> NSDictionary in
          return [
            "uuid": "\(sample.uuid)",
            "value": sample.quantity.doubleValue(for: unit!),
            "date_from": Int(sample.startDate.timeIntervalSince1970 * 1000),
            "date_to": Int(sample.endDate.timeIntervalSince1970 * 1000),
            "source_id": sample.sourceRevision.source.bundleIdentifier,
            "source_name": sample.sourceRevision.source.name,
          ]
        }

        completion(dictionaries)

      case var (samplesCategory as [HKCategorySample]) as Any:
        print("HKCategory Sample type data found: ")
        if dataTypeKey == self.healthkitDataTypes.SLEEP_IN_BED {
          samplesCategory = samplesCategory.filter { $0.value == 0 }
        }
        if dataTypeKey == self.healthkitDataTypes.SLEEP_ASLEEP {
          samplesCategory = samplesCategory.filter { $0.value == 1 }
        }
        if dataTypeKey == self.healthkitDataTypes.SLEEP_AWAKE {
          samplesCategory = samplesCategory.filter { $0.value == 2 }
        }
        if dataTypeKey == self.healthkitDataTypes.HEADACHE_UNSPECIFIED {
          samplesCategory = samplesCategory.filter { $0.value == 0 }
        }
        if dataTypeKey == self.healthkitDataTypes.HEADACHE_NOT_PRESENT {
          samplesCategory = samplesCategory.filter { $0.value == 1 }
        }
        if dataTypeKey == self.healthkitDataTypes.HEADACHE_MILD {
          samplesCategory = samplesCategory.filter { $0.value == 2 }
        }
        if dataTypeKey == self.healthkitDataTypes.HEADACHE_MODERATE {
          samplesCategory = samplesCategory.filter { $0.value == 3 }
        }
        if dataTypeKey == self.healthkitDataTypes.HEADACHE_SEVERE {
          samplesCategory = samplesCategory.filter { $0.value == 4 }
        }
        let categories = samplesCategory.map { sample -> NSDictionary in
          return [
            "uuid": "\(sample.uuid)",
            "value": sample.value,
            "date_from": Int(sample.startDate.timeIntervalSince1970 * 1000),
            "date_to": Int(sample.endDate.timeIntervalSince1970 * 1000),
            "source_id": sample.sourceRevision.source.bundleIdentifier,
            "source_name": sample.sourceRevision.source.name,
          ]
        }

        completion(categories)

      case let (samplesWorkout as [HKWorkout]) as Any:
        print("HKWorkout type data found: ")

        let dictionaries = samplesWorkout.map { sample -> NSDictionary in
          return [
            "uuid": "\(sample.uuid)",
            "workoutActivityType": self.healthkitDataTypes.workoutActivityTypeMap.first(where: {
              $0.value == sample.workoutActivityType
            })?.key,
            "totalEnergyBurned": sample.totalEnergyBurned?.doubleValue(for: HKUnit.kilocalorie()),
            "totalEnergyBurnedUnit": "KILOCALORIE",
            "totalDistance": sample.totalDistance?.doubleValue(for: HKUnit.meter()),
            "totalDistanceUnit": "METER",
            "date_from": Int(sample.startDate.timeIntervalSince1970 * 1000),
            "date_to": Int(sample.endDate.timeIntervalSince1970 * 1000),
            "source_id": sample.sourceRevision.source.bundleIdentifier,
            "source_name": sample.sourceRevision.source.name,
          ]
        }

        completion(dictionaries)

      // if #available(iOS 13.0, *) {
      //   case let (samplesAudiogram as [HKAudiogramSample]) as Any:
      //       print("HKAudiogram Sample type data found: ")
      //       let dictionaries = samplesAudiogram.map { sample -> NSDictionary in
      //           var frequencies = [Double]()
      //           var leftEarSensitivities = [Double]()
      //           var rightEarSensitivities = [Double]()
      //           for samplePoint in sample.sensitivityPoints {
      //               frequencies.append(samplePoint.frequency.doubleValue(for: HKUnit.hertz()))
      //               // leftEarSensitivities.append(samplePoint.leftEarSensitivity!.doubleValue(for: HKUnit.decibelHearingLevel()))
      //               // rightEarSensitivities.append(samplePoint.rightEarSensitivity!.doubleValue(for: HKUnit.decibelHearingLevel()))
      //           }
      //           return [
      //               "uuid": "\(sample.uuid)",
      //               "frequencies": frequencies,
      //               "leftEarSensitivities": leftEarSensitivities,
      //               "rightEarSensitivities": rightEarSensitivities,
      //               "date_from": Int(sample.startDate.timeIntervalSince1970 * 1000),
      //               "date_to": Int(sample.endDate.timeIntervalSince1970 * 1000),
      //               "source_id": sample.sourceRevision.source.bundleIdentifier,
      //               "source_name": sample.sourceRevision.source.name
      //           ]
      //       }

      //       completion(dictionaries)
      // }

      default:
        print("Nothing found!")
        completion([])

      }

    }

    healthStore!.execute(q)
  }
}
