import { Injectable, Logger } from '@nestjs/common';
import { WeatherCurrent, WeatherForecast, WeatherHourly, WeatherSafety } from './weather.types';

type Json = Record<string, unknown>;

function num(v: unknown): number | null {
  return typeof v === 'number' && Number.isFinite(v) ? v : null;
}

function arr(v: unknown): unknown[] {
  return Array.isArray(v) ? v : [];
}

@Injectable()
export class WeatherService {
  private readonly logger = new Logger(WeatherService.name);

  async getForecast(latitude: number, longitude: number): Promise<WeatherForecast> {
    const lat = latitude.toFixed(5);
    const lon = longitude.toFixed(5);
    const forecastUrl =
      `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}` +
      `&current=temperature_2m,wind_speed_10m,wind_direction_10m,wind_gusts_10m,weather_code,precipitation` +
      `&hourly=temperature_2m,wind_speed_10m,wind_gusts_10m,precipitation_probability,weather_code` +
      `&forecast_days=1&wind_speed_unit=kmh&timezone=auto`;
    const marineUrl =
      `https://marine-api.open-meteo.com/v1/marine?latitude=${lat}&longitude=${lon}` +
      `&current=wave_height&hourly=wave_height&forecast_days=1&timezone=auto`;

    const [forecastRes, marineRes] = await Promise.allSettled([
      this.fetchJson(forecastUrl),
      this.fetchJson(marineUrl),
    ]);

    if (forecastRes.status !== 'fulfilled') {
      this.logger.warn(`forecast fetch failed: ${String(forecastRes.reason)}`);
      throw forecastRes.reason;
    }
    const f = forecastRes.value;
    const m = marineRes.status === 'fulfilled' ? marineRes.value : null;
    if (marineRes.status === 'rejected') {
      this.logger.debug(`marine fetch unavailable: ${String(marineRes.reason)}`);
    }

    const timezone = typeof f.timezone === 'string' ? f.timezone : 'UTC';
    const current = this.parseCurrent(f, m);
    const hourly = this.parseHourly(f, m);
    const { safety, reasons } = this.assess(current);

    return {
      latitude,
      longitude,
      timezone,
      fetchedAt: new Date().toISOString(),
      provider: 'open-meteo',
      safety,
      safetyReasons: reasons,
      current,
      hourly,
    };
  }

  private async fetchJson(url: string): Promise<Json> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 8000);
    try {
      const res = await fetch(url, {
        signal: controller.signal,
        headers: { Accept: 'application/json' },
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      return (await res.json()) as Json;
    } finally {
      clearTimeout(timer);
    }
  }

  private parseCurrent(f: Json, m: Json | null): WeatherCurrent {
    const c = (f.current ?? {}) as Json;
    const mc = (m?.current ?? {}) as Json;
    return {
      time: typeof c.time === 'string' ? c.time : new Date().toISOString(),
      temperatureC: num(c.temperature_2m),
      windSpeedKph: num(c.wind_speed_10m),
      windDirectionDeg: num(c.wind_direction_10m),
      windGustsKph: num(c.wind_gusts_10m),
      precipitationMm: num(c.precipitation),
      weatherCode: num(c.weather_code),
      waveHeightM: num(mc.wave_height),
    };
  }

  private parseHourly(f: Json, m: Json | null): WeatherHourly[] {
    const h = (f.hourly ?? {}) as Json;
    const mh = (m?.hourly ?? {}) as Json;
    const times = arr(h.time).map((t) => String(t));
    const waves = arr(mh.wave_height);
    const limit = Math.min(times.length, 24);
    const out: WeatherHourly[] = [];
    for (let i = 0; i < limit; i++) {
      out.push({
        time: times[i],
        temperatureC: num(arr(h.temperature_2m)[i]),
        windSpeedKph: num(arr(h.wind_speed_10m)[i]),
        windGustsKph: num(arr(h.wind_gusts_10m)[i]),
        precipitationProbability: num(arr(h.precipitation_probability)[i]),
        weatherCode: num(arr(h.weather_code)[i]),
        waveHeightM: num(waves[i]),
      });
    }
    return out;
  }

  private assess(current: WeatherCurrent): { safety: WeatherSafety; reasons: string[] } {
    const reasons: string[] = [];
    let level: WeatherSafety = 'normal';
    const wind = current.windGustsKph ?? current.windSpeedKph;
    const wave = current.waveHeightM;
    const code = current.weatherCode ?? 0;

    const bump = (next: WeatherSafety) => {
      if (next === 'danger') level = 'danger';
      else if (next === 'caution' && level !== 'danger') level = 'caution';
    };

    if (wind != null) {
      if (wind >= 40) { bump('danger'); reasons.push(`Порывы ветра ${Math.round(wind)} км/ч`); }
      else if (wind >= 25) { bump('caution'); reasons.push(`Ветер ${Math.round(wind)} км/ч`); }
    }
    if (wave != null) {
      if (wave >= 1.0) { bump('danger'); reasons.push(`Волна ${wave.toFixed(1)} м`); }
      else if (wave >= 0.5) { bump('caution'); reasons.push(`Волна ${wave.toFixed(1)} м`); }
    }
    // thunderstorm / heavy precip codes (WMO)
    if ([95, 96, 99].includes(code)) { bump('danger'); reasons.push('Гроза'); }
    else if ([82, 65, 75].includes(code)) { bump('caution'); reasons.push('Сильные осадки'); }

    if (reasons.length === 0) reasons.push('Условия благоприятные');
    return { safety: level, reasons };
  }
}
