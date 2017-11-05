# TresorApp

## Usage

Just another try to create a great password manager

## Requirements

## Installation

## Author

Hugo Schlecken

## License

<!-- 
/Users/fe/Library/Developer//Xcode/DerivedData/Celetur-glzfvbvldczqhmbskfacpmjdgcfd/Build/Products/Debug-iphoneos/Celetur.app/Frameworks/CeleturKit.framework/CeleturKit:
@rpath/CeleturKit.framework/CeleturKit (compatibility version 1.0.0, current version 1.0.0)
/System/Library/Frameworks/Foundation.framework/Foundation (compatibility version 300.0.0, current version 1445.30.0)
/usr/lib/libobjc.A.dylib (compatibility version 1.0.0, current version 228.0.0)
/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1252.0.0)
/System/Library/Frameworks/CloudKit.framework/CloudKit (compatibility version 1.0.0, current version 719.0.0)
/System/Library/Frameworks/CoreData.framework/CoreData (compatibility version 1.0.0, current version 847.1.0)
/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation (compatibility version 150.0.0, current version 1445.32.0)
/System/Library/Frameworks/Security.framework/Security (compatibility version 1.0.0, current version 0.0.0)
/System/Library/Frameworks/SystemConfiguration.framework/SystemConfiguration (compatibility version 1.0.0, current version 963.0.0)
/System/Library/Frameworks/UIKit.framework/UIKit (compatibility version 1.0.0, current version 3698.21.8)
@rpath/libswiftCloudKit.dylib (compatibility version 1.0.0, current version 900.0.69)
@rpath/libswiftContacts.dylib (compatibility version 1.0.0, current version 900.0.69)
@rpath/libswiftCore.dylib (compatibility version 1.0.0, current version 900.0.69)
@rpath/libswiftCoreData.dylib (compatibility version 1.0.0, current version 900.0.69)
@rpath/libswiftCoreFoundation.dylib (compatibility version 1.0.0, current version 900.0.69)
@rpath/libswiftCoreGraphics.dylib (compatibility version 1.0.0, current version 900.0.69)
@rpath/libswiftCoreImage.dylib (compatibility version 1.0.0, current version 900.0.69)
@rpath/libswiftCoreLocation.dylib (compatibility version 1.0.0, current version 900.0.69)
@rpath/libswiftDarwin.dylib (compatibility version 1.0.0, current version 900.0.69)
@rpath/libswiftDispatch.dylib (compatibility version 1.0.0, current version 900.0.69)
@rpath/libswiftFoundation.dylib (compatibility version 1.0.0, current version 900.0.69)
@rpath/libswiftMetal.dylib (compatibility version 1.0.0, current version 900.0.69)
@rpath/libswiftObjectiveC.dylib (compatibility version 1.0.0, current version 900.0.69)
@rpath/libswiftQuartzCore.dylib (compatibility version 1.0.0, current version 900.0.69)
@rpath/libswiftSwiftOnoneSupport.dylib (compatibility version 1.0.0, current version 900.0.69)
@rpath/libswiftUIKit.dylib (compatibility version 1.0.0, current version 900.0.69)


plain:Test, the quick brown fox jumps over the lazy dog, 123,123,123
key:m5khv18JXKFVIET8pHa0AB4HSaTesxEQ
encryptedText:8e96d94452f14c554b63425f4ac7566d23ee560007ceb4e36b30180971e7bc9708efdc31c2d38bb3474b87f883813253dafa6f236f9f909cbb4b4781fa9ba934

encrypt with openssl using aes256 in ecb:
echo -n "Test, the quick brown fox jumps over the lazy dog, 123,123,123" | openssl enc -aes-256-ecb -K $(echo -n "m5khv18JXKFVIET8pHa0AB4HSaTesxEQ" | xxd -p|tr -d '\n') -nosalt|xxd -p

decrypt with openssl using aes256 in ecb:
FeldBook:TresorApp fe$ echo -n "8e96d94452f14c554b63425f4ac7566d23ee560007ceb4e36b30180971e7bc9708efdc31c2d38bb3474b87f883813253dafa6f236f9f909cbb4b4781fa9ba934" | xxd -r -p | openssl enc -d -aes-256-ecb -K $(echo -n "m5khv18JXKFVIET8pHa0AB4HSaTesxEQ" | xxd -p|tr -d '\n') | hexdump -C
00000000  54 65 73 74 2c 20 74 68  65 20 71 75 69 63 6b 20  |Test, the quick |
00000010  62 72 6f 77 6e 20 66 6f  78 20 6a 75 6d 70 73 20  |brown fox jumps |
00000020  6f 76 65 72 20 74 68 65  20 6c 61 7a 79 20 64 6f  |over the lazy do|
00000030  67 2c 20 31 32 33 2c 31  32 33 2c 31 32 33        |g, 123,123,123|
0000003e


-->
