//
//  Weather Cat
//

import Cocoa
import CoreLocation

import SwiftDate
import SwiftyTimer
import Dollar
import ForecastIO
let forecastIOClient = APIClient(apiKey: "480b791a0bd0965a07bc7b19c4b901e7")

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, CLLocationManagerDelegate {
  // The appearance and behavior of the status item are then set using the button property
  let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(-1)
  let locationManager = CLLocationManager()
  let menu = NSMenu()
  let submenu = NSMenu()

  let currentApparentTemperatureMenuItemTag = 1
  let summarySubmenuItemTag = 2
  let sunriseOrSunsetTimeMenuItemTag = 3
  let alertMenuItemTag = 4

  func applicationDidFinishLaunching(aNotification: NSNotification) {
    self.menu.autoenablesItems = false
    if let button = statusItem.button {
      button.imagePosition = NSCellImagePosition.ImageLeft
      button.image = NSImage(named: "StatusBarButtonImage")
      button.title = "--°"
      statusItem.menu = menu

      let currentApparentTemperatureMenuItem = NSMenuItem(title: "--°", action: #selector(AppDelegate.openForecastInBrowser(_:)), keyEquivalent: "t")
      currentApparentTemperatureMenuItem.tag = currentApparentTemperatureMenuItemTag
      menu.addItem(currentApparentTemperatureMenuItem)

      if let summarySubmenuItem = menu.addItemWithTitle("🔮🌈 -----", action: nil, keyEquivalent: "") {
        summarySubmenuItem.tag = summarySubmenuItemTag
        menu.setSubmenu(submenu, forItem: summarySubmenuItem)
      }

      let sunriseOrSunsetTimeMenuItem = NSMenuItem(title: "🌙 --:--", action: nil, keyEquivalent: "")
      sunriseOrSunsetTimeMenuItem.tag = sunriseOrSunsetTimeMenuItemTag
      sunriseOrSunsetTimeMenuItem.enabled = false
      menu.addItem(sunriseOrSunsetTimeMenuItem)

      // ----------------
      menu.addItem(NSMenuItem.separatorItem())

      let alertMenuItem = NSMenuItem(title: "----", action: #selector(AppDelegate.openAlertInBrowser(_:)), keyEquivalent: "")
      alertMenuItem.tag = alertMenuItemTag
      alertMenuItem.hidden = true
      menu.addItem(alertMenuItem)

      // ----------------
      menu.addItem(NSMenuItem.separatorItem())

      menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApp.terminate(_:)), keyEquivalent: ""))
      updateLocationAndWeather()
      NSTimer.every(1.hour, updateLocationAndWeather)
    }
  }

  func updateLocationAndWeather() {
    self.locationManager.delegate = self
    self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
    self.locationManager.startUpdatingLocation()
  }

  func locationManager(manager: CLLocationManager, didUpdateLocations locations: [AnyObject]) {
    let location:CLLocation = locations[locations.count-1] as! CLLocation
    let latitude = location.coordinate.latitude
    let longitude = location.coordinate.longitude
    locationManager.stopUpdatingLocation() // Stop Location Manager - keep here to run just once -> ⛄️ update daily
    updateWeather(latitude, longitude: longitude)
  }

  func updateWeather(latitude: Double, longitude: Double) {
    // print("location is latitude \(latitude), longitude \(longitude)")
    forecastIOClient.units = .Auto
    forecastIOClient.getForecast(latitude: latitude, longitude: longitude) { (currentForecast, error) -> Void in
      if let currentForecast = currentForecast {
        let apparentTemperature = Int(round((currentForecast.currently?.apparentTemperature)!))

        let weatherUnit = self.localWeatherUnit(currentForecast)
        let windEmoji = self.windEmoji(currentForecast)
        let precipEmoji = self.getCurrentPrecipWeather(currentForecast)

        if let currentApparentTemperatureMenuItem = self.menu.itemWithTag(self.currentApparentTemperatureMenuItemTag) {
          currentApparentTemperatureMenuItem.title = "\(precipEmoji)\(windEmoji) \(apparentTemperature)°\(weatherUnit)"
          currentApparentTemperatureMenuItem.representedObject = "\(latitude),\(longitude)"
        }
        // 🐈 set this to using temp icon in the statusitem
        if let statusItemButton = self.statusItem.button {
          let statusbarItemIcon = currentForecast.currently!.icon!
          print(statusbarItemIcon)
//          if let button = self.statusItem.button {
//            button.image = NSImage(named: "StatusBarButtonImage")
//          }
          // If defined, this property will have one of the following values:
          // 32 x 32 (only need an @2x version).png
          // ClearDay
          // ClearNight
          // Rain
          // Snow
          // Sleet
          // Wind
          // Fog
          // Cloudy
          // PartlyCloudyDay
          // PartlyCloudyNight
          // (weather-cat icon => Developers should ensure that a sensible default is defined, as additional values, such as hail, thunderstorm, or tornado, may be defined in the future.)
          statusItemButton.title = "\(apparentTemperature)°"
        }

        let clothingEmoji = self.clothingEmoji(currentForecast)
        let summary = (currentForecast.daily?.data![0].summary)! as String
        let summarySubmenuItem = self.menu.itemWithTag(self.summarySubmenuItemTag)
        summarySubmenuItem?.title = "\(clothingEmoji) \(summary)"

        self.hourlyForecast(currentForecast)

        self.updateSunriseOrSunsetTime(currentForecast)

        self.updateWeatherAlerts(currentForecast)
      } else if let error = error {
        print(error)
      }
    }
  }

//MARK: - Forecast Methods

  func hourlyForecast(currentForecast: Forecast) {
    let upcomingHours = 12
    let now = NSDate()
    let hourlyForecasts = currentForecast.hourly!.data! as Array
    let hourlyForecastsSplit = $.chunk(hourlyForecasts, size: upcomingHours) as Array
    for hourForecast in hourlyForecastsSplit[0] {
      if now < hourForecast.time {
        let hour = self.hourFormatter(hourForecast.time.hour)
        let apparentTemperature = Int(round((hourForecast.apparentTemperature)!))
        let precipProbability = hourForecast.precipProbability as Float!
        let precipIntensity = hourForecast.precipIntensity as Float!
        let weatherEmoji = getPrecipWeatherEmoji(precipProbability, precipIntensity: precipIntensity)
        submenu.addItemWithTitle("\(apparentTemperature)° \(weatherEmoji) - \(hour)", action: nil, keyEquivalent: "")
      }
    }
  }

  func hourFormatter(hour: Int) -> String {
    if hour < 12 {
      return "\(hour)AM"
    } else {
      return "\(hour-12)PM"
    }
  }

  func windEmoji(currentForecast: Forecast) -> String {
    let windSpeed = currentForecast.currently?.windSpeed
    if windSpeed > 20 {
      return "💨"
    } else {
      return ""
    }
  }

  func clothingEmoji(currentForecast: Forecast) -> String {
    let apparentTemperature = Int(round((currentForecast.currently?.apparentTemperature)!))
    let warm = 70
    let cool = 50
    var clothingEmoji = ""
    if apparentTemperature >= warm {
      clothingEmoji = "👙👟"
    } else if apparentTemperature < warm && apparentTemperature >= cool {
      clothingEmoji = "👕👗"
    } else {
      clothingEmoji = "👖👘"
    }
    return "\(clothingEmoji)"
  }

  func getCurrentPrecipWeather(currentForecast: Forecast) -> String {
    let precipProbability = currentForecast.daily?.data![0].precipProbability as Float!
    let precipIntensity = currentForecast.daily?.data![0].precipIntensity as Float!
    return self.getPrecipWeatherEmoji(precipProbability, precipIntensity: precipIntensity)
  }

  func getPrecipWeatherEmoji(precipProbability: Float, precipIntensity: Float) -> String {
    let highPrecipProbability = 0.6 as Float
    let lowPrecipProbability = 0.2 as Float
    let moderatePrecipIntensity = 0.05 as Float
    // 0.017 in./hr. corresponds to light precipitation, 0.1 in./hr. corresponds to moderate precipitation, and 0.4 in./hr. corresponds to heavy precipitation.
    var precipEmoji = ""
    if precipProbability >= highPrecipProbability && precipIntensity >= moderatePrecipIntensity {
      precipEmoji = "☔️"
    } else if precipProbability >= lowPrecipProbability {
      precipEmoji = "🌂"
    } else if precipProbability < lowPrecipProbability {
      precipEmoji = ""
    }
    return precipEmoji
  }

  func updateSunriseOrSunsetTime(currentForecast: Forecast) {
    let sunset = currentForecast.daily?.data![0].sunsetTime as NSDate!
    let sunrise = currentForecast.daily?.data![0].sunriseTime as NSDate!
    let now = NSDate()
    var sunriseOrSunset = ""
    if now > sunset {
      let sunriseTime = "☀️ \(NSDateFormatter.localizedStringFromDate(sunrise!, dateStyle: NSDateFormatterStyle.NoStyle, timeStyle: NSDateFormatterStyle.ShortStyle))"
      sunriseOrSunset = sunriseTime
    } else {
      let moonPhase = currentForecast.daily?.data![0].moonPhase
      let moon = updateMoonPhaseEmoji(moonPhase!)
      let sunsetTime = "\(moon) \(NSDateFormatter.localizedStringFromDate(sunset!, dateStyle: NSDateFormatterStyle.NoStyle, timeStyle: NSDateFormatterStyle.ShortStyle))"
      sunriseOrSunset = sunsetTime
    }
    let sunriseOrSunsetTimeMenuItem = self.menu.itemWithTag(self.sunriseOrSunsetTimeMenuItemTag)
    sunriseOrSunsetTimeMenuItem?.title = sunriseOrSunset
  }

  func updateMoonPhaseEmoji(moonPhase: Float) -> String {
    var moon = ""
    if moonPhase == 0 || moonPhase == 100 {
      moon = "🌑"
    } else if moonPhase > 0 && moonPhase < 25 {
      moon = "🌒"
    } else if moonPhase == 25 {
      moon = "🌓"
    } else if moonPhase > 25 && moonPhase < 50 {
      moon = "🌔"
    } else if moonPhase == 50 {
      moon = "🌕"
    } else if moonPhase > 50 && moonPhase < 75 {
      moon = "🌖"
    } else if moonPhase == 75 {
      moon = "🌗"
    } else if moonPhase > 75 && moonPhase < 100 {
      moon = "🌘"
    } else {
      moon = "🌙"
    }
    return moon
  }

  func updateWeatherAlerts(currentForecast: Forecast) {
    let alertMenuItem = self.menu.itemWithTag(self.alertMenuItemTag)
    if let alerts: Alert = currentForecast.alerts?[0] {
      alertMenuItem?.title = "\(alerts.title)…"
      alertMenuItem?.hidden = false
      alertMenuItem?.representedObject = "\(alerts.uri)"
    } else {
      alertMenuItem?.hidden = true
    }
  }

  func localWeatherUnit(currentForecast: Forecast) -> String {
    let forecastUnit = currentForecast.flags?.units
    var unit = ""
    if forecastUnit == "us" {
      unit = "F"
    } else {
      unit = "C"
    }
    return unit
  }

  func openAlertInBrowser(sender: AnyObject) {
    if let uri = sender.representedObject {
      NSWorkspace.sharedWorkspace().openURL(NSURL(string: "\(uri!)")!)
    }
  }

  func openForecastInBrowser(sender: AnyObject) {
    if let location = sender.representedObject {
      NSWorkspace.sharedWorkspace().openURL(NSURL(string: "http://forecast.io/#/f/\(location!)")!)
    }
  }

//  func applicationWillTerminate(aNotification: NSNotification) {
    // Insert code here to tear down your application
//  }

}

