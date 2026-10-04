import Foundation

/// Saved Open-Meteo responses for Enmore Park on Lin's Thursday (8 Oct 2026),
/// in the live response shape (one location, `timeformat=unixtime`,
/// `timezone=Australia/Sydney`). Hourly values match `LinsThursday`'s conditions.
/// The coordinates are the model grid points Open-Meteo returned for -33.90, 151.17.
enum OpenMeteoSamples {
    static let enmoreParkWeather = Data(#"""
    {
        "latitude": -33.919155,
        "longitude": 151.1596,
        "generationtime_ms": 0.027418136596679688,
        "utc_offset_seconds": 39600,
        "timezone": "Australia/Sydney",
        "timezone_abbreviation": "GMT+11",
        "elevation": 34.0,
        "hourly_units": {"time": "unixtime", "temperature_2m": "°C", "apparent_temperature": "°C", "precipitation_probability": "%", "uv_index": "", "wind_gusts_10m": "km/h"},
        "hourly": {
            "time": [1791378000, 1791381600, 1791385200, 1791388800, 1791392400, 1791396000, 1791399600, 1791403200, 1791406800, 1791410400, 1791414000, 1791417600, 1791421200, 1791424800, 1791428400, 1791432000, 1791435600, 1791439200, 1791442800, 1791446400, 1791450000, 1791453600, 1791457200, 1791460800],
            "temperature_2m": [24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 33.0, 33.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0],
            "apparent_temperature": [24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 33.0, 33.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0, 24.0],
            "precipitation_probability": [10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10],
            "uv_index": [3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 9.0, 9.0, 9.0, 9.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0],
            "wind_gusts_10m": [20.0, 20.0, 20.0, 20.0, 20.0, 20.0, 20.0, 20.0, 20.0, 20.0, 20.0, 20.0, 20.0, 20.0, 20.0, 20.0, 20.0, 20.0, 20.0, 20.0, 20.0, 20.0, 20.0, 20.0]
        }
    }
    """#.utf8)

    /// Starts one hour earlier than the weather (Wednesday 11 pm, PM2.5 99),
    /// so joining by position instead of by time would shift every value.
    static let enmoreParkAirQuality = Data(#"""
    {
        "latitude": -33.899998,
        "longitude": 151.20001,
        "generationtime_ms": 0.10657310485839844,
        "utc_offset_seconds": 39600,
        "timezone": "Australia/Sydney",
        "timezone_abbreviation": "GMT+11",
        "elevation": 34.0,
        "hourly_units": {"time": "unixtime", "pm2_5": "μg/m³"},
        "hourly": {
            "time": [1791374400, 1791378000, 1791381600, 1791385200, 1791388800, 1791392400, 1791396000, 1791399600, 1791403200, 1791406800, 1791410400, 1791414000, 1791417600, 1791421200, 1791424800, 1791428400, 1791432000, 1791435600, 1791439200, 1791442800, 1791446400, 1791450000, 1791453600, 1791457200, 1791460800],
            "pm2_5": [99.0, 60.0, 60.0, 60.0, 60.0, 60.0, 60.0, 60.0, 60.0, 60.0, 60.0, 12.0, 12.0, 12.0, 12.0, 12.0, 12.0, 12.0, 12.0, 12.0, 12.0, 12.0, 12.0, 12.0, 12.0]
        }
    }
    """#.utf8)
}
