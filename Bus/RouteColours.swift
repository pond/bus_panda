//
//  RouteColours.swift
//  Bus Panda
//
//  Created by Andrew Hodgkinson on 26/03/16.
//  Copyright © 2016 Andrew Hodgkinson. All rights reserved.
//
//  From October 2015: MetLink's revised web site is boring and grey!
//  It includes no colours in the realtime service tables, so we have
//  to store an internal hard-coded mapping instead. Deduced from:
//
//  https://www.metlink.org.nz/getting-around/network-map/
//
//  This class is a shared container for a dictionary that provides
//  route colours based on a route number, expressed as a string. Use
//  the 'colours' class method to access the dictionary.
//

import Foundation
import UIKit

@objc class RouteColours : NSObject
{
    // Return the colour dictionary. Key is the route number / code as a
    // String. Value is a six digit hex string. See also "colourFromHexString".
    //
    @objc class func colours() -> NSDictionary
    {
        // On July 15th 2018, MetLink introduced major changes to all routes,
        // including new colours and longer service names like "23e" and "32x".
        //
        if map.count == 0
        {
            for ( k, v ) in oldMap
            {
                map[ k ] = v
            }

            let nowDateTime = Date() // This will be, in essence, in UTC
            let formatter   = DateFormatter()

            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            formatter.timeZone   = TimeZone( identifier: "UTC" )

            let routeChangeDateTime = formatter.date( from: "2018-07-14 11:59:59" )!

            if nowDateTime > routeChangeDateTime
            {
                for ( k, v ) in newMap
                {
                    map[ k ] = v
                }
            }
        }

        return map
    }

    // http://stackoverflow.com/questions/1560081/how-can-i-create-a-uicolor-from-a-hex-string
    //
    // ...or:
    //
    // https://gist.github.com/yannickl/16f0ed38f0698d9a8ae7
    //
    @objc class func colourFromHexString( _ hexString: String ) -> UIColor
    {
        var rgbValue: UInt32 = 0
        let scanner          = Scanner( string: hexString )

        scanner.scanHexInt32( &rgbValue )

        let   red: UInt32 = ( rgbValue & 0xFF0000 ) >> 16
        let green: UInt32 = ( rgbValue &   0xFF00 ) >>  8
        let  blue: UInt32 = ( rgbValue &     0xFF )

        return UIColor(
              red: CGFloat( red   ) / 255.0,
            green: CGFloat( green ) / 255.0,
             blue: CGFloat( blue  ) / 255.0,
            alpha: 1.0
        )
    }

    static let map:    NSMutableDictionary = [:]
    static let newMap: NSDictionary        =
    [
        // Wellington bus routes on or after 2018-07-15:
        //
        // https://www.metlink.org.nz/assets/2018-Wellington-City-Bus-Network/mid-2018-route-map.pdf

        // High frequency routes

        "1":   "E31937",
        "2":   "0072BB",
        "3":   "5E9732",
        "7":   "A0208B",
        "21":  "EE80B3",
        "22":  "F4911D",

        // Other standard routes

        "12":  "59A1D2",
        "14":  "59A1D2",
        "17":  "59A1D2",
        "18":  "59A1D2",
        "19":  "59A1D2",
        "20":  "59A1D2",
        "23":  "59A1D2",
        "24":  "59A1D2",
        "25":  "59A1D2",
        "29":  "59A1D2",
        "60":  "59A1D2",

        // Other peak, extended and express routes

        "12E": "636466",
        "13":  "636466",
        "17E": "636466",
        "18E": "636466",
        "19E": "636466",
        "23E": "636466",
        "26":  "636466",
        "28":  "636466",
        "29E": "636466",
        "30X": "636466",
        "31X": "636466",
        "32X": "636466",
        "33":  "636466",
        "34":  "636466",
        "37":  "636466",
        "56":  "636466",
        "57":  "636466",
        "58":  "636466",
        "60E": "636466",

        // Airport flyer

        "91":  "000000",

        // Wellington Harbour Ferry, rail

        "CCL": "003F5F",
        "WHF": "003F5F",
        "HVL": "003F5F",
        "MEL": "003F5F",
        "JVL": "003F5F",
        "KPL": "003F5F",
        "WRL": "003F5F"
    ]

    static let oldMap: NSDictionary =
    [
        // Wellington bus routes before 2018-07-15

        "1":   "942192",
        "2":   "DF2134",
        "3":   "7AC143",
        "4":   "532380",
        "5":   "F26531",
        "6":   "009B7A",
        "7":   "CE6E19",
        "8":   "CE6E19",
        "9":   "EE362A",
        "10":  "7C3420",
        "11":  "7C3420",
        "13":  "B15C12",
        "14":  "80A1B6",
        "17":  "79C043",
        "18":  "00BCE3",
        "20":  "00BCE3",
        "21":  "607118",
        "22":  "EE8B1A",
        "23":  "F5B50D",
        "24":  "0E3A2B",
        "25":  "00274B",
        "28":  "E7AC09",
        "29":  "047383",
        "30":  "722E1E",
        "31":  "DF2134",
        "32":  "971F85",
        "43":  "779AB0",
        "44":  "09B2E6",
        "45":  "00B1C7",
        "46":  "0073BB",
        "47":  "976114",
        "50":  "0C824D",
        "52":  "59922F",
        "53":  "DF6C1E",
        "54":  "C42168",
        "55":  "722F1E",
        "56":  "F07A23",
        "57":  "F0A96F",
        "58":  "C42168",
        "91":  "F29223",

        // Porirua bus routes

        "97":  "0096D6",
        "210": "7A1500",
        "211": "F37735",
        "220": "008952",
        "226": "0080B2",
        "230": "D31245",
        "235": "E7A614",
        "236": "872174",

        // Hutt Valley bus routes

        "80":  "092F56",
        "81":  "BF3119",
        "83":  "BA2D18",
        "84":  "BA2D18",
        "85":  "BA2D18",
        "90":  "A68977",
        "92":  "A68977",
        "93":  "A68977",
        "110": "9A4E9E",
        "111": "0065A3",
        "112": "72CDF3",
        "114": "B1BA1E",
        "115": "006F4A",
        "120": "54B948",
        "121": "0065A4",
        "130": "00ADEE",
        "145": "00788A",
        "150": "A20046",
        "154": "EF5091",
        "160": "E31837",
        "170": "878502",

        // Kapiti Coast bus routes

        "250": "00689E",
        "260": "570861",
        "261": "ED1D24",
        "262": "88AF65",
        "270": "F36F21",
        "280": "233E99",
        "290": "00A4E3",

        // Wairarapa bus routes

        "200": "EF5091",
        "201": "007B85",
        "202": "FDB913",
        "203": "7E81BE",
        "204": "B4CC95",
        "205": "72CDF4",
        "206": "DD0A61",

        // Just in case - train, cable car and ferry routes

        "CCL": "808285",
        "WHF": "13B6EA",
        "HVL": "000000",
        "MEL": "000000",
        "JVL": "000000",
        "KPL": "000000",
        "WRL": "000000",
    ]
}
