//
//  Configurations.swift
//
//  The obect is the model for the Configurations but also acts as Controller when
//  the ViewControllers reads or updates data.
//
//  The object also holds various configurations for RsyncOSX and references to
//  some of the ViewControllers used in calls to delegate functions.
//
//  Created by Thomas Evensen on 08/02/16.
//  Copyright © 2016 Thomas Evensen. All rights reserved.
//
//  swiftlint:disable line_length type_body_length

import Foundation
import Cocoa

class Configurations: ReloadTable, SetSchedules {

    // Storage API
    var storageapi: PersistentStorageAPI?
    // reference to Process, used for kill in executing task
    var process: Process?
    private var profile: String?
    // Reference to singletask object
    var singleTask: SingleTask?
    // The main structure storing all Configurations for tasks
    private var configurations: [Configuration]?
    // Array to store argumenst for all tasks.
    // Initialized during startup
    private var argumentAllConfigurations: [ArgumentsOneConfiguration]?
    // Datasource for NSTableViews
    private var configurationsDataSource: [NSMutableDictionary]?
    // Object for batchQueue data and operations
    private var batchQueue: BatchTaskWorkQueu?
    // backup list from remote info view
    var quickbackuplist: [Int]?
    // Estimated backup list, all backups
    var estimatedlist: [NSMutableDictionary]?
    // remote and local info
    var localremote: [NSMutableDictionary]?
    // remote info tasks
    var remoteinfotaskworkqueue: RemoteInfoTaskWorkQueue?
    // Which kind of task
    var processtermination: ProcessTermination?

    /// Function for getting the profile
    func getProfile() -> String? {
        return self.profile
    }

    /// Function for getting Configurations read into memory
    /// - parameter none: none
    /// - returns : Array of configurations
    func getConfigurations() -> [Configuration] {
        return self.configurations ?? []
    }

    /// Function for getting arguments for all Configurations read into memory
    /// - parameter none: none
    /// - returns : Array of arguments
    func getargumentAllConfigurations() -> [ArgumentsOneConfiguration] {
        return self.argumentAllConfigurations ?? []
    }

    /// Function for getting the number of configurations used in NSTableViews
    /// - parameter none: none
    /// - returns : Int
    func configurationsDataSourcecount() -> Int {
        if self.configurationsDataSource == nil {
            return 0
        } else {
            return self.configurationsDataSource!.count
        }
    }

    /// Function for getting Configurations read into memory
    /// as datasource for tableViews
    /// - parameter none: none
    /// - returns : Array of Configurations
    func getConfigurationsDataSource() -> [NSMutableDictionary]? {
        return self.configurationsDataSource
    }

    /// Function for getting all Configurations
    /// - parameter none: none
    /// - returns : Array of NSDictionary
    func getConfigurationsDataSourcecountBackup() -> [NSMutableDictionary]? {
        let configurations: [Configuration] = self.configurations!.filter({return ($0.task == ViewControllerReference.shared.synchronize ||
            $0.task == ViewControllerReference.shared.snapshot)})
        var data = [NSMutableDictionary]()
        for i in 0 ..< configurations.count {
            let row: NSMutableDictionary = ConvertOneConfig(config: self.configurations![i]).dict
            if (row.value(forKey: "offsiteServerCellID") as? String)?.isEmpty == true {
                row.setValue("localhost", forKey: "offsiteServerCellID")
            }
            if self.quickbackuplist != nil {
                let quickbackup = self.quickbackuplist!.filter({$0 == configurations[i].hiddenID})
                if quickbackup.count > 0 {
                    row.setValue(1, forKey: "selectCellID")
                }
            }
            data.append(row)
        }
        return data
    }

    func getConfigurationsDataSourcecountBackupSnapshot() -> [NSDictionary]? {
        var configurations: [Configuration] = self.configurations!.filter({return ($0.task == ViewControllerReference.shared.synchronize ||
            $0.task == ViewControllerReference.shared.snapshot )})
        var data = [NSDictionary]()
        for i in 0 ..< configurations.count {
            if configurations[i].offsiteServer.isEmpty == true {
                configurations[i].offsiteServer = "localhost"
            }
            data.append(ConvertOneConfig(config: self.configurations![i]).dict2)
        }
        return data
    }

    /// Function returns all Configurations marked for backup.
    /// - returns : array of Configurations
    func getConfigurationsBatch() -> [Configuration] {
        return self.configurations!.filter({return ($0.task == ViewControllerReference.shared.synchronize ||
            $0.task == ViewControllerReference.shared.snapshot ) && ($0.batch == "yes")})
    }

    /// Function computes arguments for rsync, either arguments for
    /// real runn or arguments for --dry-run for Configuration at selected index
    /// - parameter index: index of Configuration
    /// - parameter argtype : either .arg or .argdryRun (of enumtype argumentsRsync)
    /// - returns : array of Strings holding all computed arguments
    func arguments4rsync(index: Int, argtype: ArgumentsRsync) -> [String] {
        let allarguments = self.argumentAllConfigurations![index]
        switch argtype {
        case .arg:
            return allarguments.arg ?? []
        case .argdryRun:
            return allarguments.argdryRun ?? []
        case .argdryRunlocalcataloginfo:
            return allarguments.argdryRunLocalcatalogInfo ?? []
        }
    }

    /// Function computes arguments for rsync, either arguments for
    /// real runn or arguments for --dry-run for Configuration at selected index
    /// - parameter index: index of Configuration
    /// - parameter argtype : either .arg or .argdryRun (of enumtype argumentsRsync)
    /// - returns : array of Strings holding all computed arguments
    func arguments4restore(index: Int, argtype: ArgumentsRsync) -> [String] {
        let allarguments = self.argumentAllConfigurations![index]
        switch argtype {
        case .arg:
            return allarguments.restore ?? []
        case .argdryRun:
            return allarguments.restoredryRun ?? []
        default:
            return []
        }
    }

    func arguments4tmprestore(index: Int, argtype: ArgumentsRsync) -> [String] {
        let allarguments = self.argumentAllConfigurations![index]
        switch argtype {
        case .arg:
            return allarguments.tmprestore ?? []
        case .argdryRun:
            return allarguments.tmprestoredryRun ?? []
        default:
            return []
        }
    }

    func arguments4verify(index: Int) -> [String] {
        let allarguments = self.argumentAllConfigurations![index]
        return allarguments.verify ?? []
    }

    /// Function is adding new Configurations to existing in memory.
    /// - parameter dict : new record configuration
    func appendconfigurationstomemory (dict: NSDictionary) {
        let config = Configuration(dictionary: dict)
        self.configurations!.append(config)
    }

    /// Function sets currentDate on Configuration when executed on task
    /// stored in memory and then saves updated configuration from memory to persistent store.
    /// Function also notifies Execute view to refresh data
    /// in tableView.
    /// - parameter index: index of Configuration to update
    func setCurrentDateonConfigurationQuickbackup (index: Int, outputprocess: OutputProcess?) {
        if self.configurations![index].task == ViewControllerReference.shared.snapshot {
            self.increasesnapshotnum(index: index)
        }
        let currendate = Date()
        let dateformatter = Dateandtime().setDateformat()
        self.configurations![index].dateRun = dateformatter.string(from: currendate)
        // Saving updated configuration in memory to persistent store
        self.storageapi!.saveConfigFromMemory()
        // Call the view and do a refresh of tableView
        self.reloadtable(vcontroller: .vctabmain)
        _ = Logging(outputprocess: outputprocess)
    }

    func setCurrentDateonConfiguration(index: Int, outputprocess: OutputProcess?) {
        let number = Numbers(outputprocess: outputprocess)
        let hiddenID = self.gethiddenID(index: index)
        let numbers = number.stats()
        self.schedules!.addlogtaskmanuel(hiddenID, result: numbers)
        if self.configurations![index].task == ViewControllerReference.shared.snapshot {
            self.increasesnapshotnum(index: index)
        }
        let currendate = Date()
        let dateformatter = Dateandtime().setDateformat()
        self.configurations![index].dateRun = dateformatter.string(from: currendate)
        // Saving updated configuration in memory to persistent store
        self.storageapi!.saveConfigFromMemory()
        // Call the view and do a refresh of tableView
        self.reloadtable(vcontroller: .vctabmain)
        _ = Logging(outputprocess: outputprocess)
    }

    /// Function is updating Configurations in memory (by record) and
    /// then saves updated Configurations from memory to persistent store
    /// - parameter config: updated configuration
    /// - parameter index: index to Configuration to replace by config
    func updateConfigurations (_ config: Configuration, index: Int) {
        self.configurations![index] = config
        self.storageapi!.saveConfigFromMemory()
    }

    /// Function deletes Configuration in memory at hiddenID and
    /// then saves updated Configurations from memory to persistent store.
    /// Function computes index by hiddenID.
    /// - parameter hiddenID: hiddenID which is unique for every Configuration
    func deleteConfigurationsByhiddenID (hiddenID: Int) {
        let index = self.getIndex(hiddenID)
        self.configurations!.remove(at: index)
        self.storageapi!.saveConfigFromMemory()
    }

    /// Function toggles Configurations for batch or no
    /// batch. Function updates Configuration in memory
    /// and stores Configuration i memory to
    /// persisten store
    /// - parameter index: index of Configuration to toogle batch on/off
    func setBatchYesNo (_ index: Int) {
        if self.configurations![index].batch == "yes" {
            self.configurations![index].batch = "no"
        } else {
            self.configurations![index].batch = "yes"
        }
        self.storageapi!.saveConfigFromMemory()
        self.reloadtable(vcontroller: .vctabmain)
    }

    // Create batchQueue
    func createbatchQueue() {
        self.batchQueue = BatchTaskWorkQueu(configurations: self)
    }

    /// Function return the reference to object holding data and methods
    /// for batch execution of Configurations.
    /// - returns : reference to to object holding data and methods
    func getbatchQueue() -> BatchTaskWorkQueu? {
        return self.batchQueue
    }

    /// Function is getting the number of rows batchDataQueue
    /// - returns : the number of rows
    func batchQueuecount() -> Int {
        return self.batchQueue?.getbatchtaskstodocount() ?? 0
    }

    func getbatchlist() -> [NSMutableDictionary]? {
        return self.batchQueue?.data
    }

    // Add new configurations
    func addNewConfigurations(_ dict: NSMutableDictionary) {
        self.storageapi!.addandsaveNewConfigurations(dict: dict)
    }

    func getResourceConfiguration(_ hiddenID: Int, resource: ResourceInConfiguration) -> String {
        let result = self.configurations!.filter({return ($0.hiddenID == hiddenID)})
        guard result.count > 0 else { return "" }
        switch resource {
        case .localCatalog:
            return result[0].localCatalog
        case .remoteCatalog:
            return result[0].offsiteCatalog
        case .offsiteServer:
            if result[0].offsiteServer.isEmpty {
                return "localhost"
            } else {
                return result[0].offsiteServer
            }
        case .task:
            return result[0].task
        case .backupid:
            return result[0].backupID
        case .offsiteusername:
            return result[0].offsiteUsername
        case .sshport:
            if result[0].sshport != nil {
                return String(result[0].sshport!)
            } else {
                return ""
            }
        }
    }

    func getIndex(_ hiddenID: Int) -> Int {
        var index: Int = -1
        loop: for i in 0 ..< self.configurations!.count where self.configurations![i].hiddenID == hiddenID {
            index = i
            break loop
        }
        return index
    }

    func gethiddenID (index: Int) -> Int {
        guard index < (self.configurations?.count ?? -1) else { return -1 }
        return self.configurations![index].hiddenID
    }

    func removecompressparameter(index: Int, delete: Bool) {
        guard self.configurations != nil else { return }
        guard index < self.configurations!.count  else { return }
        if delete {
            self.configurations![index].parameter3 = ""
        } else {
            self.configurations![index].parameter3 = "--compress"
        }
    }

    func removeedeleteparameter(index: Int, delete: Bool) {
        guard self.configurations != nil else { return }
        guard index < self.configurations!.count  else { return }
        if delete {
            self.configurations![index].parameter4 = ""
        } else {
            self.configurations![index].parameter4 = "--delete"
        }
    }

    func removeesshparameter(index: Int, delete: Bool) {
        guard self.configurations != nil else { return }
        guard index < self.configurations!.count  else { return }
        if delete {
            self.configurations![index].parameter5 = ""
        } else {
            self.configurations![index].parameter5 = "-e"
        }
    }

    private func increasesnapshotnum(index: Int) {
        guard self.configurations != nil else { return }
        let num = self.configurations![index].snapshotnum ?? 0
        self.configurations![index].snapshotnum  = num + 1
    }

    private func readconfigurations() {
        self.argumentAllConfigurations = [ArgumentsOneConfiguration]()
        let store: [Configuration]? = self.storageapi!.getConfigurations()
        guard store != nil else { return }
        for i in 0 ..< store!.count {
            if store![i].task == ViewControllerReference.shared.synchronize ||
                store![i].task == ViewControllerReference.shared.snapshot {
                    self.configurations!.append(store![i])
                    let rsyncArgumentsOneConfig = ArgumentsOneConfiguration(config: store![i])
                    self.argumentAllConfigurations!.append(rsyncArgumentsOneConfig)
            }
        }
        // Then prepare the datasource for use in tableviews as Dictionarys
        var data = [NSMutableDictionary]()
        for i in 0 ..< self.configurations!.count {
            if self.configurations![i].task == ViewControllerReference.shared.synchronize ||
                self.configurations![i].task == ViewControllerReference.shared.snapshot {
                data.append(ConvertOneConfig(config: self.configurations![i]).dict)
            }
        }
        self.configurationsDataSource = data
    }

    init(profile: String?) {
        self.configurations = [Configuration]()
        self.argumentAllConfigurations = nil
        self.configurationsDataSource = nil
        self.profile = profile
        self.processtermination = .quicktask
        self.storageapi = PersistentStorageAPI(profile: self.profile)
        self.readconfigurations()
        self.createbatchQueue()
    }
}
