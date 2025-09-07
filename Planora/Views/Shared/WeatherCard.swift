import SwiftUI
import Foundation

/// Weather card component for displaying current weather information
struct WeatherCard: View {
    @StateObject private var weatherService = WeatherService()
    let showLocation: Bool
    let compact: Bool
    let onLocationTap: (() -> Void)?
    
    init(
        showLocation: Bool = true,
        compact: Bool = false,
        onLocationTap: (() -> Void)? = nil
    ) {
        self.showLocation = showLocation
        self.compact = compact
        self.onLocationTap = onLocationTap
    }
    
    var body: some View {
        Group {
            if let weather = weatherService.currentWeather {
                weatherContent(weather)
            } else if weatherService.isLoading {
                loadingView
            } else {
                errorView
            }
        }
        .themeCard(padding: compact ? UITheme.Spacing.sm : UITheme.Spacing.md)
        .onAppear {
            _Concurrency.Task {
                await weatherService.fetchCurrentWeather()
            }
        }
        .onTapGesture {
            if weatherService.currentWeather == nil {
                _Concurrency.Task {
                    await weatherService.fetchCurrentWeather()
                }
            }
        }
    }
    
    @ViewBuilder
    private func weatherContent(_ weather: WeatherData) -> some View {
        if compact {
            compactWeatherView(weather)
        } else {
            fullWeatherView(weather)
        }
    }
    
    private func compactWeatherView(_ weather: WeatherData) -> some View {
        HStack(spacing: UITheme.Spacing.sm) {
            // Weather icon
            Image(systemName: weatherIcon(weather))
                .font(.title2)
                .foregroundColor(weatherIconColor(weather))
            
            // Temperature and condition
            VStack(alignment: .leading, spacing: 2) {
                Text(temperatureText(weather.temperature))
                    .font(UITheme.Typography.title3)
                    .fontWeight(.medium)
                    .foregroundColor(UITheme.Colors.primaryText)
                
                Text(weather.condition.displayName)
                    .font(UITheme.Typography.caption)
                    .foregroundColor(UITheme.Colors.secondaryText)
            }
            
            Spacer()
            
            // Location (if enabled)
            if showLocation {
                locationButton(weather.location)
            }
        }
    }
    
    private func fullWeatherView(_ weather: WeatherData) -> some View {
        VStack(spacing: UITheme.Spacing.md) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: UITheme.Spacing.xs) {
                    if showLocation {
                        locationButton(weather.location)
                    }
                    
                    Text("Current Weather")
                        .font(UITheme.Typography.caption)
                        .foregroundColor(UITheme.Colors.secondaryText)
                }
                
                Spacer()
                
                Text(lastUpdatedText(weather.timestamp))
                    .font(UITheme.Typography.caption2)
                    .foregroundColor(UITheme.Colors.tertiary)
            }
            
            // Main weather info
            HStack(spacing: UITheme.Spacing.lg) {
                // Icon and temperature
                VStack(spacing: UITheme.Spacing.sm) {
                    Image(systemName: weatherIcon(weather))
                        .font(.system(size: 48))
                        .foregroundColor(weatherIconColor(weather))
                    
                    Text(temperatureText(weather.temperature))
                        .font(UITheme.Typography.largeTitle)
                        .fontWeight(.medium)
                        .foregroundColor(UITheme.Colors.primaryText)
                }
                
                Spacer()
                
                // Weather details
                VStack(alignment: .trailing, spacing: UITheme.Spacing.xs) {
                    Text(weather.condition.displayName)
                        .font(UITheme.Typography.title3)
                        .foregroundColor(UITheme.Colors.primaryText)
                    
                    Text("Feels like \(temperatureText(weather.feelsLike))")
                        .font(UITheme.Typography.caption)
                        .foregroundColor(UITheme.Colors.secondaryText)
                    
                    Divider()
                        .frame(width: 60)
                    
                    weatherDetailRow("Humidity", "\(weather.humidity)%")
                    weatherDetailRow("Wind", windText(weather))
                    
                    if weather.precipitation > 0 {
                        weatherDetailRow("Rain", "\(String(format: "%.1f", weather.precipitation))mm")
                    }
                }
            }
        }
    }
    
    private func locationButton(_ location: String) -> some View {
        Button(action: {
            onLocationTap?()
        }) {
            HStack(spacing: UITheme.Spacing.xs) {
                Image(systemName: "location.fill")
                    .font(.caption2)
                    .foregroundColor(UITheme.Colors.primary)
                
                Text(location)
                    .font(UITheme.Typography.caption)
                    .foregroundColor(UITheme.Colors.primary)
                    .lineLimit(1)
            }
        }
        .disabled(onLocationTap == nil)
    }
    
    private func weatherDetailRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: UITheme.Spacing.xs) {
            Text(label)
                .font(UITheme.Typography.caption)
                .foregroundColor(UITheme.Colors.secondaryText)
            
            Text(value)
                .font(UITheme.Typography.caption)
                .fontWeight(.medium)
                .foregroundColor(UITheme.Colors.primaryText)
        }
    }
    
    private var loadingView: some View {
        HStack(spacing: UITheme.Spacing.sm) {
            ProgressView()
                .scaleEffect(0.8)
            
            Text("Loading weather...")
                .font(UITheme.Typography.caption)
                .foregroundColor(UITheme.Colors.secondaryText)
            
            Spacer()
        }
        .frame(height: compact ? 30 : 60)
    }
    
    private var errorView: some View {
        HStack(spacing: UITheme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundColor(UITheme.Colors.warning)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Weather Unavailable")
                    .font(UITheme.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(UITheme.Colors.primaryText)
                
                if let error = weatherService.errorMessage {
                    Text(error)
                        .font(UITheme.Typography.caption2)
                        .foregroundColor(UITheme.Colors.secondaryText)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            Button("Retry") {
                _Concurrency.Task {
                    await weatherService.fetchCurrentWeather()
                }
            }
            .font(UITheme.Typography.caption)
            .foregroundColor(UITheme.Colors.primary)
        }
        .frame(height: compact ? 30 : 60)
    }
    
    // MARK: - Helper Methods
    
    private func weatherIcon(_ weather: WeatherData) -> String {
        return weatherService.getWeatherIcon(for: weather.condition, isDay: weather.isDay)
    }
    
    private func weatherIconColor(_ weather: WeatherData) -> Color {
        switch weather.condition {
        case .clear:
            return weather.isDay ? .orange : .blue
        case .partlyCloudy, .cloudy:
            return .gray
        case .rain, .rainShowers, .drizzle:
            return .blue
        case .snow, .snowShowers:
            return .white
        case .thunderstorm, .thunderstormWithHail:
            return .purple
        case .foggy:
            return .gray
        default:
            return UITheme.Colors.secondary
        }
    }
    
    private func temperatureText(_ temperature: Double) -> String {
        return weatherService.formatTemperature(temperature)
    }
    
    private func windText(_ weather: WeatherData) -> String {
        let speed = String(format: "%.0f", weather.windSpeed)
        let direction = windDirectionText(weather.windDirection)
        return "\(speed) km/h \(direction)"
    }
    
    private func windDirectionText(_ degrees: Double) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((degrees + 22.5) / 45) % 8
        return directions[index]
    }
    
    private func lastUpdatedText(_ timestamp: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "Updated \(formatter.string(from: timestamp))"
    }
}

// MARK: - Preview Support

#if DEBUG
extension WeatherData {
    static var sampleSunny: WeatherData {
        WeatherData(
            temperature: 22.0,
            feelsLike: 24.0,
            humidity: 65,
            windSpeed: 12.0,
            windDirection: 225.0,
            pressure: 1013.2,
            cloudCover: 20,
            precipitation: 0.0,
            weatherCode: 0,
            isDay: true,
            condition: .clear,
            location: "San Francisco",
            timestamp: Date()
        )
    }
    
    static var sampleRainy: WeatherData {
        WeatherData(
            temperature: 15.0,
            feelsLike: 13.0,
            humidity: 85,
            windSpeed: 18.0,
            windDirection: 180.0,
            pressure: 1008.5,
            cloudCover: 90,
            precipitation: 2.5,
            weatherCode: 61,
            isDay: false,
            condition: .rain,
            location: "Seattle",
            timestamp: Date()
        )
    }
    
    static var sampleSnowy: WeatherData {
        WeatherData(
            temperature: -2.0,
            feelsLike: -5.0,
            humidity: 75,
            windSpeed: 8.0,
            windDirection: 45.0,
            pressure: 1020.1,
            cloudCover: 100,
            precipitation: 1.2,
            weatherCode: 71,
            isDay: true,
            condition: .snow,
            location: "Montreal",
            timestamp: Date()
        )
    }
}

struct WeatherCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: UITheme.Spacing.lg) {
            // Full weather cards
            Group {
                WeatherCardPreview(weather: .sampleSunny)
                WeatherCardPreview(weather: .sampleRainy)
            }
            
            // Compact weather cards
            VStack(spacing: UITheme.Spacing.sm) {
                WeatherCardPreview(weather: .sampleSunny, compact: true)
                WeatherCardPreview(weather: .sampleSnowy, compact: true)
            }
        }
        .padding()
        .background(UITheme.Colors.groupedBackground)
        .previewDisplayName("Light Mode")
        
        VStack(spacing: UITheme.Spacing.lg) {
            WeatherCardPreview(weather: .sampleRainy)
            WeatherCardPreview(weather: .sampleSnowy, compact: true)
        }
        .padding()
        .background(UITheme.Colors.groupedBackground)
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode")
    }
}

// Helper view for previews
private struct WeatherCardPreview: View {
    let weather: WeatherData
    let compact: Bool
    
    init(weather: WeatherData, compact: Bool = false) {
        self.weather = weather
        self.compact = compact
    }
    
    var body: some View {
        WeatherCard(compact: compact) {
            print("Location tapped")
        }
        .onAppear {
            // Mock the weather service for preview
            // This would need to be implemented properly with a preview-specific service
        }
    }
}
#endif
