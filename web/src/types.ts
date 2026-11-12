export type UserRole = 'user' | 'guide' | 'moderator' | 'admin';
export type VisibilityScope = 'public' | 'friends' | 'private';
export type EventLevel = 'beginner' | 'medium' | 'pro';
export type EventVisibility = 'private' | 'friends' | 'public';
export type EventAccess = 'open' | 'invite';
export type EventStatus = 'draft' | 'scheduled' | 'on_water' | 'completed' | 'cancelled';
export type ParticipantStatus = 'going' | 'maybe' | 'not_going';
export type TrackStatus = 'draft' | 'private' | 'moderation' | 'published' | 'hidden';
export type TrackDifficulty = 'easy' | 'medium' | 'hard';
export type RouteDifficulty = 'easy' | 'medium' | 'hard';

export interface RouteGeoPoint {
  lat: number;
  lng: number;
}

export interface RouteView {
  id: string;
  name: string;
  description: string | null;
  waterbodyId: string;
  waterbody: { id: string; name: string; region: string | null } | null;
  authorId: string;
  author: { id: string; name: string; avatarUrl: string | null } | null;
  distanceMeters: number;
  difficulty: RouteDifficulty;
  maxSpeedKph: number;
  expectedDurationMinutes: number | null;
  published: boolean;
  points: RouteGeoPoint[];
  startPoint: RouteGeoPoint | null;
  finishPoint: RouteGeoPoint | null;
  createdAt: string;
  updatedAt: string;
}

export interface CreateRouteInput {
  name: string;
  description?: string;
  waterbodyId: string;
  difficulty?: RouteDifficulty;
  maxSpeedKph?: number;
  expectedDurationMinutes?: number | null;
  published?: boolean;
  points: RouteGeoPoint[];
}
export type ListingStatus = 'draft' | 'moderation' | 'active' | 'completed' | 'sold' | 'removed';
export type ListingCategory = 'boards' | 'paddles' | 'wetsuits' | 'accessories' | 'services' | 'other';
export type ListingLeadStatus = 'new' | 'accepted' | 'rejected' | 'closed';
export type NotificationType =
  | 'message'
  | 'friend_request'
  | 'friend_accepted'
  | 'achievement'
  | 'event_invite'
  | 'event_joined'
  | 'event_reminder'
  | 'marketplace'
  | 'news'
  | 'weather'
  | 'system';
export type NotificationCategory =
  | 'events'
  | 'messages'
  | 'achievements'
  | 'community'
  | 'news'
  | 'marketplace'
  | 'weather';
export type MessageType = 'text' | 'photo' | 'location';
export type MessageStatus = 'sent' | 'delivered' | 'read' | 'error' | 'deleted';
export type ConversationType = 'direct' | 'group' | 'event' | 'deal';

export interface User {
  id: string;
  email: string;
  name: string;
  phone: string | null;
  city: string | null;
  region: string | null;
  country: string | null;
  avatarUrl: string | null;
  bio: string | null;
  homeWaterBodyId: string | null;
  homeWaterBody?: WaterBody | null;
  role: UserRole;
  isBanned?: boolean;
  xp: number;
  isEmailVerified: boolean;
  locale?: 'ru' | 'en';
  profileVisibility?: VisibilityScope;
  activityVisibility?: VisibilityScope;
  geoVisibility?: VisibilityScope;
  showOnline?: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface ProfileStats {
  friends: number;
  eventsOrganized: number;
  eventsAttended: number;
  tracksPublished: number;
  listingsActive: number;
  ratingAverage: number;
  reviewsCount: number;
}

export interface UserProfileView {
  user: User;
  stats: ProfileStats | null;
  canView: boolean;
  blocked: boolean;
  isFriend: boolean;
  isSelf: boolean;
}

export interface AuthResult {
  accessToken: string;
  refreshToken: string;
  user: User;
}

export interface MessageResult {
  ok: boolean;
  devToken?: string;
}

export interface WaterBody {
  id: string;
  name: string;
  description: string | null;
  region: string | null;
  active: boolean;
  createdAt: string;
  updatedAt: string;
  latitude?: number | null;
  longitude?: number | null;
}

export interface AdminWaterBody extends WaterBody {
  latitude: number | null;
  longitude: number | null;
}

export interface EventParticipant {
  id: string;
  eventId: string;
  userId: string;
  user: User;
  status: ParticipantStatus;
  joinedAt: string;
}

export interface Event {
  id: string;
  organizerId: string;
  organizer: User;
  title: string;
  description: string | null;
  photos: string[];
  waterBodyId: string | null;
  waterBody: WaterBody | null;
  /** Маршрут: водоём, длительность и дистанция заплыва берутся из него. */
  trackId: string | null;
  track?: Track | null;
  eventDate: string;
  expectedDurationMinutes: number | null;
  expectedDistanceMeters: number | null;
  level: EventLevel;
  visibility: EventVisibility;
  access: EventAccess;
  maxParticipants: number | null;
  status: EventStatus;
  startLat: number | null;
  startLng: number | null;
  participantCount?: number;
  createdAt: string;
  updatedAt: string;
}

export interface Track {
  id: string;
  userId: string;
  user?: User;
  name: string | null;
  status: TrackStatus;
  difficulty: TrackDifficulty | null;
  waterBodyId: string | null;
  waterBody?: WaterBody | null;
  routeId: string | null;
  route?: RouteView | null;
  distanceMeters: number;
  durationSeconds: number;
  avgSpeedKph: number;
  maxSpeedKph: number;
  elevationGainMeters: number;
  elevationLossMeters: number;
  calories: number;
  startedAt: string;
  endedAt: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface TrackPoint {
  id: string;
  trackId: string;
  lat: number;
  lng: number;
  altitude: number | null;
  speedKph: number | null;
  recordedAt: string;
  createdAt: string;
}

export interface FeedRouteItem {
  id: string;
  name: string | null;
  distance_meters: number;
  durationSeconds: number;
}

export interface FeedEventItem {
  id: string;
  title: string;
  description: string | null;
  eventDate: string;
  startLat: number | null;
  startLng: number | null;
  visibility: EventVisibility | string;
  organizerName: string;
  organizerId: string;
  waterBodyName: string | null;
}

export interface FeedListingItem {
  id: string;
  title: string;
  category: string;
  price: number | null;
  currency: string;
  photos: string[];
  createdAt: string;
}

export interface FeedResponse {
  routes: FeedRouteItem[];
  events: FeedEventItem[];
  listings: FeedListingItem[];
}

export type PostType = 'swim' | 'route' | 'achievement' | 'event' | 'news' | 'waterbody';

export interface Post {
  id: string;
  authorId: string;
  author?: User;
  type: PostType;
  title: string | null;
  body: string | null;
  photos: string[];
  refId: string | null;
  refType: string | null;
  visibility: VisibilityScope;
  likeCount: number;
  commentCount: number;
  shareCount: number;
  createdAt: string;
  updatedAt: string;
  likedByMe: boolean;
  canDelete: boolean;
}

export interface PostListResult {
  items: Post[];
  hasMore: boolean;
}

export interface PostComment {
  id: string;
  postId: string;
  authorId: string;
  author?: User;
  body: string;
  createdAt: string;
}

export type ChannelRole = 'member' | 'moderator' | 'owner';

export interface Channel {
  id: string;
  name: string;
  slug: string;
  description: string | null;
  photoUrl: string | null;
  ownerId: string;
  owner?: User;
  isPublic: boolean;
  subscriberCount: number;
  isMember: boolean;
  myRole: ChannelRole | null;
  createdAt: string;
  updatedAt: string;
}

export interface ChannelMember {
  id: string;
  channelId: string;
  userId: string;
  user: User;
  role: ChannelRole;
  createdAt: string;
}

export interface ChannelPost {
  id: string;
  channelId: string;
  authorId: string;
  author?: User;
  title: string | null;
  body: string | null;
  photos: string[];
  isPinned: boolean;
  likeCount: number;
  commentCount: number;
  createdAt: string;
  updatedAt: string;
  likedByMe: boolean;
  canDelete: boolean;
  canPin: boolean;
}

export interface ChannelPostListResult {
  items: ChannelPost[];
  hasMore: boolean;
}

export interface ChannelPostComment {
  id: string;
  postId: string;
  authorId: string;
  author?: User;
  body: string;
  createdAt: string;
}

export interface News {
  id: string;
  title: string;
  body: string;
  coverUrl: string | null;
  authorId: string;
  author?: User;
  isPublished: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface SearchWaterBody {
  id: string;
  name: string;
  region: string | null;
  latitude: number;
  longitude: number;
}
export interface SearchUser {
  id: string;
  name: string;
  city: string | null;
  avatarUrl: string | null;
}
export interface SearchEvent {
  id: string;
  title: string;
  eventDate: string;
  startLat: number | null;
  startLng: number | null;
  visibility: string;
  organizerName: string;
  organizerId: string;
}
export interface SearchTrack {
  id: string;
  name: string | null;
  distanceMeters: number;
  avgSpeedKph: number;
  difficulty: TrackDifficulty | null;
  startedAt: string;
  userName: string;
}
export interface SearchChannel {
  id: string;
  name: string;
  slug: string;
  description: string | null;
  photoUrl: string | null;
  subscriberCount: number;
}
export interface SearchNews {
  id: string;
  title: string;
  coverUrl: string | null;
  createdAt: string;
}
export interface SearchResponse {
  waterbodies: SearchWaterBody[];
  users: SearchUser[];
  events: SearchEvent[];
  tracks: SearchTrack[];
  listings: FeedListingItem[];
  channels: SearchChannel[];
  news: SearchNews[];
}

export interface Listing {
  id: string;
  sellerId: string;
  seller: User;
  category: string;
  title: string;
  description: string | null;
  price: number | null;
  currency: string;
  photos: string[];
  latitude: number | null;
  longitude: number | null;
  city: string | null;
  status: ListingStatus;
  moderationComment?: string | null;
  publishedAt?: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface MarketplaceReview {
  id: string;
  listingId: string;
  authorId: string;
  targetId: string;
  rating: number;
  comment: string | null;
  createdAt: string;
  author?: { id: string; name: string; avatarUrl: string | null };
}

export interface ListingLead {
  id: string;
  listingId: string;
  listing: Listing;
  buyerId: string;
  message: string | null;
  status: ListingLeadStatus;
  createdAt: string;
}

export interface FriendRequest {
  id: string;
  requesterId: string;
  requester: User;
  addresseeId: string;
  addressee: User;
  status: 'pending' | 'accepted' | 'rejected';
  createdAt: string;
  updatedAt: string;
}

export interface ConversationParticipant {
  id: string;
  conversationId: string;
  userId: string;
  user: User;
  lastReadAt: string | null;
  createdAt: string;
}

export interface Message {
  id: string;
  conversationId: string;
  senderId: string;
  sender: User;
  type: MessageType;
  content: string | null;
  nonce: string | null;
  latitude: number | null;
  longitude: number | null;
  replyToId: string | null;
  replyTo: Message | null;
  status: MessageStatus;
  createdAt: string;
}

export interface Conversation {
  id: string;
  type: ConversationType;
  title: string | null;
  eventId: string | null;
  lastMessageAt: string | null;
  participants: ConversationParticipant[];
  createdAt: string;
  updatedAt: string;
}

export interface ConversationSummary {
  id: string;
  type: ConversationType;
  title: string | null;
  eventId: string | null;
  lastMessageAt: string | null;
  lastMessage: Message | null;
  unreadCount: number;
  participants: ConversationParticipant[];
}

export interface Notification {
  id: string;
  userId: string;
  type: NotificationType;
  title: string;
  body: string | null;
  data: Record<string, unknown> | null;
  isRead: boolean;
  createdAt: string;
}

export interface NotificationSetting {
  category: NotificationCategory;
  inApp: boolean;
  push: boolean;
}

export interface LevelInfo {
  level: number;
  xp: number;
  currentLevelXp: number;
  nextLevelXp: number;
  progress: number;
}

export type GearCategory =
  | 'board'
  | 'paddle'
  | 'wetsuit'
  | 'vest'
  | 'leash'
  | 'pump'
  | 'drybag'
  | 'other';

export interface GearItem {
  id: string;
  userId: string;
  category: GearCategory;
  brand: string | null;
  model: string | null;
  lengthCm: number | null;
  widthCm: number | null;
  volumeL: number | null;
  weightKg: number | null;
  material: string | null;
  notes: string | null;
  createdAt: string;
  updatedAt: string;
}

export type RatingScope = 'all' | 'friends' | 'city' | 'region' | 'country' | 'season';

export interface RatingEntry {
  id: string;
  name: string;
  avatarUrl: string | null;
  city: string | null;
  region: string | null;
  country: string | null;
  xp: number;
  level: number;
  rank: number;
}

export interface RatingResponse {
  scope: RatingScope;
  seasonYear?: number;
  me: RatingEntry | null;
  entries: RatingEntry[];
}

export interface PointLog {
  id: string;
  userId: string;
  action: string;
  points: number;
  refType: string | null;
  refId: string | null;
  createdAt: string;
}

export interface AchievementDef {
  code: string;
  title: string;
  description: string;
  icon: string | null;
  xp: number;
}

export interface Achievement extends AchievementDef {
  unlocked: boolean;
  unlockedAt: string | null;
}

export interface AdminStats {
  users: { total: number; banned: number; admins: number; moderators: number };
  events: { total: number; scheduled: number; onWater: number; completed: number; cancelled: number };
  listings: { total: number; active: number; completed: number; removed: number };
  tracks: { total: number; published: number; hidden: number; moderation: number };
  waterbodies: { total: number; active: number };
  leads: { total: number; new: number };
  recentUsers: User[];
}

export interface AdminList<T> {
  items: T[];
  total: number;
}

export interface ChatStatusEvent {
  conversationId: string;
  messageId?: string;
  status: MessageStatus;
  userId?: string;
}
export interface ChatTypingEvent {
  conversationId: string;
  userId: string;
  isTyping: boolean;
}
export interface ChatNewEvent {
  message: Message;
  conversationId: string;
}

export type FeedEventItemFields = keyof FeedEventItem;

export type WeatherSafety = 'normal' | 'caution' | 'danger';

export interface WeatherCurrent {
  time: string;
  temperatureC: number | null;
  windSpeedKph: number | null;
  windDirectionDeg: number | null;
  windGustsKph: number | null;
  precipitationMm: number | null;
  weatherCode: number | null;
  waveHeightM: number | null;
}

export interface WeatherHourly {
  time: string;
  temperatureC: number | null;
  windSpeedKph: number | null;
  windGustsKph: number | null;
  precipitationProbability: number | null;
  weatherCode: number | null;
  waveHeightM: number | null;
}

export interface WeatherForecast {
  latitude: number;
  longitude: number;
  timezone: string;
  fetchedAt: string;
  provider: 'open-meteo';
  safety: WeatherSafety;
  safetyReasons: string[];
  current: WeatherCurrent;
  hourly: WeatherHourly[];
}