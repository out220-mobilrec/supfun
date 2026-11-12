import { useCallback, useEffect, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { api, errorMessage } from '../lib/api';
import { useAuth } from '../store/AuthContext';
import type { Conversation, Listing, MarketplaceReview } from '../types';
import { Alert, Button, Card, Field, Loading, Modal, PageHeader, Select, Textarea } from '../components/ui';
import { Avatar } from '../components/Avatar';
import { ListingStatusBadge } from '../components/statusBadges';
import { formatPrice, relativeTime, formatDateTime } from '../lib/format';
import { listingCategoryLabel } from '../lib/labels';
import { useT } from '../i18n';

export default function ListingDetailPage() {
  const t = useT();
  const { id } = useParams();
  const navigate = useNavigate();
  const { user } = useAuth();
  const [listing, setListing] = useState<Listing | null>(null);
  const [photo, setPhoto] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const [offerOpen, setOfferOpen] = useState(false);
  const [offer, setOffer] = useState('');
  const [favorite, setFavorite] = useState(false);
  const [reviews, setReviews] = useState<MarketplaceReview[]>([]);
  const [reviewForm, setReviewForm] = useState({ rating: 5, comment: '' });
  const [reviewMsg, setReviewMsg] = useState('');
  const [reviewErr, setReviewErr] = useState('');

  const load = useCallback(async () => {
    if (!id) return;
    setError('');
    try {
      const [listingRes, reviewsRes, favsRes] = await Promise.all([
        api.get<Listing>(`/marketplace/listings/${id}`),
        api.get<MarketplaceReview[]>(`/marketplace/listings/${id}/reviews`),
        api.get<Listing[]>('/marketplace/favorites'),
      ]);
      setListing(listingRes.data);
      setReviews(reviewsRes.data);
      setFavorite(favsRes.data.some((f) => f.id === id));
      setPhoto(0);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setLoading(false);
    }
  }, [id]);

  const toggleFavorite = async () => {
    if (!listing) return;
    setBusy(true);
    try {
      const { data } = await api.patch<{ favorite: boolean }>(`/marketplace/listings/${listing.id}/favorite`);
      setFavorite(data.favorite);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  const submitReview = async () => {
    if (!listing) return;
    setReviewErr('');
    setReviewMsg('');
    setBusy(true);
    try {
      await api.post(`/marketplace/listings/${listing.id}/reviews`, {
        rating: reviewForm.rating,
        comment: reviewForm.comment.trim() || undefined,
      });
      setReviewForm({ rating: 5, comment: '' });
      setReviewMsg(t('listing.reviewThanks'));
      await load();
    } catch (err) {
      setReviewErr(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  useEffect(() => {
    void load();
  }, [load]);

  const messageSeller = async () => {
    if (!listing) return;
    setBusy(true);
    try {
      const { data } = await api.post<Conversation>('/conversations/direct', { userId: listing.sellerId });
      navigate(`/chats/${data.id}`);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  const sendOffer = async () => {
    if (!listing) return;
    setBusy(true);
    try {
      await api.post(`/marketplace/listings/${listing.id}/leads`, { message: offer.trim() || undefined });
      setOfferOpen(false);
      setOffer('');
      setError('');
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  const complete = async () => {
    if (!listing) return;
    setBusy(true);
    try {
      await api.post(`/marketplace/listings/${listing.id}/complete`);
      await load();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  const remove = async () => {
    if (!listing || !window.confirm(t('listing.confirmRemove'))) return;
    setBusy(true);
    try {
      await api.delete(`/marketplace/listings/${listing.id}`);
      navigate('/marketplace/my');
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  if (loading) return <Loading />;
  if (!listing) return <Alert>{error || t('listing.notFound')}</Alert>;

  const isOwner = listing.sellerId === user?.id;

  return (
    <div className="space-y-5">
      <PageHeader
        title={listing.title}
        subtitle={`${listingCategoryLabel(listing.category)}${listing.city ? ` · ${listing.city}` : ''}`}
        action={
          isOwner ? (
            <div className="flex gap-2">
              <Button tone="outline" onClick={() => navigate(`/marketplace/${listing.id}/edit`)}>
                {t('common.edit')}
              </Button>
              {listing.status === 'active' && (
                <Button tone="green" onClick={complete} loading={busy}>
                  {t('listing.sold')}
                </Button>
              )}
              <Button tone="red" onClick={remove} loading={busy}>
                {t('listing.unpublish')}
              </Button>
            </div>
          ) : (
            <div className="flex gap-2">
              <Button
                tone={favorite ? 'brand' : 'outline'}
                onClick={toggleFavorite}
                loading={busy}
              >
                {favorite ? `★ ${t('listing.favorited')}` : `☆ ${t('listing.favorite')}`}
              </Button>
              <Button tone="outline" onClick={messageSeller} loading={busy}>
                {t('listing.writeSeller')}
              </Button>
            </div>
          )
        }
      />

      {error && <Alert>{error}</Alert>}

      <div className="grid gap-5 lg:grid-cols-3">
        <div className="space-y-3 lg:col-span-2">
          <Card className="overflow-hidden">
            <div className="aspect-[4/3] w-full bg-slate-100">
              {listing.photos?.[photo] ? (
                <img src={listing.photos[photo]} alt={listing.title} className="h-full w-full object-cover" />
              ) : (
                <div className="flex h-full items-center justify-center text-6xl text-slate-300">🏄</div>
              )}
            </div>
          </Card>
          {listing.photos?.length > 1 && (
            <div className="flex gap-2 overflow-x-auto">
              {listing.photos.map((p, i) => (
                <button
                  key={p}
                  onClick={() => setPhoto(i)}
                  className={`h-16 w-16 shrink-0 overflow-hidden rounded-lg border-2 ${i === photo ? 'border-brand-500' : 'border-transparent'}`}
                >
                  <img src={p} alt="" className="h-full w-full object-cover" />
                </button>
              ))}
            </div>
          )}
          <Card className="p-5">
            <h2 className="mb-2 font-bold text-slate-900">{t('label.description')}</h2>
            {listing.description ? (
              <p className="whitespace-pre-line text-sm text-slate-700">{listing.description}</p>
            ) : (
              <p className="text-sm text-slate-400">{t('listing.noDescription')}</p>
            )}
          </Card>

          <Card className="p-5">
            <h2 className="mb-3 font-bold text-slate-900">{t('listing.reviews')} ({reviews.length})</h2>
            <div className="space-y-4">
              {reviews.map((r) => (
                <div key={r.id} className="border-b border-slate-100 pb-3 last:border-0 last:pb-0">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <Avatar user={r.author ?? undefined} size="sm" />
                      <span className="text-sm font-medium text-slate-800">{r.author?.name ?? t('listing.buyer')}</span>
                    </div>
                    <span className="text-sm font-semibold text-amber-500">{'★'.repeat(r.rating)}<span className="text-slate-300">{'★'.repeat(5 - r.rating)}</span></span>
                  </div>
                  {r.comment && <p className="mt-1 text-sm text-slate-600">{r.comment}</p>}
                  <div className="mt-1 text-xs text-slate-400">{relativeTime(r.createdAt)}</div>
                </div>
              ))}
              {reviews.length === 0 && <div className="text-sm text-slate-400">{t('listing.noReviews')}</div>}
            </div>

            {!isOwner && (
              <div className="mt-4 border-t border-slate-100 pt-4">
                {reviewErr && <div className="mb-2"><Alert>{reviewErr}</Alert></div>}
                {reviewMsg && <div className="mb-2"><Alert tone="green">{reviewMsg}</Alert></div>}
                <div className="flex flex-wrap items-end gap-3">
                  <Field label={t('listing.rating')}>
                    <Select
                      value={String(reviewForm.rating)}
                      onChange={(e) => setReviewForm((f) => ({ ...f, rating: Number(e.target.value) }))}
                    >
                      {[5, 4, 3, 2, 1].map((n) => (
                        <option key={n} value={n}>{'★'.repeat(n)}</option>
                      ))}
                    </Select>
                  </Field>
                  <div className="min-w-[200px] flex-1">
                    <Field label={t('listing.comment')}>
                      <Textarea rows={2} value={reviewForm.comment} onChange={(e) => setReviewForm((f) => ({ ...f, comment: e.target.value }))} />
                    </Field>
                  </div>
                  <Button onClick={submitReview} loading={busy}>{t('listing.leaveReview')}</Button>
                </div>
                <p className="mt-2 text-xs text-slate-400">{t('listing.reviewHint')}</p>
              </div>
            )}
          </Card>
        </div>

        <div className="space-y-5">
          <Card className="p-5">
            <div className="flex items-center justify-between">
              <div className="text-3xl font-extrabold text-brand-700">{formatPrice(listing.price, listing.currency)}</div>
              <ListingStatusBadge status={listing.status} />
            </div>
            <div className="mt-1 text-sm text-slate-500">{t('listing.publishedAt')} {relativeTime(listing.createdAt)}</div>
            <div className="mt-1 text-xs text-slate-400">{formatDateTime(listing.createdAt)}</div>
            {!isOwner && listing.status === 'active' && (
              <Button className="mt-4 w-full" onClick={() => setOfferOpen(true)}>
                {t('listing.makeOffer')}
              </Button>
            )}
          </Card>

          <Card className="p-5">
            <div className="text-xs font-semibold uppercase tracking-wide text-slate-400">{t('listing.seller')}</div>
            <Link to={`/users/${listing.sellerId}`} className="mt-3 flex items-center gap-3">
              <Avatar user={listing.seller} />
              <div>
                <div className="font-semibold text-slate-900">{listing.seller?.name ?? t('listing.seller')}</div>
                <div className="text-sm text-slate-500">{listing.seller?.city ?? '—'}</div>
              </div>
            </Link>
          </Card>
        </div>
      </div>

      <Modal open={offerOpen} onClose={() => setOfferOpen(false)} title={t('listing.offerTitle')}>
        <div className="space-y-4">
          <p className="text-sm text-slate-500">{t('listing.offerHint')}</p>
          <Field label={t('listing.messageToSeller')}>
            <Textarea rows={3} value={offer} onChange={(e) => setOffer(e.target.value)} placeholder={t('listing.offerPlaceholder')} />
          </Field>
          <div className="flex justify-end gap-3">
            <Button tone="outline" onClick={() => setOfferOpen(false)}>
              {t('common.cancel')}
            </Button>
            <Button onClick={sendOffer} loading={busy}>
              {t('common.send')}
            </Button>
          </div>
        </div>
      </Modal>
    </div>
  );
}
