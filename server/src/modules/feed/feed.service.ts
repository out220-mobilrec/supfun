import { Injectable, BadRequestException } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { BlocksService } from '../blocks/blocks.service';

const NO_MATCH = '00000000-0000-0000-0000-000000000000';

export interface FeedResponse {
  routes: unknown[];
  events: unknown[];
  listings: unknown[];
}

export interface SearchResponse {
  waterbodies: unknown[];
  users: unknown[];
  events: unknown[];
  tracks: unknown[];
  listings: unknown[];
  channels: unknown[];
  news: unknown[];
}

@Injectable()
export class FeedService {
  constructor(
    @InjectDataSource()
    private readonly dataSource: DataSource,
    private readonly blocks: BlocksService,
  ) {}

  async feed(limit = 10, viewerId?: string): Promise<FeedResponse> {
    const n = Math.min(Math.max(limit, 1), 50);
    const hidden = viewerId ? await this.blocks.hiddenIds(viewerId) : [];
    const hide = hidden.length > 0;
    const hiddenList = hide ? hidden : [NO_MATCH];
    const [routes, events, listings] = await Promise.all([
      this.dataSource.query(
        `SELECT t.id, t.name, t.distance_meters, t.duration_seconds,
                t.avg_speed_kph AS "avgSpeedKph", t.started_at AS "startedAt",
                t.difficulty, u.name AS "userName", u.id AS "userId"
         FROM tracks t
         JOIN users u ON u.id = t.user_id
         WHERE t.status = 'published' AND ($3 = false OR t.user_id NOT IN (SELECT unnest($2::uuid[])))
         ORDER BY t.created_at DESC
         LIMIT $1`,
        [n, hiddenList, hide],
      ),
      this.dataSource.query(
        `SELECT e.id, e.title, e.description, e.event_date AS "eventDate",
                e.start_lat AS "startLat", e.start_lng AS "startLng",
                e.visibility, u.name AS "organizerName", u.id AS "organizerId",
                wb.name AS "waterBodyName"
         FROM events e
         JOIN users u ON u.id = e.organizer_id
         LEFT JOIN waterbodies wb ON wb.id = e.waterbody_id
         WHERE e.status = 'scheduled' AND ($3 = false OR e.organizer_id NOT IN (SELECT unnest($2::uuid[])))
         ORDER BY e.event_date ASC
         LIMIT $1`,
        [n, hiddenList, hide],
      ),
      this.dataSource.query(
        `SELECT id, title, category, price, currency, photos, city,
                created_at AS "createdAt"
         FROM listings
         WHERE status = 'active' AND ($3 = false OR seller_id NOT IN (SELECT unnest($2::uuid[])))
         ORDER BY created_at DESC
         LIMIT $1`,
        [n, hiddenList, hide],
      ),
    ]);
    return { routes, events, listings };
  }

  async search(
    q: string | undefined,
    limit = 5,
    viewerId?: string,
  ): Promise<SearchResponse> {
    const needle = (q ?? '').trim();
    if (!needle) {
      throw new BadRequestException("Search query 'q' is required");
    }
    const n = Math.min(Math.max(limit, 1), 20);
    const like = `%${needle}%`;
    const hidden = viewerId ? await this.blocks.hiddenIds(viewerId) : [];
    const hide = hidden.length > 0;
    const hiddenList = hide ? hidden : [NO_MATCH];
    const [waterbodies, users, events, tracks, listings, channels, news] = await Promise.all([
      this.dataSource.query(
        `SELECT id, name, region,
                ST_Y(location) AS "latitude", ST_X(location) AS "longitude"
         FROM waterbodies
         WHERE name ILIKE $1 OR region ILIKE $1
         ORDER BY name
         LIMIT $2`,
        [like, n],
      ),
      this.dataSource.query(
        `SELECT id, name, city, avatar_url AS "avatarUrl"
         FROM users
         WHERE (name ILIKE $1 OR city ILIKE $1)
           AND ($4 = false OR id NOT IN (SELECT unnest($3::uuid[])))
         ORDER BY name
         LIMIT $2`,
        [like, n, hiddenList, hide],
      ),
      this.dataSource.query(
        `SELECT e.id, e.title, e.event_date AS "eventDate", e.start_lat AS "startLat",
                e.start_lng AS "startLng", e.visibility,
                u.name AS "organizerName", u.id AS "organizerId"
         FROM events e
         JOIN users u ON u.id = e.organizer_id
         WHERE e.status = 'scheduled' AND (e.title ILIKE $1 OR e.description ILIKE $1)
           AND ($4 = false OR e.organizer_id NOT IN (SELECT unnest($3::uuid[])))
         ORDER BY e.event_date ASC
         LIMIT $2`,
        [like, n, hiddenList, hide],
      ),
      this.dataSource.query(
        `SELECT t.id, t.name, t.distance_meters AS "distanceMeters",
                t.avg_speed_kph AS "avgSpeedKph", t.difficulty, t.started_at AS "startedAt",
                u.name AS "userName"
         FROM tracks t
         JOIN users u ON u.id = t.user_id
         WHERE t.status = 'published' AND t.name ILIKE $1
           AND ($4 = false OR t.user_id NOT IN (SELECT unnest($3::uuid[])))
         ORDER BY t.created_at DESC
         LIMIT $2`,
        [like, n, hiddenList, hide],
      ),
      this.dataSource.query(
        `SELECT id, title, category, price, currency, photos, city,
                created_at AS "createdAt"
         FROM listings
         WHERE status = 'active' AND title ILIKE $1
           AND ($4 = false OR seller_id NOT IN (SELECT unnest($3::uuid[])))
         ORDER BY created_at DESC
         LIMIT $2`,
        [like, n, hiddenList, hide],
      ),
      this.dataSource.query(
        `SELECT c.id, c.name, c.slug, c.description, c.photo_url AS "photoUrl",
                (SELECT COUNT(*)::int FROM channel_members cm WHERE cm.channel_id = c.id) AS "subscriberCount"
         FROM channels c
         WHERE c.is_public = true
           AND (c.name ILIKE $1 OR c.description ILIKE $1 OR c.slug ILIKE $1)
         ORDER BY "subscriberCount" DESC, c.name ASC
         LIMIT $2`,
        [like, n],
      ),
      this.dataSource.query(
        `SELECT id, title, cover_url AS "coverUrl", created_at AS "createdAt"
         FROM news
         WHERE is_published = true AND (title ILIKE $1 OR body ILIKE $1)
         ORDER BY created_at DESC
         LIMIT $2`,
        [like, n],
      ),
    ]);
    return { waterbodies, users, events, tracks, listings, channels, news };
  }
}