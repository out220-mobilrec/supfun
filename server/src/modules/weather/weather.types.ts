export type WeatherSafety = 'normal' | 'caution' | 'danger';

export interface WeatherCurrent {
  time: string;
  temperatureC: number | null;
  windSpeedKph: number | null;
  windDirectionDeg: number | null;
  windGustsKph: number | null;
  precipitationMm: number | null;
  weatherCode: number | null;
  waveHeightM: number | null;
}

export interface WeatherHourly {
  time: string;
  temperatureC: number | null;
  windSpeedKph: number | null;
  windGustsKph: number | null;
  precipitationProbability: number | null;
  weatherCode: number | null;
  waveHeightM: number | null;
}

export interface WeatherForecast {
  latitude: number;
  longitude: number;
  timezone: string;
  fetchedAt: string;
  provider: 'open-meteo';
  safety: WeatherSafety;
  safetyReasons: string[];
  current: WeatherCurrent;
  hourly: WeatherHourly[];
}
