//
//  main.swift
//  createUser
//
//  Created by Joel Rennich on 6/5/18.
//  Copyright © 2018 Orchard & Grove Inc. All rights reserved.
//

import Foundation
import SystemConfiguration
import OpenDirectory

var format: PropertyListSerialization.PropertyListFormat = .xml

// arguments

var user = ""
var entropy = ""
var iterations = ""
var salt = ""

// user attributes

var first = ""
var last = ""
var pass : String?
var uid : String?
var gid : String?
var guid : String?
var adminUser = false
var printhashes = false

// get all the arguments

let args = CommandLine.arguments

// help statement

if args.contains("-h") || args.contains("-help") {
    print("""
createUser takes a number of options, only one is required `-u` the other options determine if the user is created and/or the password hash is updated.

-u user                   Determines the user short name to create or to update the hash

User creation options
-f first                  First name of the user
-l last                   Last name of the user
-uid uid                  UID of the user
-gid gid                  GID of the user
-guid guid                GUID of the user
-admin                    Determines if the user is an admin or not
-pass pass                Sets the password of the user

Password hash options
-i iterations             Iterations of the hash
-e entropy                Entropy of the hash
-s salt                   Salt of the hash

Other options
-h                        Returns the help statement
-p                        Prints the current hash of the user specified

Examples:

Create a new user

createUser -u joel -f Joel -l Rennich -uid 510 -gid 20 -admin

Will create a new user with the specified attributes. If no password is set you will not be able to authenticate as this user.

createUser -u joel -e Tf5e5HovnQ/MQoG3XNxpfP19bDxMSsdfsdfsdfXOq05vac1e8taMEl23hqvPHCtw+e7qGjty6aaEc1E8jywnO0= -i 2343 -s FwnfiVOsdfaseP6fEr21O05jiZEBVCrSBCDt3hzbk=

Will update the hash for the user with the specified attributes.
""")
    exit(0)
}

for i in 0...(args.count - 1) {
    
    if args[i] == "-p" {
        printhashes = true
    }
    
    if args[i] == "-admin" {
        adminUser = true
    }
    
    if i == (args.count - 1) {
        // last option
        continue
    }
    
    switch args[i] {
    case "-u" :
        user = args[i + 1]
    case "-e" :
        entropy = args[i + 1]
    case "-i" :
        iterations = args[i + 1]
    case "-s" :
        salt = args[i + 1]
    case "-f" :
        first = args[i + 1]
    case "-l" :
        last = args[i + 1]
    case "-uid" :
        uid = args[i + 1]
    case "-gid" :
        gid = args[i + 1]
    case "-guid" :
        guid = args[i + 1]
    case "-pass" :
        pass = args[i + 1]
    default :
        continue
    }
}

if user == "" {
    // no user set, bail
    
    print("Need to set a user")
    exit(0)
}

if first != "" {
    print("Creating a user")
    let uops = UserOps()
    uops.createUser(name: user, first: first, last: last, pass: pass, uid: uid, gid: gid, guid: guid, changePass: false, attributes: nil, admin: adminUser)
}

// set up the OD session

let session = ODSession.default()

let node = try ODNode.init(session: session, type: UInt32(kODNodeTypeAuthentication))

let query = try ODQuery.init(node: node, forRecordTypes: kODRecordTypeUsers, attribute: kODAttributeTypeRecordName, matchType: UInt32(kODMatchEqualTo), queryValues: user, returnAttributes: kODAttributeTypeNativeOnly, maximumResults: 0)

let result = try query.resultsAllowingPartial(false)

let record = result[0] as! ODRecord

if printhashes {
    let hash = try! record.recordDetails(forAttributes: ["dsAttrTypeNative:ShadowHashData"])
    
    let hashData = hash.first?.value as! [Any]
    
    let finalHash = hashData.first! as! Data
    
    let propertyListObject = try? PropertyListSerialization.propertyList(from: finalHash, options: [], format: &format) as! [ String : AnyHashable]
    
    print(propertyListObject?.description ?? "No Hash Data to print")
    
}

if entropy != "" && iterations != "" && salt != "" {
    
    let baseData = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0"><dict><key>SALTED-SHA512-PBKDF2</key><dict><key>entropy</key><data>\(entropy)</data><key>iterations</key><integer>\(iterations)</integer><key>salt</key><data>\(salt)</data></dict></dict></plist>
    """
    
    let newPL = try? PropertyListSerialization.propertyList(from: baseData.data(using: String.Encoding.utf8)!, options: [], format: &format) as! [ String : AnyHashable]
    
    let final = try? PropertyListSerialization.data(fromPropertyList: newPL as Any, format: .binary, options: .init(bitPattern: 0))
    
    try! record.setValue([final], forAttribute: "dsAttrTypeNative:ShadowHashData")
}
