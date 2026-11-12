export type {
  UserRole,
  EventLevel,
  EventVisibility,
  EventAccess,
  EventStatus,
  ParticipantStatus,
  TrackStatus,
  TrackDifficulty,
  ListingCategory,
  ListingStatus,
  ListingLeadStatus,
  NotificationType,
  MessageType,
  MessageStatus,
  ConversationType,
  PostType,
  NotificationCategory,
} from '../types';

import type {
  UserRole,
  EventLevel,
  EventVisibility,
  EventAccess,
  EventStatus,
  ParticipantStatus,
  TrackStatus,
  TrackDifficulty,
  ListingCategory,
  ListingStatus,
  ListingLeadStatus,
  NotificationType,
  MessageType,
  ConversationType,
  PostType,
  NotificationCategory,
} from '../types';

export const NOTIFICATION_CATEGORIES: NotificationCategory[] = [
  'events',
  'messages',
  'achievements',
  'community',
  'news',
  'marketplace',
  'weather',
];

export const POST_TYPES: PostType[] = [
  'swim',
  'route',
  'achievement',
  'event',
  'news',
  'waterbody',
];

export const USER_ROLES: UserRole[] = ['user', 'guide', 'moderator', 'admin'];
export const EVENT_LEVELS: EventLevel[] = ['beginner', 'medium', 'pro'];
export const EVENT_VISIBILITIES: EventVisibility[] = ['public', 'friends', 'private'];
export const EVENT_ACCESSES: EventAccess[] = ['open', 'invite'];
export const PARTICIPANT_STATUSES: ParticipantStatus[] = ['going', 'maybe', 'not_going'];
export const TRACK_STATUSES: TrackStatus[] = ['private', 'moderation', 'published', 'hidden'];
export const TRACK_DIFFICULTIES: TrackDifficulty[] = ['easy', 'medium', 'hard'];
export const LISTING_CATEGORIES: ListingCategory[] = [
  'boards',
  'paddles',
  'wetsuits',
  'accessories',
  'services',
  'other',
];
export const LISTING_STATUSES: ListingStatus[] = ['draft', 'moderation', 'active', 'completed', 'sold', 'removed'];
export const LEAD_STATUSES: ListingLeadStatus[] = ['new', 'accepted', 'rejected', 'closed'];
export const EVENT_STATUSES: EventStatus[] = ['scheduled', 'on_water', 'completed', 'cancelled'];
export const NOTIFICATION_TYPES: NotificationType[] = [
  'message',
  'friend_request',
  'friend_accepted',
  'achievement',
  'event_invite',
  'event_joined',
  'event_reminder',
  'system',
];
export const MESSAGE_TYPES: MessageType[] = ['text', 'photo', 'location'];
export const CONVERSATION_TYPES: ConversationType[] = ['direct', 'group', 'event', 'deal'];