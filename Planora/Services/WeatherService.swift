import Foundation
import CoreLocation
import Combine
import UIKit

/// Service for fetching weather data using Open-Meteo API (no API key required)
class WeatherService: ObservableObject {
    @Published var currentWeather: WeatherData?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let locationService = LocationService()
    private var lastFetchTime: Date?
    private let cacheInterval: TimeInterval = 600 // 10 minutes
    
    init() {
        // Auto-fetch weather when location updates
        locationService.$currentLocation
            .compactMap { $0 }
            .sink { [weak self] location in
                _Concurrency.Task {
                    await self?.fetchWeather(for: location)
                }
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    /// Fetch current weather for user's location
    func fetchCurrentWeather() async {
        await locationService.requestLocation()
    }
    
    /// Fetch weather for specific coordinates
    func fetchWeather(for location: CLLocation) async {
        // Check cache validity
        if let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < cacheInterval,
           currentWeather != nil {
            return
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let weather = try await fetchWeatherData(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            
            await MainActor.run {
                self.currentWeather = weather
                self.lastFetchTime = Date()
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    /// Fetch weather data from Open-Meteo API
    private func fetchWeatherData(latitude: Double, longitude: Double) async throws -> WeatherData {
        let baseURL = "https://api.open-meteo.com/v1/forecast"
        
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,rain,showers,snowfall,weather_code,cloud_cover,pressure_msl,surface_pressure,wind_speed_10m,wind_direction_10m,wind_gusts_10m"),
            URLQueryItem(name: "hourly", value: "temperature_2m,precipitation_probability,weather_code"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum"),
            URLQueryItem(name: "timezone", value: TimeZone.current.identifier),
            URLQueryItem(name: "forecast_days", value: "3")
        ]
        
        guard let url = components.url else {
            throw WeatherError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WeatherError.networkError
        }
        
        let apiResponse = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        return mapToWeatherData(apiResponse)
    }
    
    /// Map Open-Meteo response to our WeatherData model
    private func mapToWeatherData(_ response: OpenMeteoResponse) -> WeatherData {
        let current = response.current
        
        return WeatherData(
            temperature: current.temperature_2m,
            feelsLike: current.apparent_temperature,
            humidity: current.relative_humidity_2m,
            windSpeed: current.wind_speed_10m,
            windDirection: current.wind_direction_10m,
            pressure: current.pressure_msl,
            cloudCover: current.cloud_cover,
            precipitation: current.precipitation,
            weatherCode: current.weather_code,
            isDay: current.is_day == 1,
            condition: weatherCodeToCondition(current.weather_code),
            location: locationService.currentLocationName ?? "Current Location",
            timestamp: Date()
        )
    }
    
    /// Convert WMO weather code to readable condition
    private func weatherCodeToCondition(_ code: Int) -> WeatherCondition {
        switch code {
        case 0:
            return .clear
        case 1, 2, 3:
            return .partlyCloudy
        case 45, 48:
            return .foggy
        case 51, 53, 55:
            return .drizzle
        case 56, 57:
            return .freezingDrizzle
        case 61, 63, 65:
            return .rain
        case 66, 67:
            return .freezingRain
        case 71, 73, 75:
            return .snow
        case 77:
            return .snowGrains
        case 80, 81, 82:
            return .rainShowers
        case 85, 86:
            return .snowShowers
        case 95:
            return .thunderstorm
        case 96, 99:
            return .thunderstormWithHail
        default:
            return .unknown
        }
    }
    
    /// Get weather icon name for UI
    func getWeatherIcon(for condition: WeatherCondition, isDay: Bool) -> String {
        switch condition {
        case .clear:
            return isDay ? "sun.max.fill" : "moon.stars.fill"
        case .partlyCloudy:
            return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case .cloudy:
            return "cloud.fill"
        case .foggy:
            return "cloud.fog.fill"
        case .drizzle, .freezingDrizzle:
            return "cloud.drizzle.fill"
        case .rain, .freezingRain:
            return "cloud.rain.fill"
        case .rainShowers:
            return "cloud.heavyrain.fill"
        case .snow, .snowGrains, .snowShowers:
            return "cloud.snow.fill"
        case .thunderstorm, .thunderstormWithHail:
            return "cloud.bolt.rain.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }
    
    /// Format temperature for display
    func formatTemperature(_ temperature: Double) -> String {
        let formatter = MeasurementFormatter()
        formatter.unitStyle = .short
        
        let temp = Measurement(value: temperature, unit: UnitTemperature.celsius)
        return formatter.string(from: temp)
    }
}

// MARK: - Location Service

class LocationService: NSObject, ObservableObject {
    @Published var currentLocation: CLLocation?
    @Published var currentLocationName: String?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?
    
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        authorizationStatus = locationManager.authorizationStatus
    }
    
    /// Request location permission and update
    func requestLocation() async {
        await MainActor.run {
            switch authorizationStatus {
            case .notDetermined:
                locationManager.requestWhenInUseAuthorization()
            case .denied, .restricted:
                errorMessage = "Location access denied. Please enable in Settings."
            case .authorizedWhenInUse, .authorizedAlways:
                locationManager.requestLocation()
            @unknown default:
                break
            }
        }
    }
    
    /// Open Settings app to location permissions
    func openLocationSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
    }
    
    private func geocodeLocation(_ location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Geocoding error: \(error)")
                return
            }
            
            if let placemark = placemarks?.first {
                DispatchQueue.main.async {
                    if let city = placemark.locality {
                        self.currentLocationName = city
                    } else if let area = placemark.administrativeArea {
                        self.currentLocationName = area
                    } else {
                        self.currentLocationName = "Current Location"
                    }
                }
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        currentLocation = location
        geocodeLocation(location)
        errorMessage = nil
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = error.localizedDescription
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            errorMessage = "Location access denied"
        default:
            break
        }
    }
}

// MARK: - Data Models

struct WeatherData {
    let temperature: Double
    let feelsLike: Double
    let humidity: Int
    let windSpeed: Double
    let windDirection: Double
    let pressure: Double
    let cloudCover: Int
    let precipitation: Double
    let weatherCode: Int
    let isDay: Bool
    let condition: WeatherCondition
    let location: String
    let timestamp: Date
}

enum WeatherCondition: CaseIterable {
    case clear
    case partlyCloudy
    case cloudy
    case foggy
    case drizzle
    case freezingDrizzle
    case rain
    case freezingRain
    case rainShowers
    case snow
    case snowGrains
    case snowShowers
    case thunderstorm
    case thunderstormWithHail
    case unknown
    
    var displayName: String {
        switch self {
        case .clear:
            return "Clear"
        case .partlyCloudy:
            return "Partly Cloudy"
        case .cloudy:
            return "Cloudy"
        case .foggy:
            return "Foggy"
        case .drizzle:
            return "Drizzle"
        case .freezingDrizzle:
            return "Freezing Drizzle"
        case .rain:
            return "Rain"
        case .freezingRain:
            return "Freezing Rain"
        case .rainShowers:
            return "Rain Showers"
        case .snow:
            return "Snow"
        case .snowGrains:
            return "Snow Grains"
        case .snowShowers:
            return "Snow Showers"
        case .thunderstorm:
            return "Thunderstorm"
        case .thunderstormWithHail:
            return "Thunderstorm with Hail"
        case .unknown:
            return "Unknown"
        }
    }
}

// MARK: - API Response Models

struct OpenMeteoResponse: Codable {
    let current: CurrentWeather
    let hourly: HourlyWeather?
    let daily: DailyWeather?
}

struct CurrentWeather: Codable {
    let temperature_2m: Double
    let relative_humidity_2m: Int
    let apparent_temperature: Double
    let is_day: Int
    let precipitation: Double
    let rain: Double?
    let showers: Double?
    let snowfall: Double?
    let weather_code: Int
    let cloud_cover: Int
    let pressure_msl: Double
    let surface_pressure: Double?
    let wind_speed_10m: Double
    let wind_direction_10m: Double
    let wind_gusts_10m: Double?
}

struct HourlyWeather: Codable {
    let time: [String]
    let temperature_2m: [Double]
    let precipitation_probability: [Int]
    let weather_code: [Int]
}

struct DailyWeather: Codable {
    let time: [String]
    let weather_code: [Int]
    let temperature_2m_max: [Double]
    let temperature_2m_min: [Double]
    let precipitation_sum: [Double]
}

enum WeatherError: LocalizedError {
    case invalidURL
    case networkError
    case decodingError
    case locationNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid weather service URL"
        case .networkError:
            return "Unable to fetch weather data"
        case .decodingError:
            return "Unable to parse weather data"
        case .locationNotAvailable:
            return "Location not available"
        }
    }
}
