FROM swift:6.2

WORKDIR /workspace
CMD ["sh", "-c", "find papaWeather/papaWeather papaWeatherIntents papaWeatherWidgets -name '*.swift' -print0 | xargs -0 swiftc -frontend -parse"]
