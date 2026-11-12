import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api, errorMessage } from '../lib/api';
import type { ListingLead, User } from '../types';
import { Alert, Button, Card, EmptyState, Loading, PageHeader } from '../components/ui';
import { Avatar } from '../components/Avatar';
import { LeadStatusBadge } from '../components/statusBadges';
import { formatPrice, relativeTime } from '../lib/format';
import { useT } from '../i18n';

type Tab = 'buying' | 'selling';

export default function MyLeadsPage() {
  const t = useT();
  const [tab, setTab] = useState<Tab>('buying');
  const [leads, setLeads] = useState<ListingLead[]>([]);
  const [buyers, setBuyers] = useState<Record<string, User>>({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      if (tab === 'buying') {
        const { data } = await api.get<ListingLead[]>('/marketplace/leads/mine');
        setLeads(data);
      } else {
        const { data } = await api.get<ListingLead[]>('/marketplace/leads/for-me');
        setLeads(data);
        const ids = [...new Set(data.map((l) => l.buyerId))];
        const entries = await Promise.all(
          ids.map(async (id) => {
            try {
              const { data: u } = await api.get<User>(`/users/${id}`);
              return [id, u] as const;
            } catch {
              return [id, null] as const;
            }
          }),
        );
        const map: Record<string, User> = {};
        for (const [id, u] of entries) if (u) map[id] = u;
        setBuyers(map);
      }
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setLoading(false);
    }
  }, [tab]);

  useEffect(() => {
    void load();
  }, [load]);

  const updateStatus = async (id: string, status: 'accepted' | 'rejected') => {
    try {
      await api.patch(`/marketplace/leads/${id}/status`, { status });
      await load();
    } catch (err) {
      setError(errorMessage(err));
    }
  };

  return (
    <div>
      <PageHeader title={t('leads.title')} subtitle={t('leads.subtitle')} />

      <div className="mb-4 flex gap-2">
        {(['buying', 'selling'] as const).map((k) => (
          <button
            key={k}
            onClick={() => setTab(k)}
            className={`rounded-full px-4 py-2 text-sm font-semibold ${tab === k ? 'bg-brand-600 text-white' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'}`}
          >
            {k === 'buying' ? t('leads.buying') : t('leads.selling')}
          </button>
        ))}
      </div>

      {error && <div className="mb-4"><Alert>{error}</Alert></div>}
      {loading ? (
        <Loading />
      ) : leads.length === 0 ? (
        <EmptyState
          title={tab === 'buying' ? t('leads.noneSent') : t('leads.noneReceived')}
          hint={tab === 'buying' ? t('leads.noneSentHint') : t('leads.noneReceivedHint')}
        />
      ) : (
        <div className="space-y-3">
          {leads.map((lead) => {
            const buyer = buyers[lead.buyerId];
            return (
              <Card key={lead.id} className="p-4">
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div className="min-w-0">
                    <Link to={`/marketplace/${lead.listingId}`} className="font-semibold text-slate-900 hover:underline">
                      {lead.listing?.title ?? t('leads.listingFallback')}
                    </Link>
                    {lead.listing && (
                      <div className="text-sm text-slate-500">{formatPrice(lead.listing.price, lead.listing.currency)}</div>
                    )}
                    {lead.message && <p className="mt-1 text-sm text-slate-600">«{lead.message}»</p>}
                    <div className="mt-1 text-xs text-slate-400">{relativeTime(lead.createdAt)}</div>
                  </div>
                  <LeadStatusBadge status={lead.status} />
                </div>

                {tab === 'selling' && (
                  <div className="mt-3 flex items-center justify-between border-t border-slate-100 pt-3">
                    <Link to={`/users/${lead.buyerId}`} className="flex items-center gap-2">
                      <Avatar user={buyer ?? { name: t('listing.buyer') }} size="sm" />
                      <span className="text-sm font-medium text-slate-700">{buyer?.name ?? t('listing.buyer')}</span>
                    </Link>
                    {lead.status === 'new' && (
                      <div className="flex gap-2">
                        <Button size="sm" tone="green" onClick={() => updateStatus(lead.id, 'accepted')}>
                          {t('leads.accept')}
                        </Button>
                        <Button size="sm" tone="outline" onClick={() => updateStatus(lead.id, 'rejected')}>
                          {t('leads.reject')}
                        </Button>
                      </div>
                    )}
                  </div>
                )}
              </Card>
            );
          })}
        </div>
      )}
    </div>
  );
}
