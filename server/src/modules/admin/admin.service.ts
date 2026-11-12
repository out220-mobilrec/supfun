import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { ILike, Repository } from 'typeorm';
import { User, UserRole } from '../users/user.entity';
import { Listing, ListingStatus } from '../marketplace/listing.entity';
import { ListingLead, ListingLeadStatus } from '../marketplace/listing-lead.entity';
import { Event, EventStatus } from '../events/event.entity';
import { Track, TrackStatus } from '../tracks/track.entity';
import { WaterBody } from '../waterbodies/waterbody.entity';
import { AdminUpdateEventDto } from './dto/event.dto';
import { EventStatsQueryDto } from './dto/event-stats.dto';

export interface AdminStats {
  users: { total: number; banned: number; admins: number; moderators: number };
  events: { total: number; scheduled: number; onWater: number; completed: number; cancelled: number };
  listings: { total: number; active: number; completed: number; removed: number };
  tracks: { total: number; published: number; hidden: number; moderation: number };
  waterbodies: { total: number; active: number };
  leads: { total: number; new: number };
  recentUsers: User[];
}

/** Сводка по заплывам за период. */
export interface EventStatsSummary {
  totalEvents: number;
  scheduledEvents: number;
  completedEvents: number;
  totalParticipants: number;
  uniqueParticipants: number;
  totalTracks: number;
  totalDistanceMeters: number;
  totalDurationSeconds: number;
  avgDistanceMeters: number;
  avgDurationSeconds: number;
  totalPoints: number;
  totalReviews: number;
  avgRating: number | null;
  topEvents: EventStatRow[];
  eventsByMonth: EventMonthRow[];
}

export interface EventStatRow {
  eventId: string;
  title: string;
  eventDate: string;
  waterBodyName: string | null;
  participantCount: number;
  trackCount: number;
  totalDistanceMeters: number;
  totalDurationSeconds: number;
}

export interface EventMonthRow {
  month: string;
  eventCount: number;
  participantCount: number;
  totalDistanceMeters: number;
}

export interface AdminList<T> {
  items: T[];
  total: number;
}

export interface AdminWaterBody extends WaterBody {
  latitude: number | null;
  longitude: number | null;
}

export interface WaterbodyInput {
  name?: string;
  region?: string | null;
  description?: string | null;
  latitude?: number | null;
  longitude?: number | null;
  active?: boolean;
}

@Injectable()
export class AdminService {
  constructor(
    @InjectRepository(User)
    private readonly usersRepository: Repository<User>,
    @InjectRepository(Event)
    private readonly eventsRepository: Repository<Event>,
    @InjectRepository(Track)
    private readonly tracksRepository: Repository<Track>,
    @InjectRepository(Listing)
    private readonly listingsRepository: Repository<Listing>,
    @InjectRepository(WaterBody)
    private readonly waterbodiesRepository: Repository<WaterBody>,
    @InjectRepository(ListingLead)
    private readonly leadsRepository: Repository<ListingLead>,
  ) {}

  async stats(): Promise<AdminStats> {
    const [
      totalUsers,
      bannedUsers,
      admins,
      moderators,
      totalEvents,
      scheduledEvents,
      onWaterEvents,
      completedEvents,
      cancelledEvents,
      totalListings,
      activeListings,
      completedListings,
      removedListings,
      totalTracks,
      publishedTracks,
      hiddenTracks,
      moderationTracks,
      totalWaterbodies,
      activeWaterbodies,
      totalLeads,
      newLeads,
      recentUsers,
    ] = await Promise.all([
      this.usersRepository.count(),
      this.usersRepository.count({ where: { isBanned: true } }),
      this.usersRepository.count({ where: { role: UserRole.ADMIN } }),
      this.usersRepository.count({ where: { role: UserRole.MODERATOR } }),
      this.eventsRepository.count(),
      this.eventsRepository.count({ where: { status: EventStatus.SCHEDULED } }),
      this.eventsRepository.count({ where: { status: EventStatus.ON_WATER } }),
      this.eventsRepository.count({ where: { status: EventStatus.COMPLETED } }),
      this.eventsRepository.count({ where: { status: EventStatus.CANCELLED } }),
      this.listingsRepository.count(),
      this.listingsRepository.count({ where: { status: ListingStatus.ACTIVE } }),
      this.listingsRepository.count({ where: { status: ListingStatus.COMPLETED } }),
      this.listingsRepository.count({ where: { status: ListingStatus.REMOVED } }),
      this.tracksRepository.count(),
      this.tracksRepository.count({ where: { status: TrackStatus.PUBLISHED } }),
      this.tracksRepository.count({ where: { status: TrackStatus.HIDDEN } }),
      this.tracksRepository.count({ where: { status: TrackStatus.MODERATION } }),
      this.waterbodiesRepository.count(),
      this.waterbodiesRepository.count({ where: { active: true } }),
      this.leadsRepository.count(),
      this.leadsRepository.count({ where: { status: ListingLeadStatus.NEW } }),
      this.usersRepository.find({
        order: { createdAt: 'DESC' },
        take: 10,
      }),
    ]);

    return {
      users: { total: totalUsers, banned: bannedUsers, admins, moderators },
      events: {
        total: totalEvents,
        scheduled: scheduledEvents,
        onWater: onWaterEvents,
        completed: completedEvents,
        cancelled: cancelledEvents,
      },
      listings: {
        total: totalListings,
        active: activeListings,
        completed: completedListings,
        removed: removedListings,
      },
      tracks: {
        total: totalTracks,
        published: publishedTracks,
        hidden: hiddenTracks,
        moderation: moderationTracks,
      },
      waterbodies: { total: totalWaterbodies, active: activeWaterbodies },
      leads: { total: totalLeads, new: newLeads },
      recentUsers,
    };
  }

  /** Сводка по заплывам за период (from/to — опционально, inclusive). */
  async eventStats(from?: string, to?: string): Promise<EventStatsSummary> {
    // Базовый фильтр по event_date
    const conditions: string[] = [];
    const params: unknown[] = [];
    if (from) {
      params.push(from);
      conditions.push(`e.event_date >= $${params.length}::date`);
    }
    if (to) {
      params.push(to);
      conditions.push(`e.event_date < ($${params.length}::date + interval '1 day')`);
    }
    const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

    // 1. Основные агрегаты по событиям
    const eventAgg: { total: number; scheduled: number; completed: number } =
      await this.eventsRepository.query(
        `SELECT COUNT(*)::int AS total,
                COUNT(*) FILTER (WHERE e.status = 'scheduled')::int AS scheduled,
                COUNT(*) FILTER (WHERE e.status = 'completed')::int AS completed
           FROM events e
           ${where}`,
        params,
      ).then((r) => r[0] ?? { total: 0, scheduled: 0, completed: 0 });

    // 2. Участники (всего записей going + уникальные пользователи)
    const participantAgg: { total: number; unique: number } =
      await this.eventsRepository.query(
        `SELECT COUNT(*)::int AS total,
                COUNT(DISTINCT ep.user_id)::int AS "unique"
           FROM event_participants ep
           JOIN events e ON e.id = ep.event_id
           ${where.replace('e.event_date', 'e.event_date')}
           AND ep.status = 'going'`,
        params,
      ).then((r) => r[0] ?? { total: 0, unique: 0 });

    // 3. Треки участников: дистанция, длительность, точки
    const trackAgg: { total: number; distance: number; duration: number; points: number } =
      await this.eventsRepository.query(
        `SELECT COUNT(*)::int AS total,
                COALESCE(SUM(t.distance_meters), 0)::float8 AS distance,
                COALESCE(SUM(t.duration_seconds), 0)::float8 AS duration,
                COALESCE(SUM((SELECT COUNT(*) FROM track_points p WHERE p.track_id = t.id)), 0)::int AS points
           FROM tracks t
           JOIN events e ON e.id = t.event_id
           ${where.replace('e.event_date', 'e.event_date')}`,
        params,
      ).then((r) => r[0] ?? { total: 0, distance: 0, duration: 0, points: 0 });

    // 4. Отзывы о заплывах
    const reviewAgg: { total: number; avg: number | null } =
      await this.eventsRepository.query(
        `SELECT COUNT(*)::int AS total,
                ROUND(AVG(rating)::numeric, 2)::float8 AS avg
           FROM reviews r
           JOIN events e ON e.id = r.target_id
           WHERE r.target_type = 'event'
             ${where ? 'AND ' + where.replace('WHERE ', '') : ''}`,
        params,
      ).then((r) => r[0] ?? { total: 0, avg: null });

    // 5. Топ заплывов по дистанции
    const topEvents: EventStatRow[] = await this.eventsRepository.query(
      `SELECT e.id AS "eventId",
              e.title,
              e.event_date AS "eventDate",
              wb.name AS "waterBodyName",
              (SELECT COUNT(*) FROM event_participants ep WHERE ep.event_id = e.id AND ep.status = 'going')::int AS "participantCount",
              (SELECT COUNT(*) FROM tracks t WHERE t.event_id = e.id)::int AS "trackCount",
              COALESCE((SELECT SUM(t.distance_meters) FROM tracks t WHERE t.event_id = e.id), 0)::float8 AS "totalDistanceMeters",
              COALESCE((SELECT SUM(t.duration_seconds) FROM tracks t WHERE t.event_id = e.id), 0)::float8 AS "totalDurationSeconds"
         FROM events e
         LEFT JOIN waterbodies wb ON wb.id = e.waterbody_id
         ${where}
        ORDER BY (SELECT SUM(t.distance_meters) FROM tracks t WHERE t.event_id = e.id) DESC NULLS LAST
        LIMIT 10`,
      params,
    );

    // 6. Помесячная разбивка (последние 12 месяцев или весь период)
    const eventsByMonth: EventMonthRow[] = await this.eventsRepository.query(
      `SELECT to_char(date_trunc('month', e.event_date), 'YYYY-MM') AS month,
              COUNT(*)::int AS "eventCount",
              COALESCE(SUM((SELECT COUNT(*) FROM event_participants ep WHERE ep.event_id = e.id AND ep.status = 'going')), 0)::int AS "participantCount",
              COALESCE(SUM((SELECT SUM(t.distance_meters) FROM tracks t WHERE t.event_id = e.id)), 0)::float8 AS "totalDistanceMeters"
         FROM events e
         ${where}
        GROUP BY month
        ORDER BY month DESC
        LIMIT 12`,
      params,
    );

    return {
      totalEvents: eventAgg.total,
      scheduledEvents: eventAgg.scheduled,
      completedEvents: eventAgg.completed,
      totalParticipants: participantAgg.total,
      uniqueParticipants: participantAgg.unique,
      totalTracks: trackAgg.total,
      totalDistanceMeters: trackAgg.distance,
      totalDurationSeconds: trackAgg.duration,
      avgDistanceMeters: eventAgg.total > 0 ? trackAgg.distance / eventAgg.total : 0,
      avgDurationSeconds: eventAgg.total > 0 ? trackAgg.duration / eventAgg.total : 0,
      totalPoints: trackAgg.points,
      totalReviews: reviewAgg.total,
      avgRating: reviewAgg.avg,
      topEvents,
      eventsByMonth,
    };
  }

  // ---------- users ----------

  async listUsers(
    query?: string,
    role?: string,
    limit = 50,
    offset = 0,
  ): Promise<AdminList<User>> {
    const where: any[] = [];
    if (query) {
      where.push({ name: ILike(`%${query}%`) }, { email: ILike(`%${query}%`) });
    }
    const filtered = role
      ? (where.length ? where.map((w) => ({ ...w, role })) : [{ role }])
      : where;

    const [items, total] = await this.usersRepository.findAndCount({
      where: filtered.length ? filtered : {},
      order: { createdAt: 'DESC' },
      take: limit,
      skip: offset,
    });
    return { items, total };
  }

  async setRole(id: string, role: UserRole): Promise<User> {
    return this.updateUser(id, { role });
  }

  async ban(id: string): Promise<User> {
    return this.updateUser(id, { isBanned: true });
  }

  async unban(id: string): Promise<User> {
    return this.updateUser(id, { isBanned: false });
  }

  private async updateUser(id: string, data: Partial<User>): Promise<User> {
    const user = await this.usersRepository.findOne({ where: { id } });
    if (!user) {
      throw new NotFoundException(`User ${id} not found`);
    }
    Object.assign(user, data);
    return this.usersRepository.save(user);
  }

  // ---------- listings ----------

  async listListings(
    status?: string,
    query?: string,
    limit = 50,
    offset = 0,
  ): Promise<AdminList<Listing>> {
    const where: any = {};
    if (status) where.status = status;
    if (query) where.title = ILike(`%${query}%`);
    const [items, total] = await this.listingsRepository.findAndCount({
      where,
      relations: { seller: true },
      order: { createdAt: 'DESC' },
      take: limit,
      skip: offset,
    });
    return { items, total };
  }

  async setListingStatus(id: string, status: ListingStatus): Promise<Listing> {
    const listing = await this.listingsRepository.findOne({ where: { id } });
    if (!listing) {
      throw new NotFoundException(`Listing ${id} not found`);
    }
    listing.status = status;
    return this.listingsRepository.save(listing);
  }

  // ---------- events ----------

  async listEvents(
    status?: string,
    query?: string,
    limit = 50,
    offset = 0,
  ): Promise<AdminList<Event>> {
    const qb = this.eventsRepository
      .createQueryBuilder('event')
      .leftJoinAndSelect('event.organizer', 'organizer')
      .leftJoinAndSelect('event.waterBody', 'waterBody');

    if (status) {
      qb.andWhere('event.status = :status', { status });
    }
    if (query) {
      qb.andWhere('event.title ILIKE :q', { q: `%${query}%` });
    }
    const total = await qb.getCount();
    const items = await qb
      .orderBy('event.eventDate', 'DESC')
      .take(limit)
      .skip(offset)
      .getMany();

    if (items.length > 0) {
      const ids = items.map((e) => e.id);
      const rows: { event_id: string; cnt: string }[] =
        await this.eventsRepository.query(
          `SELECT event_id, COUNT(*)::int AS cnt
           FROM event_participants
           WHERE event_id = ANY($1) AND status = 'going'
           GROUP BY event_id`,
          [ids],
        );
      const counts = new Map(rows.map((r) => [r.event_id, Number(r.cnt)]));
      items.forEach((e) => {
        (e as Event & { participantCount: number }).participantCount =
          counts.get(e.id) ?? 0;
      });
    }
    return { items, total };
  }

  async setEventStatus(id: string, status: EventStatus): Promise<Event> {
    const event = await this.eventsRepository.findOne({ where: { id } });
    if (!event) {
      throw new NotFoundException(`Event ${id} not found`);
    }
    event.status = status;
    const saved = await this.eventsRepository.save(event);
    return this.eventsRepository.findOne({
      where: { id: saved.id },
      relations: { organizer: true, waterBody: true },
    }) as Promise<Event>;
  }

  async updateEvent(id: string, dto: AdminUpdateEventDto): Promise<Event> {
    const event = await this.eventsRepository.findOne({ where: { id } });
    if (!event) {
      throw new NotFoundException(`Event ${id} not found`);
    }
    if (dto.title !== undefined) event.title = dto.title;
    if (dto.description !== undefined) event.description = dto.description;
    if (dto.photos !== undefined) event.photos = dto.photos;
    if (dto.waterBodyId !== undefined) {
      if (dto.waterBodyId) {
        const wb = await this.waterbodiesRepository.findOne({
          where: { id: dto.waterBodyId },
        });
        if (!wb) {
          throw new NotFoundException(`WaterBody ${dto.waterBodyId} not found`);
        }
      }
      event.waterBodyId = dto.waterBodyId;
    }
    if (dto.eventDate !== undefined) event.eventDate = new Date(dto.eventDate);
    if (dto.expectedDurationMinutes !== undefined) {
      event.expectedDurationMinutes = dto.expectedDurationMinutes;
    }
    if (dto.expectedDistanceMeters !== undefined) {
      event.expectedDistanceMeters = dto.expectedDistanceMeters;
    }
    if (dto.level !== undefined) event.level = dto.level;
    if (dto.visibility !== undefined) event.visibility = dto.visibility;
    if (dto.access !== undefined) event.access = dto.access;
    if (dto.maxParticipants !== undefined) {
      event.maxParticipants = dto.maxParticipants;
    }
    if (dto.status !== undefined) event.status = dto.status;
    const saved = await this.eventsRepository.save(event);
    if (dto.startPoint !== undefined) {
      if (dto.startPoint) {
        const sp = dto.startPoint;
        await this.eventsRepository
          .createQueryBuilder()
          .update(Event)
          .set({
            startPoint: () =>
              `ST_SetSRID(ST_MakePoint(${sp.lng}, ${sp.lat}), 4326)`,
          })
          .where('id = :id', { id })
          .execute();
      } else {
        await this.eventsRepository
          .createQueryBuilder()
          .update(Event)
          .set({ startPoint: null as unknown as string })
          .where('id = :id', { id })
          .execute();
      }
    }
    const updated = await this.eventsRepository.findOne({
      where: { id: saved.id },
      relations: { organizer: true, waterBody: true },
    });
    if (!updated) {
      throw new NotFoundException(`Event ${id} not found`);
    }
    const row: { cnt: string } | undefined = await this.eventsRepository
      .createQueryBuilder()
      .select('COUNT(*)::int AS cnt', 'cnt')
      .from('event_participants', 'p')
      .where('p.event_id = :id AND p.status = \'going\'', { id })
      .getRawOne<{ cnt: string }>();
    (updated as Event & { participantCount: number }).participantCount =
      Number(row?.cnt ?? 0);
    return updated;
  }

  async deleteEvent(id: string): Promise<{ id: string; deleted: true }> {
    const event = await this.eventsRepository.findOne({ where: { id } });
    if (!event) {
      throw new NotFoundException(`Event ${id} not found`);
    }
    // conversations.event_id ссылается на event без FK-каскада —
    // сначала обнуляем связь, чтобы удаление не упало на ограничении
    await this.eventsRepository.query(
      'UPDATE conversations SET event_id = NULL WHERE event_id = $1',
      [id],
    );
    await this.eventsRepository.remove(event);
    return { id, deleted: true };
  }

  // ---------- tracks ----------

  async listTracks(
    status?: string,
    query?: string,
    limit = 50,
    offset = 0,
  ): Promise<AdminList<Track>> {
    const where: any = {};
    if (status) where.status = status;
    if (query) where.name = ILike(`%${query}%`);
    const [items, total] = await this.tracksRepository.findAndCount({
      where,
      relations: { user: true, waterBody: true },
      order: { createdAt: 'DESC' },
      take: limit,
      skip: offset,
    });
    return { items, total };
  }

  async setTrackStatus(id: string, status: TrackStatus): Promise<Track> {
    const track = await this.tracksRepository.findOne({ where: { id } });
    if (!track) {
      throw new NotFoundException(`Track ${id} not found`);
    }
    track.status = status;
    return this.tracksRepository.save(track);
  }

  // ---------- waterbodies ----------

  async listWaterbodies(
    query?: string,
    active?: boolean,
  ): Promise<AdminWaterBody[]> {
    const qb = this.waterbodiesRepository.createQueryBuilder('wb');
    if (query) {
      qb.andWhere('wb.name ILIKE :q OR wb.region ILIKE :q', {
        q: `%${query}%`,
      });
    }
    if (active !== undefined) {
      qb.andWhere('wb.active = :active', { active });
    }
    const items = await qb.orderBy('wb.name', 'ASC').getMany();
    return this.withLocation(items);
  }

  async getWaterbody(id: string): Promise<AdminWaterBody> {
    const waterBody = await this.waterbodiesRepository.findOne({
      where: { id },
    });
    if (!waterBody) {
      throw new NotFoundException(`WaterBody ${id} not found`);
    }
    const [withLocation] = await this.withLocation([waterBody]);
    return withLocation;
  }

  async createWaterbody(input: WaterbodyInput): Promise<AdminWaterBody> {
    const entity = this.waterbodiesRepository.create({
      name: input.name,
      region: input.region ?? null,
      description: input.description ?? null,
      active: input.active ?? true,
    });
    const saved = await this.waterbodiesRepository.save(entity);
    await this.applyLocation(saved.id, input);
    return this.getWaterbody(saved.id);
  }

  async updateWaterbody(
    id: string,
    input: WaterbodyInput,
  ): Promise<AdminWaterBody> {
    const waterBody = await this.waterbodiesRepository.findOne({
      where: { id },
    });
    if (!waterBody) {
      throw new NotFoundException(`WaterBody ${id} not found`);
    }
    if (input.name !== undefined) waterBody.name = input.name;
    if (input.region !== undefined) waterBody.region = input.region ?? null;
    if (input.description !== undefined) {
      waterBody.description = input.description ?? null;
    }
    if (input.active !== undefined) waterBody.active = input.active;
    await this.waterbodiesRepository.save(waterBody);
    await this.applyLocation(id, input);
    return this.getWaterbody(id);
  }

  async deleteWaterbody(id: string): Promise<{ id: string; deleted: true }> {
    const waterBody = await this.waterbodiesRepository.findOne({
      where: { id },
    });
    if (!waterBody) {
      throw new NotFoundException(`WaterBody ${id} not found`);
    }
    await this.waterbodiesRepository.remove(waterBody);
    return { id, deleted: true };
  }

  async setWaterbodyActive(id: string, active: boolean): Promise<AdminWaterBody> {
    return this.updateWaterbody(id, { active });
  }

  private async applyLocation(
    id: string,
    input: WaterbodyInput,
  ): Promise<void> {
    if (input.latitude === undefined && input.longitude === undefined) {
      return;
    }
    const latitude = typeof input.latitude === 'number' ? input.latitude : null;
    const longitude =
      typeof input.longitude === 'number' ? input.longitude : null;
    if (latitude === null || longitude === null) {
      await this.waterbodiesRepository.query(
        `UPDATE waterbodies SET location = NULL WHERE id = $1`,
        [id],
      );
      return;
    }
    await this.waterbodiesRepository.query(
      `UPDATE waterbodies
         SET location = ST_SetSRID(ST_MakePoint($1, $2), 4326)
       WHERE id = $3`,
      [longitude, latitude, id],
    );
  }

  private async withLocation(
    items: WaterBody[],
  ): Promise<AdminWaterBody[]> {
    if (items.length === 0) return [] as AdminWaterBody[];
    const ids = items.map((w) => w.id);
    const rows: { id: string; latitude: number | null; longitude: number | null }[] =
      await this.waterbodiesRepository.query(
        `SELECT id,
                ST_Y(location::geometry)::float8 AS latitude,
                ST_X(location::geometry)::float8 AS longitude
           FROM waterbodies
          WHERE id = ANY($1)`,
        [ids],
      );
    const byId = new Map(rows.map((r) => [r.id, r]));
    return items.map((w) => {
      const loc = byId.get(w.id);
      return Object.assign(w, {
        latitude: loc?.latitude ?? null,
        longitude: loc?.longitude ?? null,
      }) as AdminWaterBody;
    });
  }
}