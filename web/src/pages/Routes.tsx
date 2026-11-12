import { Link } from 'react-router-dom';
import { PageHeader } from '../components/ui';
import RouteCatalog from '../components/RouteCatalog';
import { useT } from '../i18n';

/** Справочник маршрутов (публичный каталог, `/routes`). */
export default function RoutesPage() {
  const t = useT();
  return (
    <div>
      <PageHeader
        title={t('tracks.routes')}
        subtitle={t('routes.catalogSubtitle')}
      />
      <RouteCatalog />
      <p className="mt-5 text-xs text-slate-400">
        {t('routes.catalogNote')}{' '}
        <Link to="/tracks" className="text-brand-600 hover:underline">{t('routes.personalTracks')} →</Link>
      </p>
    </div>
  );
}
