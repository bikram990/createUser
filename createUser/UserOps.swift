//
//  UserOps.swift
//  createUser
//
//  Created by Joel Rennich on 6/5/18.
//  Copyright © 2018 Orchard & Grove Inc. All rights reserved.
//

import Foundation
import OpenDirectory

class UserOps {
    
    // setup
    
    let session = ODSession.init()
    
    ///MARK: Functions
    
    /// Creates a user using the Open Directory APIs
    ///
    /// - Parameters:
    ///   - name: shortname of the user
    ///   - first: first name of the user
    ///   - last: last name of the user
    ///   - pass: plaintext password of the user, set to nil to set the password other ways
    ///   - uid: uid of the user as a String, set to nil to let system choose
    ///   - gid: gid of the user as a String, set to nil to let system choose
    ///   - guid: guid of the new user account, set to nil to let system choose
    ///   - changePass: determines if user can change their own password
    ///   - attributes: [String:Any] of attributes and values to be added to the account
    ///   - hash: PBKDF2 password hash
    
    func createUser(name: String, first: String, last: String, pass: String?, uid: String?, gid: String?, guid: String?, changePass: Bool?, attributes: [String:Any]?, admin: Bool=false) {
        
        let nodeName = "/Local/Default"
        
        var newRecord: ODRecord?
        
        // note for anyone follwing behind me
        // you need to specify the attribute values in an array
        // regardless of if there's more than one value or not
        
        var attrs: [AnyHashable:Any] = [
            kODAttributeTypeFirstName: [first],
            kODAttributeTypeLastName: [last],
            kODAttributeTypeFullName: [first + " " + last],
            kODAttributeTypeNFSHomeDirectory: [ "/Users/" + name ],
            kODAttributeTypeUserShell: ["/bin/bash"]
        ]
        
        if uid != nil {
            attrs[kODAttributeTypeUniqueID] = [uid]
        }
        
        if gid != nil {
            attrs[kODAttributeTypePrimaryGroupID] = [gid]
        }
        
        if guid != nil {
            attrs[kODAttributeTypeGUID] = [guid]
        }
        
        do {
            let node = try ODNode.init(session: session, name: nodeName)
            newRecord = try node.createRecord(withRecordType: kODRecordTypeUsers, name: name, attributes: attrs)
        } catch {
            print("Error: Unable to create OD Record.")
        }
        
        // Set up password to be used on the new user
        
        var password = pass
        
        if pass == nil || pass == "" {
            password = randomString(length: 24)
        }
        
        // now to set the password, skipping this step if NONE is specified
        
        if pass != "NONE" {
            do {
                try newRecord?.changePassword(nil, toPassword: password)
            } catch {
                print("Error: Unable to set password.")
            }
        }
        
        if changePass! {
            do {
                try newRecord?.addValue(name, toAttribute: "dsAttrTypeNative:writers_passwd")
            } catch {
                print("Error: Unable to set writers_passwd.")
            }
        }
        
        // now to add any arbitrary attributes
        
        if attributes != nil {
            for item in attributes! {
                do {
                    try newRecord?.addValue(item.value, toAttribute: item.key)
                } catch {
                    print("Error: unable to set \(item.key)")
                }
            }
        }
        
        if admin {
            do {
                let node = try ODNode.init(session: session, type: ODNodeType(kODNodeTypeLocalNodes))
                let query = try ODQuery.init(node: node,
                                             forRecordTypes: kODRecordTypeGroups,
                                             attribute: kODAttributeTypeRecordName,
                                             matchType: ODMatchType(kODMatchEqualTo),
                                             queryValues: "admin",
                                             returnAttributes: kODAttributeTypeNativeOnly,
                                             maximumResults: 1)
                let results = try query.resultsAllowingPartial(false) as! [ODRecord]
                let adminGroup = results.first
                
                try adminGroup?.addMemberRecord(newRecord)
            } catch {
                print("Error: Unable to make user an admin.")
            }
        }
    }

    // function to delete a user
    
    func deleteUser(guid: String) {
        
        var records = [ODRecord]()
        
        do {
            let node = try ODNode.init(session: session, type: UInt32(kODNodeTypeLocalNodes))
            let query = try ODQuery.init(node: node, forRecordTypes: kODRecordTypeUsers, attribute: kODAttributeTypeGUID, matchType: UInt32(kODMatchEqualTo), queryValues: guid, returnAttributes: kODAttributeTypeNativeOnly, maximumResults: 1)
            records = try query.resultsAllowingPartial(false) as! [ODRecord]
        } catch {
            print("Unable to get user account with guid: " + guid )
        }
        
        do {
            try records.first?.delete()
        } catch {
            print("Error deleting the record with guid: " + guid )
        }
    }
    
    // function to set the password to something specific
    
    func setPassword(guid: String, pass: String) {
        
        // get the user record
        
        var records = [ODRecord]()
        
        do {
            let node = try ODNode.init(session: session, type: UInt32(kODNodeTypeLocalNodes))
            let query = try ODQuery.init(node: node, forRecordTypes: kODRecordTypeUsers, attribute: kODAttributeTypeGUID, matchType: UInt32(kODMatchEqualTo), queryValues: guid, returnAttributes: kODAttributeTypeNativeOnly, maximumResults: 1)
            records = try query.resultsAllowingPartial(false) as! [ODRecord]
        } catch {
            print("Error: Unable to get user account with guid: " + guid )
        }
        
        // figure out the password
        
        var newPassword = ""
        
        switch pass {
        case "<<random>>" :
            newPassword = randomString(length: 24)
        default:
            newPassword = pass
        }
        
        // now to set the password
        
        do {
            try records.first?.changePassword(nil, toPassword: newPassword)
        } catch {
            print("Error: Unable to set password")
        }
    }
    
    // func to get a random string
    
    func randomString(length: Int) -> String {
        
        let letters : NSString = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()"
        let len = UInt32(letters.length)
        
        var randomString = ""
        
        for _ in 0 ..< length {
            let rand = arc4random_uniform(len)
            var nextChar = letters.character(at: Int(rand))
            randomString += NSString(characters: &nextChar, length: 1) as String
        }
        
        return randomString
    }
    
    // function to check for an admin user
    
    func checkAdmin(guid: String) -> Bool {
        
        var records = [ODRecord]()
        var userRecord = [ODRecord]()
        
        let adminGUID = "ABCDEFAB-CDEF-ABCD-EFAB-CDEF00000050"
        
        // does every admin group have the same GUID?
        // ABCDEFAB-CDEF-ABCD-EFAB-CDEF00000050
        // they seem too
        
        do {
            let node = try ODNode.init(session: session, type: UInt32(kODNodeTypeLocalNodes))
            let query = try ODQuery.init(node: node, forRecordTypes: kODRecordTypeGroups, attribute: kODAttributeTypeGUID, matchType: UInt32(kODMatchEqualTo), queryValues: adminGUID, returnAttributes: kODAttributeTypeNativeOnly, maximumResults: 0)
            records = try query.resultsAllowingPartial(false) as! [ODRecord]
            
            let userQuery = try ODQuery.init(node: node, forRecordTypes: kODRecordTypeUsers, attribute: kODAttributeTypeGUID, matchType: UInt32(kODMatchEqualTo), queryValues: guid, returnAttributes: kODAttributeTypeNativeOnly, maximumResults: 1)
            userRecord = try userQuery.resultsAllowingPartial(false) as! [ODRecord]
            
        } catch {
            print("Error: Unable to get user account ODRecords")
            return false
        }
        
        if records.count > 0 {
            
            do {
                if ((try records.first?.isMemberRecord((userRecord.first))) != nil) {
                    return true
                } else {
                    return false
                }
            } catch {
                return false
            }
            
        } else {
            return false
        }
    }
}
