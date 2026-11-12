import { useRef, useState } from 'react';
import { errorMessage, uploadImage } from '../lib/api';
import { Spinner } from './ui';

interface ImageUploaderProps {
  value: string[];
  onChange: (urls: string[]) => void;
  max?: number;
  single?: boolean;
  label?: string;
  hint?: string;
  className?: string;
}

export function ImageUploader({
  value,
  onChange,
  max = 6,
  single = false,
  label,
  hint,
  className = '',
}: ImageUploaderProps) {
  const limit = single ? 1 : max;
  const inputRef = useRef<HTMLInputElement>(null);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState('');

  const pick = () => inputRef.current?.click();

  const handleFiles = async (files: FileList | null) => {
    if (!files || files.length === 0) return;
    setError('');
    const remaining = limit - value.length;
    const selected = Array.from(files).slice(0, Math.max(0, remaining));
    if (selected.length === 0) {
      setError(`Достигнут лимит: ${limit}`);
      return;
    }
    setUploading(true);
    const urls: string[] = [];
    try {
      for (const file of selected) {
        if (!file.type.startsWith('image/')) {
          setError('Можно загружать только изображения');
          continue;
        }
        urls.push(await uploadImage(file));
      }
      if (urls.length > 0) onChange([...value, ...urls]);
    } catch (err) {
      setError(errorMessage(err, 'Не удалось загрузить изображение'));
    } finally {
      setUploading(false);
      if (inputRef.current) inputRef.current.value = '';
    }
  };

  const remove = (url: string) => onChange(value.filter((u) => u !== url));

  const tile = single ? 'h-28 w-28 rounded-full' : 'h-24 w-24 rounded-xl';

  return (
    <div className={className}>
      {label && (
        <span className="mb-1 block text-xs font-semibold uppercase tracking-wide text-slate-500">{label}</span>
      )}
      <div className={`flex flex-wrap gap-3 ${single ? '' : ''}`}>
        {value.map((url) => (
          <div key={url} className={`group relative overflow-hidden border border-slate-200 bg-slate-50 ${tile}`}>
            <img src={url} alt="" className="h-full w-full object-cover" />
            <button
              type="button"
              onClick={() => remove(url)}
              className="absolute right-1 top-1 flex h-6 w-6 items-center justify-center rounded-full bg-slate-900/70 text-sm font-bold text-white opacity-0 transition group-hover:opacity-100"
              aria-label="Удалить изображение"
            >
              ×
            </button>
          </div>
        ))}

        {value.length < limit && (
          <button
            type="button"
            onClick={pick}
            disabled={uploading}
            className={`flex flex-col items-center justify-center gap-1 border-2 border-dashed border-slate-300 bg-white text-slate-400 transition hover:border-brand-400 hover:text-brand-500 disabled:opacity-60 ${tile}`}
          >
            {uploading ? (
              <Spinner className="h-5 w-5" />
            ) : (
              <>
                <span className="text-2xl leading-none">+</span>
                <span className="text-xs font-medium">Загрузить</span>
              </>
            )}
          </button>
        )}
      </div>

      <input
        ref={inputRef}
        type="file"
        accept="image/*"
        multiple={!single}
        className="hidden"
        onChange={(e) => void handleFiles(e.target.files)}
      />

      {error ? (
        <p className="mt-2 text-xs text-red-600">{error}</p>
      ) : (
        hint && <p className="mt-2 text-xs text-slate-400">{hint}</p>
      )}
    </div>
  );
}
