//
//  BOMModels.swift
//  papaWeather
//
//  Decodable structs that mirror the Bureau of Meteorology JSON structure.
//

import Foundation

// MARK: - Top-level

struct BOMResponse: Decodable {
    let observations: BOMObservations
}

struct BOMObservations: Decodable {
    let header: [BOMHeader]
    let data: [BOMDataPoint]
}

// MARK: - Header

struct BOMHeader: Decodable {
    let name: String?
    let state: String?
}

// MARK: - Data point  (one observation per 30-min interval)

struct BOMDataPoint: Decodable {
    let sortOrder: Int
    let localDateTime: String
    let apparentT: Double?
    let airTemp: Double?
    let pressMsl: Double?
    let relHum: Int?
    let cloud: String?
    let windDir: String?
    let windSpdKmh: Int?

    enum CodingKeys: String, CodingKey {
        case sortOrder    = "sort_order"
        case localDateTime = "local_date_time"
        case apparentT    = "apparent_t"
        case airTemp      = "air_temp"
        case pressMsl     = "press_msl"
        case relHum       = "rel_hum"
        case cloud
        case windDir      = "wind_dir"
        case windSpdKmh   = "wind_spd_kmh"
    }
}

// MARK: - Forecast location lookup

struct BOMLocationSearchResponse: Decodable {
    let data: [BOMLocationSearchItem]
}

struct BOMLocationSearchItem: Decodable {
    let geohash: String
    let name: String
}

// MARK: - Daily forecast

struct BOMDailyForecastResponse: Decodable {
    let data: [BOMDailyForecastDay]
}

struct BOMDailyForecastDay: Decodable {
    let rain: BOMForecastRain?
    let uv: BOMForecastUV?
    let astronomical: BOMForecastAstronomical?
    let date: String
    let tempMax: Int?
    let tempMin: Int?
    let extendedText: String?
    let shortText: String?
    let fireDanger: String?
    let now: BOMForecastNow?

    enum CodingKeys: String, CodingKey {
        case rain
        case uv
        case astronomical
        case date
        case tempMax = "temp_max"
        case tempMin = "temp_min"
        case extendedText = "extended_text"
        case shortText = "short_text"
        case fireDanger = "fire_danger"
        case now
    }
}

struct BOMForecastAstronomical: Decodable {
    let sunriseTime: String?
    let sunsetTime: String?

    enum CodingKeys: String, CodingKey {
        case sunriseTime = "sunrise_time"
        case sunsetTime  = "sunset_time"
    }
}

struct BOMForecastRain: Decodable {
    let amount: BOMForecastRainAmount?
    let chance: Int?
    let chanceOfNoRainCategory: String?

    enum CodingKeys: String, CodingKey {
        case amount
        case chance
        case chanceOfNoRainCategory = "chance_of_no_rain_category"
    }
}

struct BOMForecastRainAmount: Decodable {
    let min: Int?
    let max: Int?
}

struct BOMForecastUV: Decodable {
    let category: String?
}

// MARK: - Hourly forecast

struct BOMHourlyForecastResponse: Decodable {
    let data: [BOMHourlyForecastPoint]
}

struct BOMHourlyForecastPoint: Decodable {
    let rain: BOMHourlyRain?
    let temp: Int?
    let tempFeelsLike: Int?
    let wind: BOMHourlyWind?
    let relativeHumidity: Int?
    let iconDescriptor: String?
    let time: String
    let isNight: Bool?

    enum CodingKeys: String, CodingKey {
        case rain, temp, wind, time
        case tempFeelsLike    = "temp_feels_like"
        case relativeHumidity = "relative_humidity"
        case iconDescriptor   = "icon_descriptor"
        case isNight          = "is_night"
    }
}

struct BOMHourlyRain: Decodable {
    let chance: Int?
}

struct BOMHourlyWind: Decodable {
    let speedKilometre: Int?
    let gustSpeedKilometre: Int?
    let direction: String?

    enum CodingKeys: String, CodingKey {
        case speedKilometre     = "speed_kilometre"
        case gustSpeedKilometre = "gust_speed_kilometre"
        case direction
    }
}

// MARK: - Warnings list

struct BOMWarningListResponse: Decodable {
    let warnings: [BOMWarningListItem]
}

struct BOMWarningListItem: Decodable {
    let id: String
    let issueDatetimeUtc: String?
    let expiresDatetimeUtc: String?
    let title: String?
    let subTitle: String?
    let phenomenaSummary: String?
    let severityCode: [String]?
    let issueType: String?
    let type: String?
    let areaStateCode: String?

    enum CodingKeys: String, CodingKey {
        case id
        case issueDatetimeUtc   = "issue_datetime_utc"
        case expiresDatetimeUtc = "expires_datetime_utc"
        case title
        case subTitle           = "sub_title"
        case phenomenaSummary   = "phenomena_summary"
        case severityCode       = "severity_code"
        case issueType          = "issue_type"
        case type
        case areaStateCode      = "area_state_code"
    }
}

// MARK: - Warning detail

struct BOMWarningDetailResponse: Decodable {
    let meta: BOMWarningMeta?
    let warning: BOMWarningDetail
}

struct BOMWarningMeta: Decodable {
    let issueDatetimeUtc: String?

    enum CodingKeys: String, CodingKey {
        case issueDatetimeUtc = "issue_datetime_utc"
    }
}

struct BOMWarningDetail: Decodable {
    let id: String
    let issueType: String?
    let onsetDatetimeUtc: String?
    let expiresDatetimeUtc: String?
    let nextIssue: String?
    let title: String?
    let subTitle: String?
    let advice: String?
    let areaSummary: String?
    let phenomenaSummary: String?
    let issuedAt: String?
    let info: [BOMWarningInfoBlock]?

    enum CodingKeys: String, CodingKey {
        case id
        case issueType           = "issue_type"
        case onsetDatetimeUtc    = "onset_datetime_utc"
        case expiresDatetimeUtc  = "expires_datetime_utc"
        case nextIssue           = "next_issue"
        case title
        case subTitle            = "sub_title"
        case advice
        case areaSummary         = "area_summary"
        case phenomenaSummary    = "phenomena_summary"
        case issuedAt            = "issued_at"
        case info
    }
}

struct BOMWarningInfoBlock: Decodable {
    let headline: String?
    let summary: String?
    let situation: String?

    enum CodingKeys: String, CodingKey {
        case headline, summary, situation
    }
}

struct BOMForecastNow: Decodable {
    let isNight: Bool?
    let nowLabel: String?
    let laterLabel: String?
    let tempNow: Int?
    let tempLater: Int?

    enum CodingKeys: String, CodingKey {
        case isNight = "is_night"
        case nowLabel = "now_label"
        case laterLabel = "later_label"
        case tempNow = "temp_now"
        case tempLater = "temp_later"
    }
}
