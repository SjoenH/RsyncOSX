//
//  ViewControllerQuickBackup.swift
//  RsyncOSX
//
//  Created by Thomas Evensen on 22.12.2017.
//  Copyright © 2017 Thomas Evensen. All rights reserved.
//
// swiftlint:disable line_length

import Foundation
import Cocoa

class ViewControllerRemoteInfo: NSViewController, SetDismisser {

    @IBOutlet weak var mainTableView: NSTableView!
    @IBOutlet weak var working: NSProgressIndicator!
    @IBOutlet weak var abortbutton: NSButton!

    var tabledata: [NSMutableDictionary]?
    // remote info tasks
    private var remoteinfotask: RemoteInfoTaskWorkQueue?
    weak var remoteinfotaskDelegate: SetRemoteInfo?

    // Either abort or close
    @IBAction func abort(_ sender: NSButton) {
        self.dismissview(viewcontroller: self, vcontroller: .vctabmain)
    }

    // Initial functions viewDidLoad and viewDidAppear
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        // Setting delegates and datasource
        self.mainTableView.delegate = self
        self.mainTableView.dataSource = self
        self.remoteinfotaskDelegate = ViewControllerReference.shared.getvcref(viewcontroller: .vctabmain) as? ViewControllertabMain
        self.remoteinfotask = RemoteInfoTaskWorkQueue()
        self.remoteinfotaskDelegate?.setremoteinfo(remoteinfotask: self.remoteinfotask)
        self.tabledata = self.remoteinfotask?.records
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        ViewControllerReference.shared.setvcref(viewcontroller: .vcremoteinfo, nsviewcontroller: self)
        globalMainQueue.async(execute: { () -> Void in
            self.mainTableView.reloadData()
        })
    }

}

extension ViewControllerRemoteInfo: NSTableViewDataSource {
    // Delegate for size of table
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.tabledata?.count ?? 0
    }
}

extension ViewControllerRemoteInfo: NSTableViewDelegate, Attributtedestring {
    // TableView delegates
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard self.tabledata != nil else { return nil }
        guard row < self.tabledata!.count else { return nil }
        let object: NSDictionary = (self.tabledata?[row])!
        return object[tableColumn!.identifier] as? String
    }
}

extension ViewControllerRemoteInfo: Reloadandrefresh {

    // Updates tableview according to progress of batch
    func reloadtabledata() {
        globalMainQueue.async(execute: { () -> Void in
            self.mainTableView.reloadData()
        })
    }
}

extension ViewControllerRemoteInfo: UpdateProgress {
    func processTermination() {
        self.reloadtabledata()
    }

    func fileHandler() {
        // nothing
    }
}

extension ViewControllerRemoteInfo: StartStopProgressIndicator {
    func start() {
        // nothing
    }

    func stop() {
        self.working.stopAnimation(nil)
    }

    func complete() {
        // nothing
    }
}
