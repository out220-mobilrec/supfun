import RouteCatalog from '../../components/RouteCatalog';
import { AdminHeader } from './shared';
import { useT } from '../../i18n';

/**
 * Админ: управление справочником маршрутов (те же маршруты, что и у пользователя,
 * но со всеми черновиками и полным CRUD).
 */
export default function AdminRoutes() {
  const t = useT(); void t;
  return (
    <div>
      <AdminHeader
        title="Справочник маршрутов"
        subtitle="Все маршруты каталога — включая чужие черновики. Клик по карте в режиме создания добавляет точку."
      />
      <RouteCatalog admin />
    </div>
  );
}
