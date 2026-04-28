//
//  MockWeatherService.swift
//  papaWeather
//

import Foundation

enum MockWeatherService {

    static func mockWeather() -> WeatherInfo {
        WeatherInfo(
            stationName: "Laverton",
            observations: [
                WeatherObservation(localDateTime: "11:30am", apparentTemp: 17.4, airTemp: 18.8,
                                   pressureMSL: 1011.7, relHumidity: 81, cloud: "Cloudy",        windDir: "SW", windSpeedKmh: 17),
                WeatherObservation(localDateTime: "11:00am", apparentTemp: 16.8, airTemp: 17.9,
                                   pressureMSL: 1011.9, relHumidity: 83, cloud: "Cloudy",        windDir: "SW", windSpeedKmh: 19),
                WeatherObservation(localDateTime: "10:30am", apparentTemp: 15.9, airTemp: 17.1,
                                   pressureMSL: 1012.1, relHumidity: 85, cloud: "Mostly Cloudy", windDir: "SW", windSpeedKmh: 15),
                WeatherObservation(localDateTime: "10:00am", apparentTemp: 15.2, airTemp: 16.4,
                                   pressureMSL: 1012.4, relHumidity: 86, cloud: "Mostly Cloudy", windDir: "S",  windSpeedKmh: 13),
                WeatherObservation(localDateTime:  "9:30am", apparentTemp: 14.6, airTemp: 15.7,
                                   pressureMSL: 1012.7, relHumidity: 88, cloud: "Overcast",      windDir: "S",  windSpeedKmh: 11),
                WeatherObservation(localDateTime:  "9:00am", apparentTemp: 14.1, airTemp: 15.2,
                                   pressureMSL: 1012.9, relHumidity: 89, cloud: "Overcast",      windDir: "S",  windSpeedKmh: 10),
                WeatherObservation(localDateTime:  "8:30am", apparentTemp: 13.8, airTemp: 14.9,
                                   pressureMSL: 1013.2, relHumidity: 90, cloud: "Overcast",      windDir: "SE", windSpeedKmh:  9),
                WeatherObservation(localDateTime:  "8:00am", apparentTemp: 13.2, airTemp: 14.2,
                                   pressureMSL: 1013.4, relHumidity: 91, cloud: "Cloudy",        windDir: "SE", windSpeedKmh:  8),
                WeatherObservation(localDateTime:  "7:30am", apparentTemp: 12.7, airTemp: 13.7,
                                   pressureMSL: 1013.6, relHumidity: 92, cloud: "Cloudy",        windDir: "E",  windSpeedKmh:  8),
                WeatherObservation(localDateTime:  "7:00am", apparentTemp: 12.1, airTemp: 13.0,
                                   pressureMSL: 1013.8, relHumidity: 93, cloud: "Cloudy",        windDir: "E",  windSpeedKmh:  7),
            ]
        )
    }
}
