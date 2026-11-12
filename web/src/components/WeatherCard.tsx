import { useEffect, useState } from 'react';
import { api, errorMessage } from '../lib/api';
import type { WeatherForecast, WeatherSafety } from '../types';
import { Card, Spinner } from './ui';
import { useT } from '../i18n';

const safetyStyle: Record<WeatherSafety, { wrap: string }> = {
  normal: { wrap: 'border-emerald-200 bg-emerald-50 text-emerald-800' },
  caution: { wrap: 'border-amber-200 bg-amber-50 text-amber-800' },
  danger: { wrap: 'border-red-200 bg-red-50 text-red-800' },
};

function windDir(deg: number | null): string {
  if (deg == null) return '—';
  const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  return dirs[Math.round(deg / 45) % 8];
}

function fmt(v: number | null, unit: string, digits = 0): string {
  if (v == null) return '—';
  return `${v.toFixed(digits)} ${unit}`;
}

export default function WeatherCard({
  lat,
  lon,
  title,
}: {
  lat: number;
  lon: number;
  title?: string;
}) {
  const t = useT();
  const [data, setData] = useState<WeatherForecast | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const resolvedTitle = title ?? t('weather.title');

  useEffect(() => {
    let mounted = true;
    setLoading(true);
    setError('');
    api
      .get<WeatherForecast>('/weather', { params: { lat, lon } })
      .then((res) => {
        if (mounted) setData(res.data);
      })
      .catch((err) => {
        if (mounted) setError(errorMessage(err, t('weather.unavailable')));
      })
      .finally(() => {
        if (mounted) setLoading(false);
      });
    return () => {
      mounted = false;
    };
  }, [lat, lon, t]);

  if (loading) {
    return (
      <Card className="p-5">
        <div className="flex items-center gap-2 text-sm text-slate-500">
          <Spinner className="h-4 w-4" />
          <span>{t('weather.loading')}</span>
        </div>
      </Card>
    );
  }
  if (error || !data) {
    return (
      <Card className="p-5">
        <h2 className="mb-1 text-lg font-bold text-slate-900">{resolvedTitle}</h2>
        <p className="text-sm text-slate-400">{error || t('weather.unavailable')}</p>
      </Card>
    );
  }

  const s = safetyStyle[data.safety];
  const c = data.current;
  const safetyLabel =
    data.safety === 'danger' ? t('weather.danger') : data.safety === 'caution' ? t('weather.caution') : t('weather.safe');
  return (
    <Card className="p-5">
      <div className="mb-3 flex items-center justify-between gap-3">
        <h2 className="text-lg font-bold text-slate-900">{resolvedTitle}</h2>
        <span className="text-xs text-slate-400">Open-Meteo</span>
      </div>
      <div className={`mb-4 rounded-xl border px-3 py-2 text-sm font-medium ${s.wrap}`}>
        <div className="font-semibold">{safetyLabel}</div>
        <div className="mt-0.5 text-xs opacity-90">{data.safetyReasons.join(' • ')}</div>
      </div>
      <div className="grid grid-cols-2 gap-3 text-sm sm:grid-cols-3">
        <Metric label={t('weather.temp')} value={fmt(c.temperatureC, '°C')} />
        <Metric label={t('weather.wind')} value={fmt(c.windSpeedKph, 'km/h')} />
        <Metric label={t('weather.gusts')} value={fmt(c.windGustsKph, 'km/h')} />
        <Metric label={t('weather.dir')} value={windDir(c.windDirectionDeg)} />
        <Metric label={t('weather.wave')} value={c.waveHeightM != null ? fmt(c.waveHeightM, 'm', 1) : t('weather.noWave')} />
        <Metric label={t('weather.precip')} value={fmt(c.precipitationMm, 'mm', 1)} />
      </div>
      {data.safety === 'danger' && (
        <div className="mt-4 rounded-lg bg-red-600 px-3 py-2 text-center text-sm font-semibold text-white">
          {t('weather.abort')}
        </div>
      )}
    </Card>
  );
}

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg bg-slate-50 px-3 py-2">
      <div className="text-xs uppercase tracking-wide text-slate-400">{label}</div>
      <div className="font-semibold text-slate-800">{value}</div>
    </div>
  );
}
