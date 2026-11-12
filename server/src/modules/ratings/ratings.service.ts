import { Injectable } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { FriendsService } from '../friends/friends.service';
import { BlocksService } from '../blocks/blocks.service';

export type RatingScope = 'friends' | 'city' | 'region' | 'country' | 'all' | 'season';

export interface RatingEntry {
  id: string;
  name: string;
  avatarUrl: string | null;
  city: string | null;
  region: string | null;
  country: string | null;
  xp: number;
  level: number;
}

export interface RatingResponse {
  scope: RatingScope;
  seasonYear?: number;
  me: (RatingEntry & { rank: number }) | null;
  entries: Array<RatingEntry & { rank: number }>;
}

@Injectable()
export class RatingsService {
  constructor(
    @InjectDataSource()
    private readonly dataSource: DataSource,
    private readonly friends: FriendsService,
    private readonly blocks: BlocksService,
  ) {}

  async leaderboard(
    meId: string,
    scope: RatingScope = 'all',
    limit = 50,
  ): Promise<RatingResponse> {
    const n = Math.min(Math.max(limit, 1), 100);
    const hidden = await this.blocks.hiddenIds(meId);
    const hiddenGuarded = hidden.length > 0;

    let where = 'u.is_banned = false';
    const params: unknown[] = [];

    if (scope === 'friends') {
      const friendIds = await this.friends.friendIds(meId);
      if (friendIds.length === 0) {
        return { scope, me: null, entries: [] };
      }
      params.push(friendIds);
      where += ` AND u.id = ANY($${params.length}::uuid[])`;
    } else if (scope === 'city') {
      params.push(meId);
      where += ` AND u.city IS NOT NULL AND u.city = (SELECT city FROM users WHERE id = $${params.length})`;
    } else if (scope === 'region') {
      params.push(meId);
      where += ` AND u.region IS NOT NULL AND u.region = (SELECT region FROM users WHERE id = $${params.length})`;
    } else if (scope === 'country') {
      params.push(meId);
      where += ` AND u.country IS NOT NULL AND u.country = (SELECT country FROM users WHERE id = $${params.length})`;
    }

    let scoreExpr = 'u.xp';
    let seasonYear: number | undefined;
    if (scope === 'season') {
      seasonYear = new Date().getUTCFullYear();
      params.push(seasonYear);
      scoreExpr = `COALESCE((SELECT SUM(pl.points) FROM point_logs pl WHERE pl.user_id = u.id AND EXTRACT(YEAR FROM pl.created_at) = $${params.length}), 0)`;
    }

    if (hiddenGuarded) {
      params.push(hidden);
      where += ` AND u.id NOT IN (SELECT unnest($${params.length}::uuid[]))`;
    }

    params.push(n);
    const rows: Array<RatingEntry & { rank: number }> =
      await this.dataSource.query(
        `SELECT u.id, u.name, u.avatar_url AS "avatarUrl", u.city, u.region, u.country,
                ${scoreExpr} AS xp
         FROM users u
         WHERE ${where}
         ORDER BY xp DESC, u.name ASC
         LIMIT $${params.length}`,
        params,
      );

    const entries = rows.map((r, i) => ({
      ...r,
      xp: Number(r.xp ?? 0),
      level: this.levelOf(Number(r.xp ?? 0)),
      rank: i + 1,
    }));

    const meRow = entries.find((e) => e.id === meId) ?? null;
    return { scope, seasonYear, me: meRow, entries };
  }

  private levelOf(xp: number): number {
    let level = 1;
    let remaining = xp;
    let need = 200;
    while (remaining >= need) {
      remaining -= need;
      level += 1;
      need = Math.round(need * 1.4);
    }
    return level;
  }
}