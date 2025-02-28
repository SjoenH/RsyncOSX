//
//  ViewControllerNew.swift
//  Rsync
//
//  Created by Thomas Evensen on 13/02/16.
//  Copyright © 2016 Thomas Evensen. All rights reserved.
//
//  swiftlint:disable function_body_length line_length

import Foundation
import Cocoa

enum Typebackup {
    case synchronize
    case snapshots
    case singlefile
}

class ViewControllerNewConfigurations: NSViewController, SetConfigurations, VcSchedule, Delay, Index, VcExecute {

    var storageapi: PersistentStorageAPI?
    var newconfigurations: NewConfigurations?
    var tabledata: [NSMutableDictionary]?
    let archive: String = "--archive"
    let verbose: String = "--verbose"
    let compress: String = "--compress"
    let delete: String = "--delete"
    let eparam: String = "-e"
    let ssh: String = "ssh"
    let dryrun: String = "--dry-run"
    var outputprocess: OutputProcess?
    var index: Int?
    // Reference to rsync parameters to use in combox
    var comboBoxValues = [ViewControllerReference.shared.synchronize,
                          ViewControllerReference.shared.snapshot,
                          "single file"]
    var backuptypeselected: Typebackup = .synchronize
    var diddissappear: Bool = false
    var remote: RemoteCapacity?

    @IBOutlet weak var addtable: NSTableView!
    @IBOutlet weak var remotecapacitytable: NSTableView!
    @IBOutlet weak var viewParameter1: NSTextField!
    @IBOutlet weak var viewParameter2: NSTextField!
    @IBOutlet weak var viewParameter3: NSTextField!
    @IBOutlet weak var viewParameter4: NSTextField!
    @IBOutlet weak var viewParameter5: NSTextField!
    @IBOutlet weak var localCatalog: NSTextField!
    @IBOutlet weak var offsiteCatalog: NSTextField!
    @IBOutlet weak var offsiteUsername: NSTextField!
    @IBOutlet weak var offsiteServer: NSTextField!
    @IBOutlet weak var backupID: NSTextField!
    @IBOutlet weak var sshport: NSTextField!
    @IBOutlet weak var rsyncdaemon: NSButton!
    @IBOutlet weak var profilInfo: NSTextField!
    @IBOutlet weak var copyconfigbutton: NSButton!
    @IBOutlet weak var backuptype: NSComboBox!
    @IBOutlet weak var remotecapacitybutton: NSButton!

    @IBAction func totinfo(_ sender: NSButton) {
        guard ViewControllerReference.shared.norsync == false else {
            _ = Norsync()
            return
        }
        self.configurations!.processtermination = .remoteinfotask
        globalMainQueue.async(execute: { () -> Void in
            self.presentAsSheet(self.viewControllerRemoteInfo!)
        })
    }

    @IBAction func quickbackup(_ sender: NSButton) {
        guard ViewControllerReference.shared.norsync == false else {
            _ = Norsync()
            return
        }
        self.openquickbackup()
    }

    @IBAction func automaticbackup(_ sender: NSButton) {
        self.configurations!.processtermination = .automaticbackup
        self.configurations?.remoteinfotaskworkqueue = RemoteInfoTaskWorkQueue(inbatch: false)
        self.presentAsSheet(self.viewControllerEstimating!)
    }

    @IBAction func remotecapacity(_ sender: NSButton) {
        self.remotecapacitybutton.isEnabled = false
        self.remote = RemoteCapacity(object: self)
    }

    @IBAction func copyconfiguration(_ sender: NSButton) {
        guard self.index != nil else { return }
        let hiddenID = self.configurations!.gethiddenID(index: self.index!)
        guard hiddenID > -1 else { return }
        self.localCatalog.stringValue = self.configurations!.getResourceConfiguration(hiddenID, resource: .localCatalog)
        self.offsiteCatalog.stringValue = self.configurations!.getResourceConfiguration(hiddenID, resource: .remoteCatalog)
        self.offsiteUsername.stringValue = self.configurations!.getResourceConfiguration(hiddenID, resource: .offsiteusername)
        self.backupID.stringValue = "copy of " + self.configurations!.getResourceConfiguration(hiddenID, resource: .backupid)
        if self.configurations!.getResourceConfiguration(hiddenID, resource: .offsiteServer) != "localhost" {
            self.offsiteServer.stringValue = self.configurations!.getResourceConfiguration(hiddenID, resource: .offsiteServer)
        } else {
            self.offsiteServer.stringValue = ""
        }
        self.sshport.stringValue = self.configurations!.getResourceConfiguration(hiddenID, resource: .sshport)
    }

    @IBAction func cleartable(_ sender: NSButton) {
        self.newconfigurations = nil
        self.newconfigurations = NewConfigurations()
        globalMainQueue.async(execute: { () -> Void in
            self.addtable.reloadData()
            self.setFields()
        })
    }

    // Userconfiguration button
    @IBAction func userconfiguration(_ sender: NSButton) {
        globalMainQueue.async(execute: { () -> Void in
            self.presentAsSheet(self.viewControllerUserconfiguration!)
        })
    }

    @IBAction func setbackuptype(_ sender: NSComboBox) {
        switch self.backuptype.indexOfSelectedItem {
        case 0:
            self.backuptypeselected = .synchronize
        case 1:
            self.backuptypeselected = .snapshots
        case 2:
            self.backuptypeselected = .singlefile
        default:
            self.backuptypeselected = .synchronize
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.newconfigurations = NewConfigurations()
        self.addtable.delegate = self
        self.addtable.dataSource = self
        self.remotecapacitytable.delegate = self
        self.remotecapacitytable.dataSource = self
        self.localCatalog.toolTip = NSLocalizedString("By using Finder drag and drop filepaths.", comment: "Tooltip")
        self.offsiteCatalog.toolTip = NSLocalizedString("By using Finder drag and drop filepaths.", comment: "Tooltip")
        ViewControllerReference.shared.setvcref(viewcontroller: .vcnewconfigurations, nsviewcontroller: self)
        self.initcombox(combobox: self.backuptype, index: 0)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        ViewControllerReference.shared.activetab = .vcnewconfigurations
        self.backuptypeselected = .synchronize
        self.backuptype.selectItem(at: 0)
        self.index = self.index()
        if self.index != nil {
            self.copyconfigbutton.isEnabled = true
        } else {
            self.copyconfigbutton.isEnabled = false
        }
        if let profile = self.configurations!.getProfile() {
            self.storageapi = PersistentStorageAPI(profile: profile)
        } else {
            self.storageapi = PersistentStorageAPI(profile: nil)
        }
        self.viewParameter1.stringValue = self.archive
        self.viewParameter2.stringValue = self.verbose
        self.viewParameter3.stringValue = self.compress
        self.viewParameter4.stringValue = self.delete
        self.viewParameter5.stringValue = self.eparam + " " + self.ssh
        self.rsyncdaemon.state = .off
    }

    private func initcombox(combobox: NSComboBox, index: Int) {
        combobox.removeAllItems()
        combobox.addItems(withObjectValues: self.comboBoxValues)
        combobox.selectItem(at: index)
    }

    private func setFields() {
        self.localCatalog.stringValue = ""
        self.offsiteCatalog.stringValue = ""
        self.offsiteUsername.stringValue = ""
        self.offsiteServer.stringValue = ""
        self.backupID.stringValue = ""
        self.sshport.stringValue = ""
        self.rsyncdaemon.state = .off
    }

    private func snapshotcreatecatalog (dict: NSDictionary, outputprocess: OutputProcess?) {
        let config: Configuration = Configuration(dictionary: dict)
        guard config.offsiteServer.isEmpty == false else { return }
        let args = SnapshotCreateCatalogArguments(config: config)
        let updatecurrent = SnapshotCreateCatalog(command: args.getCommand(), arguments: args.getArguments())
        updatecurrent.executeProcess(outputprocess: outputprocess)
    }

    @IBAction func addConfig(_ sender: NSButton) {
        let dict: NSMutableDictionary = [
            "task": ViewControllerReference.shared.synchronize,
            "backupID": backupID.stringValue,
            "localCatalog": localCatalog.stringValue,
            "offsiteCatalog": offsiteCatalog.stringValue,
            "offsiteServer": offsiteServer.stringValue,
            "offsiteUsername": offsiteUsername.stringValue,
            "parameter1": self.archive,
            "parameter2": self.verbose,
            "parameter3": self.compress,
            "parameter4": self.delete,
            "parameter5": self.eparam,
            "parameter6": self.ssh,
            "dryrun": self.dryrun,
            "dateRun": "",
            "singleFile": 0]
        dict.setValue("no", forKey: "batch")
        if self.backuptypeselected == .snapshots {
            dict.setValue(ViewControllerReference.shared.snapshot, forKey: "task")
            dict.setValue(1, forKey: "snapshotnum")
            self.outputprocess = OutputProcess()
            self.snapshotcreatecatalog(dict: dict, outputprocess: self.outputprocess)
        } else if self.backuptypeselected == .singlefile {
            dict.setValue(1, forKey: "singleFile")
        }

        if !self.localCatalog.stringValue.hasSuffix("/") && self.backuptypeselected != .singlefile {
            self.localCatalog.stringValue += "/"
            dict.setValue(self.localCatalog.stringValue, forKey: "localCatalog")
        }
        if !self.offsiteCatalog.stringValue.hasSuffix("/") {
            self.offsiteCatalog.stringValue += "/"
            dict.setValue(self.offsiteCatalog.stringValue, forKey: "offsiteCatalog")
        }
        dict.setObject(self.rsyncdaemon.state, forKey: "rsyncdaemon" as NSCopying)
        if sshport.stringValue != "" {
            if let port: Int = Int(self.sshport.stringValue) {
                dict.setObject(port, forKey: "sshport" as NSCopying)
            }
        }
        // If add button is selected without any values
        guard self.localCatalog.stringValue != "/" else {
            self.offsiteCatalog.stringValue = ""
            self.localCatalog.stringValue = ""
            return
        }
        guard self.offsiteCatalog.stringValue != "/" else {
            self.offsiteCatalog.stringValue = ""
            self.localCatalog.stringValue = ""
            return
        }
        self.configurations!.addNewConfigurations(dict)
        self.newconfigurations?.appendnewConfigurations(dict: dict)
        self.tabledata = self.newconfigurations!.getnewConfigurations()
        globalMainQueue.async(execute: { () -> Void in
            self.addtable.reloadData()
        })
        self.setFields()
    }
}

extension ViewControllerNewConfigurations: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == self.addtable {
            return self.newconfigurations?.newConfigurationsCount() ?? 0
        } else {
            return self.remote?.remotecapacity?.count ?? 0
        }
    }
}

extension ViewControllerNewConfigurations: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        if tableView == self.addtable {
            guard self.newconfigurations?.getnewConfigurations() != nil else { return nil }
            let object: NSMutableDictionary = self.newconfigurations!.getnewConfigurations()![row]
            return object[tableColumn!.identifier] as? String
        } else {
            guard self.remote?.remotecapacity != nil else { return nil }
            let object: NSMutableDictionary = self.remote!.remotecapacity![row]
            return object[tableColumn!.identifier] as? String
        }
    }

    func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
        self.tabledata![row].setObject(object!, forKey: (tableColumn?.identifier)! as NSCopying)
    }
}

extension ViewControllerNewConfigurations: DismissViewController {

    func dismiss_view(viewcontroller: NSViewController) {
        self.dismiss(viewcontroller)
    }
}

extension ViewControllerNewConfigurations: SetProfileinfo {
    func setprofile(profile: String, color: NSColor) {
        globalMainQueue.async(execute: { () -> Void in
            self.profilInfo.stringValue = profile
            self.profilInfo.textColor = color
        })
    }
}

extension ViewControllerNewConfigurations: UpdateProgress {
    func processTermination() {
        self.remote?.processTermination()
        self.remotecapacitybutton.isEnabled = self.remote!.enableremotecapacitybutton()
        globalMainQueue.async(execute: { () -> Void in
            self.remotecapacitytable.reloadData()
        })
    }

    func fileHandler() {
        //
    }
}

extension ViewControllerNewConfigurations: OpenQuickBackup {
    func openquickbackup() {
        self.configurations!.processtermination = .quicktask
        globalMainQueue.async(execute: { () -> Void in
            self.presentAsSheet(self.viewControllerQuickBackup!)
        })
    }
}
