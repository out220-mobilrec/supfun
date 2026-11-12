import type {
  ConversationType,
  EventLevel,
  EventStatus,
  ListingCategory,
  ListingLeadStatus,
  ListingStatus,
  MessageType,
  NotificationCategory,
  NotificationType,
  ParticipantStatus,
  PostType,
  TrackDifficulty,
  TrackStatus,
  UserRole,
} from '../types';

function isEn(): boolean {
  try {
    return localStorage.getItem('sf_locale') === 'en';
  } catch {
    return false;
  }
}
function pick<T extends string>(en: boolean, ruVal: T, enVal: T): T {
  return en ? enVal : ruVal;
}

export function roleLabel(role: UserRole): string {
  const en = isEn();
  switch (role) {
    case 'admin': return pick(en, 'Админ', 'Admin');
    case 'moderator': return pick(en, 'Модератор', 'Moderator');
    case 'guide': return pick(en, 'Гид', 'Guide');
    default: return pick(en, 'Пользователь', 'User');
  }
}

export function eventStatusLabel(status: EventStatus): string {
  const en = isEn();
  switch (status) {
    case 'draft': return pick(en, 'Черновик', 'Draft');
    case 'scheduled': return pick(en, 'Запланирован', 'Scheduled');
    case 'on_water': return pick(en, 'На воде', 'On water');
    case 'completed': return pick(en, 'Завершён', 'Completed');
    case 'cancelled': return pick(en, 'Отменён', 'Cancelled');
    default: return status;
  }
}

export function eventLevelLabel(level: EventLevel): string {
  const en = isEn();
  switch (level) {
    case 'beginner': return pick(en, 'Новичок', 'Beginner');
    case 'medium': return pick(en, 'Средний', 'Medium');
    case 'pro': return pick(en, 'Про', 'Pro');
    default: return level;
  }
}

export function trackStatusLabel(status: TrackStatus): string {
  const en = isEn();
  switch (status) {
    case 'draft': return pick(en, 'Черновик', 'Draft');
    case 'private': return pick(en, 'Личный', 'Private');
    case 'moderation': return pick(en, 'На модерации', 'In moderation');
    case 'published': return pick(en, 'Опубликован', 'Published');
    case 'hidden': return pick(en, 'Скрыт', 'Hidden');
    default: return status;
  }
}

export function trackDifficultyLabel(difficulty: TrackDifficulty | null): string {
  const en = isEn();
  switch (difficulty) {
    case 'easy': return pick(en, 'Лёгкий', 'Easy');
    case 'medium': return pick(en, 'Средний', 'Medium');
    case 'hard': return pick(en, 'Сложный', 'Hard');
    default: return '—';
  }
}

export function listingStatusLabel(status: ListingStatus): string {
  const en = isEn();
  switch (status) {
    case 'draft': return pick(en, 'Черновик', 'Draft');
    case 'moderation': return pick(en, 'На модерации', 'In moderation');
    case 'active': return pick(en, 'Активно', 'Active');
    case 'completed': return pick(en, 'Завершено', 'Completed');
    case 'sold': return pick(en, 'Продано', 'Sold');
    case 'removed': return pick(en, 'Снято', 'Removed');
    default: return status;
  }
}

export function leadStatusLabel(status: ListingLeadStatus): string {
  const en = isEn();
  switch (status) {
    case 'new': return pick(en, 'Новая', 'New');
    case 'accepted': return pick(en, 'Принята', 'Accepted');
    case 'rejected': return pick(en, 'Отклонена', 'Rejected');
    case 'closed': return pick(en, 'Закрыта', 'Closed');
    default: return status;
  }
}

export function participantStatusLabel(status: ParticipantStatus): string {
  const en = isEn();
  switch (status) {
    case 'going': return pick(en, 'Иду', 'Going');
    case 'maybe': return pick(en, 'Может быть', 'Maybe');
    case 'not_going': return pick(en, 'Не пойду', 'Not going');
    default: return status;
  }
}

export function conversationTypeLabel(type: ConversationType): string {
  const en = isEn();
  switch (type) {
    case 'direct': return pick(en, 'Личный', 'Direct');
    case 'group': return pick(en, 'Группа', 'Group');
    case 'event': return pick(en, 'Заплыв', 'Event');
    case 'deal': return pick(en, 'Сделка', 'Deal');
    default: return type;
  }
}

export function notificationTypeLabel(type: NotificationType): string {
  const en = isEn();
  switch (type) {
    case 'message': return pick(en, 'Сообщение', 'Message');
    case 'friend_request': return pick(en, 'Заявка в друзья', 'Friend request');
    case 'friend_accepted': return pick(en, 'Новый друг', 'New friend');
    case 'achievement': return pick(en, 'Достижение', 'Achievement');
    case 'event_invite': return pick(en, 'Приглашение', 'Invitation');
    case 'event_joined': return pick(en, 'Заплыв', 'Event');
    case 'event_reminder': return pick(en, 'Напоминание', 'Reminder');
    case 'marketplace': return pick(en, 'Маркетплейс', 'Marketplace');
    case 'news': return pick(en, 'Новости', 'News');
    case 'weather': return pick(en, 'Погода', 'Weather');
    case 'system': return pick(en, 'Система', 'System');
    default: return type;
  }
}

export function notificationCategoryLabel(category: NotificationCategory): string {
  const en = isEn();
  switch (category) {
    case 'events': return pick(en, 'Заплывы', 'Events');
    case 'messages': return pick(en, 'Сообщения', 'Messages');
    case 'achievements': return pick(en, 'Достижения', 'Achievements');
    case 'community': return pick(en, 'Сообщество', 'Community');
    case 'news': return pick(en, 'Новости', 'News');
    case 'marketplace': return pick(en, 'Маркетплейс', 'Marketplace');
    case 'weather': return pick(en, 'Погода', 'Weather');
    default: return category;
  }
}

export function messageTypeLabel(type: MessageType): string {
  const en = isEn();
  switch (type) {
    case 'text': return pick(en, 'Текст', 'Text');
    case 'photo': return pick(en, 'Фото', 'Photo');
    case 'location': return pick(en, 'Геолокация', 'Location');
    default: return type;
  }
}

export function postTypeLabel(type: PostType): string {
  const en = isEn();
  switch (type) {
    case 'swim': return pick(en, 'Заплыв', 'Swim');
    case 'route': return pick(en, 'Маршрут', 'Route');
    case 'achievement': return pick(en, 'Достижение', 'Achievement');
    case 'event': return pick(en, 'Заплыв', 'Event');
    case 'news': return pick(en, 'Новость', 'News');
    case 'waterbody': return pick(en, 'Водоём', 'Waterbody');
    default: return type;
  }
}

export function listingCategoryLabel(category: ListingCategory | string): string {
  const en = isEn();
  const map: Record<string, [string, string]> = {
    boards: ['Доски', 'Boards'],
    paddles: ['Вёсла', 'Paddles'],
    wetsuits: ['Гидрокостюмы', 'Wetsuits'],
    accessories: ['Аксессуары', 'Accessories'],
    services: ['Услуги', 'Services'],
    other: ['Другое', 'Other'],
  };
  const v = map[category];
  return v ? (en ? v[1] : v[0]) : category;
}