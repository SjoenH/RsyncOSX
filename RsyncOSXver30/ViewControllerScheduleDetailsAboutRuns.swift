//
//  ViewControllerScheduleDetailsAboutRuns.swift
//  RsyncOSX
//  The ViewController is the logview
//
//  Created by Thomas Evensen on 23/09/2016.
//  Copyright © 2016 Thomas Evensen. All rights reserved.
//

import Foundation
import Cocoa

class ViewControllerScheduleDetailsAboutRuns : NSViewController {
    
    @IBOutlet weak var scheduletable: NSTableView!
    var tabledata:[NSDictionary]?
    // Search field
    @IBOutlet weak var search: NSSearchField!
    // Buttons
    @IBOutlet weak var server: NSButton!
    @IBOutlet weak var Catalog: NSButton!
    @IBOutlet weak var date: NSButton!
    // Search after
    var what:filterLogs?
    
    
    @IBAction func Radiobuttons(_ sender: NSButton) {
        if (self.server.state == NSOnState) {
            self.what = .remoteServer
        } else if (self.Catalog.state == NSOnState) {
            self.what = .localCatalog
        } else if (self.date.state == NSOnState) {
            self.what = .executeDate
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        self.scheduletable.delegate = self
        self.scheduletable.dataSource = self
        self.search.delegate = self
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        GlobalMainQueue.async(execute: { () -> Void in
            self.tabledata = ScheduleDetailsAboutRuns().filter(search: nil, what:nil)
            self.scheduletable.reloadData()
        })
        self.server.state = NSOnState
        self.what = .remoteServer
    }
}


extension ViewControllerScheduleDetailsAboutRuns : NSSearchFieldDelegate {
    
    func searchFieldDidStartSearching(_ sender: NSSearchField){
        if (sender.stringValue.isEmpty) {
            GlobalMainQueue.async(execute: { () -> Void in
                self.tabledata = ScheduleDetailsAboutRuns().filter(search: nil, what:nil)
                self.scheduletable.reloadData()
            })
        } else {
            GlobalMainQueue.async(execute: { () -> Void in
                self.tabledata = ScheduleDetailsAboutRuns().filter(search: sender.stringValue, what:self.what)
                self.scheduletable.reloadData()
            })
        }
    }
    
    func searchFieldDidEndSearching(_ sender: NSSearchField){
        GlobalMainQueue.async(execute: { () -> Void in
            self.tabledata = ScheduleDetailsAboutRuns().filter(search: nil, what:nil)
            self.scheduletable.reloadData()
        })
    }
    
}

extension ViewControllerScheduleDetailsAboutRuns : NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        if (self.tabledata == nil ) {
            return 0
        } else {
            return (self.tabledata!.count)
        }
    }
    
}

extension ViewControllerScheduleDetailsAboutRuns : NSTableViewDelegate {
    
    @objc(tableView:objectValueForTableColumn:row:) func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        let object:NSDictionary = self.tabledata![row]
        return object[tableColumn!.identifier] as? String
    }
    
    // when row is selected
    // setting which table row is selected
    func tableViewSelectionDidChange(_ notification: Notification) {
        let myTableViewFromNotification = notification.object as! NSTableView
        let indexes = myTableViewFromNotification.selectedRowIndexes
        if let index = indexes.first {
            let dict = self.tabledata?[index]
            
            if (self.server.state == NSOnState) {
                if let server = dict?.value(forKey: "offsiteServer") as? String {
                    self.search.stringValue = server
                    self.searchFieldDidStartSearching(self.search)
                }
            } else if (self.Catalog.state == NSOnState) {
                if let server = dict?.value(forKey: "localCatalog") as? String {
                    self.search.stringValue = server
                    self.searchFieldDidStartSearching(self.search)
                }
            } else if (self.date.state == NSOnState) {
                if let server = dict?.value(forKey: "dateExecuted") as? String {
                    self.search.stringValue = server
                    self.searchFieldDidStartSearching(self.search)
                }
            }
        }
    }

}


