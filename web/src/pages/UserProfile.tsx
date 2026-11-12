import { useCallback, useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { api, errorMessage } from '../lib/api';
import { useAuth } from '../store/AuthContext';
import type { Conversation, FriendRequest, GearItem, User, UserProfileView } from '../types';
import { Alert, Button, Card, Loading, PageHeader } from '../components/ui';
import { Avatar } from '../components/Avatar';
import { PostList } from '../components/PostList';
import { RoleBadge } from '../components/statusBadges';
import { formatDate } from '../lib/format';
import { countryName, useCountries } from '../lib/countries';
import { useT } from '../i18n';

interface Relation {
  isFriend: boolean;
  incoming: FriendRequest | null;
  outgoing: FriendRequest | null;
}

export default function UserProfilePage() {
  const t = useT();
  const { id } = useParams();
  const navigate = useNavigate();
  const { user } = useAuth();
  const countries = useCountries();
  const [view, setView] = useState<UserProfileView | null>(null);
  const [gear, setGear] = useState<GearItem[]>([]);
  const [relation, setRelation] = useState<Relation>({ isFriend: false, incoming: null, outgoing: null });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  const isSelf = user?.id === id;

  const load = useCallback(async () => {
    if (!id) return;
    setError('');
    try {
      const [profileRes, friendsRes, incomingRes, outgoingRes] = await Promise.all([
        api.get<UserProfileView>(`/users/${id}/profile`),
        api.get<User[]>('/friends'),
        api.get<FriendRequest[]>('/friends/requests/incoming'),
        api.get<FriendRequest[]>('/friends/requests/outgoing'),
      ]);
      setView(profileRes.data);
      setGear([]);
      if (profileRes.data.canView && !profileRes.data.blocked && !isSelf) {
        api.get<GearItem[]>(`/gear/${id}?limit=30`).then(({ data }) => setGear(data)).catch(() => undefined);
      }
      setRelation({
        isFriend: friendsRes.data.some((f) => f.id === id),
        incoming: incomingRes.data.find((r) => r.requesterId === id) ?? null,
        outgoing: outgoingRes.data.find((r) => r.addresseeId === id) ?? null,
      });
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setLoading(false);
    }
  }, [id, isSelf]);

  useEffect(() => {
    void load();
  }, [load]);

  const act = async (fn: () => Promise<unknown>) => {
    setBusy(true);
    try {
      await fn();
      await load();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  const messageUser = async () => {
    setBusy(true);
    try {
      const { data } = await api.post<Conversation>('/conversations/direct', { userId: id });
      navigate(`/chats/${data.id}`);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  const toggleBlock = () =>
    act(() =>
      view?.blocked
        ? api.delete(`/blocks/${id}`)
        : api.post('/blocks', { userId: id }),
    );

  if (loading) return <Loading />;
  if (!view) return <Alert>{error || t('user.notFound')}</Alert>;

  const profile = view.user;
  const stats = view.stats;
  const isFriend = relation.isFriend || view.isFriend;

  return (
    <div className="space-y-5">
      <PageHeader title={t('user.profile')} />
      {error && <Alert>{error}</Alert>}

      <Card className="overflow-hidden">
        <div className="h-28 bg-gradient-to-r from-brand-600 to-blue-600" />
        <div className="px-6 pb-6">
          <div className="-mt-10 flex flex-wrap items-end justify-between gap-4">
            <div className="flex items-end gap-4">
              <div className="rounded-full ring-4 ring-white">
                <Avatar user={profile} size="xl" />
              </div>
              <div className="pb-1">
                <div className="flex items-center gap-2">
                  <h1 className="text-xl font-bold text-slate-900">{profile.name}</h1>
                  {profile.role && <RoleBadge role={profile.role} />}
                </div>
                <div className="text-sm text-slate-500">
                  {[profile.city, profile.region, countryName(countries, profile.country)]
                    .filter(Boolean)
                    .join(' · ') || t('user.geoUnknown')}
                </div>
              </div>
            </div>

            <div className="flex flex-wrap gap-2 pb-1">
              {!isSelf && (
                <>
                  {!view.blocked && (
                    <Button tone="outline" onClick={messageUser} loading={busy}>
                      {t('user.message')}
                    </Button>
                  )}
                  {view.blocked ? (
                    <Button tone="green" onClick={toggleBlock} loading={busy}>
                      {t('user.unblock')}
                    </Button>
                  ) : isFriend ? (
                    <>
                      <Button tone="red" onClick={() => act(() => api.delete(`/friends/${id}`))} loading={busy}>
                        {t('user.removeFriend')}
                      </Button>
                      <Button tone="outline" onClick={toggleBlock} loading={busy}>
                        {t('user.block')}
                      </Button>
                    </>
                  ) : relation.incoming ? (
                    <Button tone="green" onClick={() => act(() => api.post(`/friends/requests/${relation.incoming!.id}/accept`))} loading={busy}>
                      {t('user.acceptRequest')}
                    </Button>
                  ) : relation.outgoing ? (
                    <Button tone="outline" onClick={() => act(() => api.delete(`/friends/requests/${relation.outgoing!.id}`))} loading={busy}>
                      {t('user.cancelRequest')}
                    </Button>
                  ) : (
                    <Button onClick={() => act(() => api.post('/friends/requests', { userId: id }))} loading={busy}>
                      {t('user.addFriend')}
                    </Button>
                  )}
                </>
              )}
              {isSelf && (
                <Button onClick={() => navigate('/profile')}>{t('user.editProfile')}</Button>
              )}
            </div>
          </div>

          {view.blocked && (
            <div className="mt-5">
              <Alert>{t('user.blockedAlert')}</Alert>
            </div>
          )}

          {!view.blocked && !view.canView && (
            <div className="mt-5">
              <Alert tone="amber">{t('user.privateAlert')}</Alert>
            </div>
          )}

          {view.canView && (
            <>
              <div className="mt-5 grid grid-cols-2 gap-4 border-t border-slate-100 pt-5 text-sm sm:grid-cols-4">
                <div>
                  <div className="text-xs uppercase tracking-wide text-slate-400">{t('user.xp')}</div>
                  <div className="font-semibold text-slate-800">{profile.xp} XP</div>
                </div>
                <div>
                  <div className="text-xs uppercase tracking-wide text-slate-400">{t('user.memberSince')}</div>
                  <div className="font-semibold text-slate-800">{formatDate(profile.createdAt)}</div>
                </div>
                <div>
                  <div className="text-xs uppercase tracking-wide text-slate-400">{t('user.phone')}</div>
                  <div className="font-semibold text-slate-800">{profile.phone ?? '—'}</div>
                </div>
                <div>
                  <div className="text-xs uppercase tracking-wide text-slate-400">{t('user.email')}</div>
                  <div className="truncate font-semibold text-slate-800">{profile.email ?? '—'}</div>
                </div>
              </div>

              {stats && (
                <div className="mt-5 grid grid-cols-2 gap-4 border-t border-slate-100 pt-5 text-sm sm:grid-cols-3 lg:grid-cols-6">
                  <Stat label={t('user.stat.friends')} value={stats.friends} />
                  <Stat label={t('user.stat.events')} value={stats.eventsAttended} />
                  <Stat label={t('user.stat.organized')} value={stats.eventsOrganized} />
                  <Stat label={t('user.stat.routes')} value={stats.tracksPublished} />
                  <Stat label={t('user.stat.listings')} value={stats.listingsActive} />
                  <Stat
                    label={t('user.stat.rating')}
                    value={stats.reviewsCount > 0 ? `★ ${stats.ratingAverage} (${stats.reviewsCount})` : '—'}
                  />
                </div>
              )}

              {profile.bio && (
                <div className="mt-5 border-t border-slate-100 pt-5">
                  <div className="text-xs uppercase tracking-wide text-slate-400">{t('user.about')}</div>
                  <p className="mt-1 whitespace-pre-line text-sm text-slate-700">{profile.bio}</p>
                </div>
              )}

              {profile.homeWaterBody && (
                <div className="mt-5 border-t border-slate-100 pt-5">
                  <div className="text-xs uppercase tracking-wide text-slate-400">{t('user.homeWaterbody')}</div>
                  <p className="mt-1 text-sm font-medium text-slate-700">{profile.homeWaterBody.name}</p>
                </div>
              )}

              {gear.length > 0 && (
                <div className="mt-5 border-t border-slate-100 pt-5">
                  <div className="text-xs uppercase tracking-wide text-slate-400">{t('user.gear')}</div>
                  <div className="mt-2 flex flex-wrap gap-2">
                    {gear.map((g) => (
                      <span key={g.id} className="inline-flex items-center gap-1 rounded-full border border-slate-200 bg-slate-50 px-2.5 py-1 text-xs font-medium text-slate-700">
                        {g.category}
                        {[g.brand, g.model].filter(Boolean).length > 0 && ` · ${[g.brand, g.model].filter(Boolean).join(' ')}`}
                      </span>
                    ))}
                  </div>
                </div>
              )}
            </>
          )}
        </div>
      </Card>

      {view.canView && !view.blocked && (
        <PostList title={t('user.activity')} authorId={id} showComposer={isSelf} />
      )}
    </div>
  );
}

function Stat({ label, value }: { label: string; value: number | string }) {
  return (
    <div>
      <div className="text-xs uppercase tracking-wide text-slate-400">{label}</div>
      <div className="text-lg font-bold text-slate-900">{value}</div>
    </div>
  );
}
