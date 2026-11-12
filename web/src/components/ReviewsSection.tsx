import { useCallback, useEffect, useState } from 'react';
import type { FormEvent } from 'react';
import { api, errorMessage } from '../lib/api';
import { useAuth } from '../store/AuthContext';
import { Avatar } from './Avatar';
import { ImageUploader } from './ImageUploader';
import { Alert, Badge, Button, Card, Textarea } from './ui';
import { relativeTime } from '../lib/format';

export type ReviewTargetType = 'track' | 'event';

interface Review {
  id: string;
  targetType: ReviewTargetType;
  targetId: string;
  authorId: string;
  author?: { id: string; name: string; avatarUrl: string | null };
  rating: number;
  comment: string | null;
  photos: string[];
  createdAt: string;
  updatedAt: string;
}

const STARS = [1, 2, 3, 4, 5];

function Stars({ value, size = 'text-base' }: { value: number; size?: string }) {
  return (
    <span className={`${size} leading-none tracking-tight`} aria-label={`Оценка ${value} из 5`}>
      {STARS.map((s) => (
        <span key={s} className={s <= value ? 'text-amber-400' : 'text-slate-300'}>
          ★
        </span>
      ))}
    </span>
  );
}

/**
 * Отзывы о маршруте или заплыве: список, средняя оценка,
 * форма добавления с фотографиями. Повторная отправка обновляет свой отзыв.
 */
export function ReviewsSection({
  targetType,
  targetId,
  title = 'Отзывы',
}: {
  targetType: ReviewTargetType;
  targetId: string;
  title?: string;
}) {
  const { user } = useAuth();
  const [reviews, setReviews] = useState<Review[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [saving, setSaving] = useState(false);
  const [notice, setNotice] = useState('');

  const mine = reviews.find((r) => r.authorId === user?.id) ?? null;
  const [rating, setRating] = useState(5);
  const [comment, setComment] = useState('');
  const [photos, setPhotos] = useState<string[]>([]);
  const [editing, setEditing] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const { data } = await api.get<Review[]>('/reviews', {
        params: { targetType, targetId },
      });
      setReviews(data);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setLoading(false);
    }
  }, [targetType, targetId]);

  useEffect(() => {
    load();
  }, [load]);

  // При появлении своего отзыва подставляем его в форму при правке
  useEffect(() => {
    if (!editing || !mine) return;
    setRating(mine.rating);
    setComment(mine.comment ?? '');
    setPhotos(mine.photos ?? []);
  }, [editing, mine]);

  const avg =
    reviews.length > 0
      ? reviews.reduce((sum, r) => sum + r.rating, 0) / reviews.length
      : 0;

  const startEdit = () => {
    setEditing(true);
    setNotice('');
  };

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setError('');
    setSaving(true);
    try {
      await api.post('/reviews', {
        targetType,
        targetId,
        rating,
        comment: comment || undefined,
        photos,
      });
      setEditing(false);
      setComment('');
      setPhotos([]);
      setNotice('Отзыв сохранён');
      await load();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setSaving(false);
    }
  };

  const remove = async (id: string) => {
    setError('');
    try {
      await api.delete(`/reviews/${id}`);
      await load();
    } catch (err) {
      setError(errorMessage(err));
    }
  };

  const canReview = Boolean(user);

  return (
    <Card className="p-5">
      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <h2 className="font-bold text-slate-900">
          {title}
          {reviews.length > 0 && (
            <span className="ml-2 text-sm font-normal text-slate-500">
              <Stars value={Math.round(avg)} size="text-sm" /> {avg.toFixed(1)} · {reviews.length}
            </span>
          )}
        </h2>
        {canReview && !editing && (
          <Button size="sm" tone={mine ? 'outline' : 'brand'} onClick={startEdit}>
            {mine ? 'Изменить мой отзыв' : 'Написать отзыв'}
          </Button>
        )}
      </div>

      {error && <div className="mb-3"><Alert>{error}</Alert></div>}
      {notice && !error && <div className="mb-3"><Alert tone="green">{notice}</Alert></div>}

      {editing && (
        <form onSubmit={submit} className="mb-5 space-y-3 rounded-lg border border-brand-100 bg-brand-50 p-4">
          <div className="flex items-center gap-2">
            <span className="text-sm font-semibold text-slate-700">Оценка</span>
            <div className="flex gap-1">
              {STARS.map((s) => (
                <button
                  key={s}
                  type="button"
                  onClick={() => setRating(s)}
                  className={`text-2xl leading-none transition ${
                    s <= rating ? 'text-amber-400' : 'text-slate-300 hover:text-amber-300'
                  }`}
                  aria-label={`Поставить ${s}`}
                >
                  ★
                </button>
              ))}
            </div>
          </div>
          <Textarea
            rows={3}
            maxLength={2000}
            placeholder="Что понравилось, что учесть другим"
            value={comment}
            onChange={(e) => setComment(e.target.value)}
          />
          <ImageUploader
            label="Фото"
            hint="До 6 изображений, каждое до 5 МБ"
            max={6}
            value={photos}
            onChange={setPhotos}
          />
          <div className="flex justify-end gap-2">
            <Button type="button" tone="outline" size="sm" onClick={() => setEditing(false)}>
              Отмена
            </Button>
            <Button type="submit" size="sm" loading={saving}>
              Сохранить
            </Button>
          </div>
        </form>
      )}

      {loading ? (
        <div className="text-sm text-slate-500">Загружаем отзывы…</div>
      ) : reviews.length === 0 ? (
        <div className="text-sm text-slate-500">
          Отзывов пока нет — {canReview ? 'станьте первым' : 'авторизуйтесь, чтобы оценить'}.
        </div>
      ) : (
        <div className="space-y-4">
          {reviews.map((review) => (
            <div key={review.id} className="border-t border-slate-100 pt-4 first:border-0 first:pt-0">
              <div className="flex items-start gap-3">
                <Avatar user={review.author as never} size="sm" />
                <div className="min-w-0 flex-1">
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="text-sm font-semibold text-slate-800">
                      {review.author?.name ?? 'Пользователь'}
                    </span>
                    <Stars value={review.rating} size="text-sm" />
                    {review.authorId === user?.id && <Badge tone="brand">вы</Badge>}
                    <span className="text-xs text-slate-400">{relativeTime(review.createdAt)}</span>
                  </div>
                  {review.comment && (
                    <p className="mt-1 whitespace-pre-line text-sm text-slate-600">{review.comment}</p>
                  )}
                  {review.photos?.length > 0 && (
                    <div className="mt-2 flex flex-wrap gap-2">
                      {review.photos.map((url, i) => (
                        <a key={`${review.id}-${i}`} href={url} target="_blank" rel="noreferrer">
                          <img
                            src={url}
                            alt=""
                            className="h-20 w-20 rounded-lg border border-slate-200 object-cover"
                          />
                        </a>
                      ))}
                    </div>
                  )}
                </div>
                {review.authorId === user?.id && (
                  <div className="flex shrink-0 gap-2">
                    <button
                      onClick={startEdit}
                      className="text-xs font-semibold text-slate-500 hover:text-slate-700"
                    >
                      Изменить
                    </button>
                    <button
                      onClick={() => remove(review.id)}
                      className="text-xs font-semibold text-red-500 hover:text-red-700"
                    >
                      Удалить
                    </button>
                  </div>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </Card>
  );
}
