import { useEffect, useState } from 'react';
import type { FormEvent } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { api, errorMessage } from '../lib/api';
import type { Listing } from '../types';
import { LISTING_CATEGORIES, type ListingCategory } from '../lib/lists';
import { Alert, Button, Card, Field, Input, Loading, PageHeader, Select, Textarea } from '../components/ui';
import { ImageUploader } from '../components/ImageUploader';
import { listingCategoryLabel } from '../lib/labels';
import { useT } from '../i18n';

const CURRENCIES = ['RUB', 'USD', 'EUR'];

export default function ListingFormPage() {
  const t = useT();
  const { id } = useParams();
  const isEdit = Boolean(id);
  const navigate = useNavigate();
  const [loading, setLoading] = useState(isEdit);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');

  const [form, setForm] = useState({
    title: '',
    category: 'boards' as ListingCategory,
    description: '',
    price: '',
    currency: 'RUB',
    city: '',
    photos: [] as string[],
    latitude: '',
    longitude: '',
  });

  useEffect(() => {
    if (!id) return;
    let mounted = true;
    (async () => {
      try {
        const { data } = await api.get<Listing>(`/marketplace/listings/${id}`);
        if (!mounted) return;
        setForm({
          title: data.title,
          category: data.category as ListingCategory,
          description: data.description ?? '',
          price: data.price?.toString() ?? '',
          currency: data.currency ?? 'RUB',
          city: data.city ?? '',
          photos: data.photos ?? [],
          latitude: data.latitude?.toString() ?? '',
          longitude: data.longitude?.toString() ?? '',
        });
      } catch (err) {
        if (mounted) setError(errorMessage(err));
      } finally {
        if (mounted) setLoading(false);
      }
    })();
    return () => {
      mounted = false;
    };
  }, [id]);

  const set = <K extends keyof typeof form>(key: K, value: (typeof form)[K]) =>
    setForm((f) => ({ ...f, [key]: value }));

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setError('');
    const payload: Record<string, unknown> = {
      title: form.title,
      category: form.category,
      description: form.description || undefined,
      currency: form.currency,
      city: form.city || undefined,
      photos: form.photos,
    };
    payload.price = form.price ? Number(form.price) : null;
    if (form.latitude && form.longitude) {
      payload.latitude = Number(form.latitude);
      payload.longitude = Number(form.longitude);
    }

    setSaving(true);
    try {
      if (isEdit) {
        const { data } = await api.patch<Listing>(`/marketplace/listings/${id}`, payload);
        navigate(`/marketplace/${data.id}`);
      } else {
        const { data } = await api.post<Listing>('/marketplace/listings', payload);
        navigate(`/marketplace/${data.id}`);
      }
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setSaving(false);
    }
  };

  if (loading) return <Loading />;

  return (
    <div className="mx-auto max-w-2xl">
      <PageHeader
        title={isEdit ? t('listing.form.edit') : t('listing.form.new')}
        subtitle={t('listing.form.subtitle')}
      />
      {error && <div className="mb-4"><Alert>{error}</Alert></div>}
      <Card className="p-6">
        <form onSubmit={submit} className="space-y-4">
          <Field label={t('listing.form.titleLabel')}>
            <Input required maxLength={200} value={form.title} onChange={(e) => set('title', e.target.value)} placeholder={t('listing.form.titlePlaceholder')} />
          </Field>
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label={t('label.category')}>
              <Select value={form.category} onChange={(e) => set('category', e.target.value as ListingCategory)}>
                {LISTING_CATEGORIES.map((c) => (
                  <option key={c} value={c}>
                    {listingCategoryLabel(c)}
                  </option>
                ))}
              </Select>
            </Field>
            <Field label={t('label.city')}>
              <Input value={form.city} onChange={(e) => set('city', e.target.value)} placeholder={t('listing.form.cityPlaceholder')} />
            </Field>
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label={t('label.price')} hint={t('listing.form.priceHint')}>
              <Input type="number" min={0} step="0.01" value={form.price} onChange={(e) => set('price', e.target.value)} placeholder="45000" />
            </Field>
            <Field label={t('listing.form.currency')}>
              <Select value={form.currency} onChange={(e) => set('currency', e.target.value)}>
                {CURRENCIES.map((c) => (
                  <option key={c} value={c}>
                    {c}
                  </option>
                ))}
              </Select>
            </Field>
          </div>
          <Field label={t('label.description')}>
            <Textarea rows={4} value={form.description} onChange={(e) => set('description', e.target.value)} placeholder={t('listing.form.descPlaceholder')} />
          </Field>
          <ImageUploader
            label={t('listing.form.photo')}
            hint={t('listing.form.photoHint')}
            max={6}
            value={form.photos}
            onChange={(urls) => set('photos', urls)}
          />
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label={t('listing.form.lat')}>
              <Input type="number" step="any" value={form.latitude} onChange={(e) => set('latitude', e.target.value)} placeholder="48.48" />
            </Field>
            <Field label={t('listing.form.lng')}>
              <Input type="number" step="any" value={form.longitude} onChange={(e) => set('longitude', e.target.value)} placeholder="135.07" />
            </Field>
          </div>
          <div className="flex justify-end gap-3 pt-2">
            <Button type="button" tone="outline" onClick={() => navigate(-1)}>
              {t('common.cancel')}
            </Button>
            <Button type="submit" loading={saving}>
              {isEdit ? t('listing.form.saveBtn') : t('listing.form.publishBtn')}
            </Button>
          </div>
        </form>
      </Card>
    </div>
  );
}
