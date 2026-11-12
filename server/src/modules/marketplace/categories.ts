export const LISTING_CATEGORIES = [
  'boards',
  'paddles',
  'wetsuits',
  'accessories',
  'services',
  'other',
] as const;

export type ListingCategory = (typeof LISTING_CATEGORIES)[number];