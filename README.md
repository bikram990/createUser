#  createUser

Small utility to create users and to update the shadow hash data in a user record via the Open Directory APIs.

This has been tested with macOS Mojave where it solves the problem of being unable to create a new user by creating the raw plist files in the local OD node.

## MacDevOps 2018 Hack Night Project

Thanks to everyone that helped on this project! 

See you next year in YYZ!

## Use

createUser takes a number of options, only one is required `-u` the other options determine if the user is created and/or the password hash is updated.

-u user                     Determines the user name to create or to update the hash

### User creation options

-f first                        First name of the user
-l last                         Last name of the user
-uid uid                      UID of the user
-gid gid                      GID of the user
-guid guid                  GUID of the user
-admin                       Determines if the user is an admin or not
-pass pass                Sets the password of the user

### Password hash options
-i iterations               Iterations of the hash
-e entropy                 Entropy of the hash
-s salt                       Salt of the hash

### Other options
-h                              Returns the help statement
-p                              Prints the current hash of the user specified

### Examples:

Create a new user

`createUser -u joel -f Joel -l Rennich -uid 510 -gid 20 -admin`

Will create a new user with the specified attributes. If no password is set you will not be able to authenticate as this user.

`createUser -u joel -e Tf5e5HovnQ/MQoG3XNxpfP19bDxMSsdfsdfsdfXOq05vac1e8taMEl23hqvPHCtw+e7qGjty6aaEc1E8jywnO0= -i 2343 -s FwnfiVOsdfaseP6fEr21O05jiZEBVCrSBCDt3hzbk=`

Will update the hash for the user with the specified attributes.
