import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectDataSource, InjectRepository } from '@nestjs/typeorm';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { DataSource, Repository } from 'typeorm';
import { Track, TrackStatus } from './track.entity';
import { TrackPoint } from './track-point.entity';
import {
  TrackPointDto,
  CreateTrackDto,
  CompleteTrackDto,
  UpdateTrackDto,
  TrackQueryDto,
  GpsPointDto,
  StartEventTrackDto,
} from './dto/track.dto';
import { GamificationService, AwardResult } from '../gamification/gamification.service';
import { UserRole } from '../users/user.entity';
import type { AuthUser } from '../../common/decorators/current-user.decorator';

/** Строка списка «треки участников заплыва». */
export interface EventTrackSummary {
  id: string;
  userId: string;
  author: { id: string; name: string; avatarUrl: string | null };
  name: string | null;
  status: TrackStatus;
  startedAt: Date;
  endedAt: Date | null;
  distanceMeters: number;
  durationSeconds: number;
  avgSpeedKph: number;
  pointsCount: number;
}

@Injectable()
export class TracksService {
  constructor(
    @InjectRepository(Track)
    private readonly tracksRepository: Repository<Track>,
    @InjectRepository(TrackPoint)
    private readonly pointsRepository: Repository<TrackPoint>,
    private readonly gamificationService: GamificationService,
    private readonly eventEmitter: EventEmitter2,
    @InjectDataSource()
    private readonly dataSource: DataSource,
  ) {}

  async create(userId: string, dto: CreateTrackDto): Promise<Track> {
    const track = this.tracksRepository.create({
      userId,
      name: dto.name ?? null,
      waterBodyId: dto.waterBodyId ?? null,
      eventId: dto.eventId ?? null,
      routeId: dto.routeId ?? null,
      difficulty: dto.difficulty ?? null,
      startedAt: new Date(dto.startedAt),
    });
    return this.tracksRepository.save(track);
  }

  async listMine(userId: string): Promise<Track[]> {
    return this.tracksRepository.find({
      where: { userId },
      order: { startedAt: 'DESC' },
      relations: { waterBody: true },
    });
  }

  /**
   * Справочник маршрутов с фильтрами.
   * scope=mine — только свои, scope=public — только опубликованные,
   * scope=all (по умолчанию) — опубликованные плюс свои черновики.
   */
  async list(query: TrackQueryDto, me: AuthUser): Promise<Track[]> {
    const qb = this.tracksRepository
      .createQueryBuilder('track')
      .leftJoinAndSelect('track.waterBody', 'waterBody')
      .leftJoinAndSelect('track.user', 'user')
      .leftJoinAndSelect('track.route', 'route')
      .orderBy('track.startedAt', 'DESC')
      .take(Math.min(query.limit ?? 50, 100))
      .skip(query.offset ?? 0);

    if (query.scope === 'mine') {
      qb.andWhere('track.user_id = :me', { me: me.id });
    } else if (query.scope === 'public') {
      qb.andWhere('track.status = :published', { published: TrackStatus.PUBLISHED });
    } else {
      qb.andWhere('(track.status = :published OR track.user_id = :me)', {
        published: TrackStatus.PUBLISHED,
        me: me.id,
      });
    }

    if (query.waterBodyId) {
      qb.andWhere('track.waterbody_id = :wb', { wb: query.waterBodyId });
    }
    if (query.routeId) {
      qb.andWhere('track.route_id = :routeId', { routeId: query.routeId });
    }
    if (query.region) {
      qb.andWhere('waterBody.region ILIKE :region', { region: `%${query.region}%` });
    }
    if (query.farEast === 'true' || query.farEast === '1') {
      qb.andWhere(
        `(waterBody.region ILIKE '%Примор%' OR waterBody.region ILIKE '%Камчат%' OR waterBody.region ILIKE '%Сахалин%' OR waterBody.region ILIKE '%Хабаров%' OR waterBody.region ILIKE '%Амур%' OR waterBody.region ILIKE '%Магадан%' OR waterBody.region ILIKE '%Чукот%' OR waterBody.region ILIKE '%Якут%')`,
      );
    }
    if (query.difficulty) {
      qb.andWhere('track.difficulty = :diff', { diff: query.difficulty });
    }
    if (query.minDurationSec !== undefined) {
      qb.andWhere('track.duration_seconds >= :minDur', { minDur: query.minDurationSec });
    }
    if (query.maxDurationSec !== undefined) {
      qb.andWhere('track.duration_seconds <= :maxDur', { maxDur: query.maxDurationSec });
    }

    return qb.getMany();
  }

  async findById(id: string, viewer?: AuthUser): Promise<Track> {
    const track = await this.tracksRepository.findOne({
      where: { id },
      relations: { user: true, waterBody: true, event: true, route: { points: true } },
    });
    if (!track) {
      throw new NotFoundException(`Track ${id} not found`);
    }
    if (track.userId !== viewer?.id && !this.isStaff(viewer) && track.status === TrackStatus.PRIVATE) {
      throw new ForbiddenException('This track is private');
    }
    return track;
  }

  async update(id: string, me: AuthUser, dto: UpdateTrackDto): Promise<Track> {
    const track = await this.ensureEditable(id, me);
    if (dto.name !== undefined) track.name = dto.name;
    if (dto.waterBodyId !== undefined) track.waterBodyId = dto.waterBodyId;
    if (dto.routeId !== undefined) track.routeId = dto.routeId;
    if (dto.difficulty !== undefined) track.difficulty = dto.difficulty;
    if (dto.distanceMeters !== undefined) track.distanceMeters = dto.distanceMeters;
    if (dto.durationSeconds !== undefined) track.durationSeconds = dto.durationSeconds;
    if (dto.avgSpeedKph !== undefined) track.avgSpeedKph = dto.avgSpeedKph;
    if (dto.maxSpeedKph !== undefined) track.maxSpeedKph = dto.maxSpeedKph;
    if (dto.elevationGainMeters !== undefined) track.elevationGainMeters = dto.elevationGainMeters;
    if (dto.elevationLossMeters !== undefined) track.elevationLossMeters = dto.elevationLossMeters;
    if (dto.calories !== undefined) track.calories = dto.calories;
    await this.tracksRepository.save(track);
    return this.findById(id, me);
  }

  async addPoints(
    id: string,
    me: AuthUser,
    points: TrackPointDto[],
  ): Promise<{ added: number; skipped: number; total: number }> {
    const track = await this.tracksRepository.findOne({ where: { id } });
    if (!track) throw new NotFoundException(`Track ${id} not found`);
    const staff = me.role === UserRole.ADMIN || me.role === UserRole.MODERATOR;
    if (track.userId !== me.id && !staff) throw new ForbiddenException('Not your track');
    if (track.endedAt) throw new ForbiddenException('Трек уже завершён — точки добавить нельзя');

    const hasSeq = points.some((p) => p.seq !== undefined);
    if (!hasSeq) {
      const entities = points.map((p) =>
        this.pointsRepository.create({
          trackId: id,
          lat: p.lat,
          lng: p.lng,
          altitude: p.altitude ?? null,
          speedKph: p.speedKph ?? null,
          recordedAt: new Date(p.recordedAt),
        }),
      );
      if (entities.length) await this.pointsRepository.save(entities);
      const total = await this.pointsRepository.count({ where: { trackId: id } });
      return { added: entities.length, skipped: 0, total };
    }

    const known = new Set<number>(
      (await this.pointsRepository.find({ select: ['seq'], where: { trackId: id } }))
        .map((p) => p.seq)
        .filter((s): s is number => s !== null),
    );
    const fresh = points.filter((p) => p.seq === undefined || !known.has(p.seq));
    if (fresh.length > 0) {
      await this.pointsRepository
        .createQueryBuilder()
        .insert()
        .into(TrackPoint)
        .values(
          fresh.map((p) => ({
            trackId: id,
            seq: p.seq ?? null,
            lat: p.lat,
            lng: p.lng,
            altitude: p.altitude ?? null,
            speedKph: p.speedKph ?? null,
            recordedAt: new Date(p.recordedAt),
          })),
        )
        .orIgnore()
        .execute();
    }
    const total = await this.pointsRepository.count({ where: { trackId: id } });
    return { added: fresh.length, skipped: points.length - fresh.length, total };
  }

  async getPoints(id: string, me?: AuthUser): Promise<TrackPoint[]> {
    const track = await this.findById(id, me);
    return this.pointsRepository.find({
      where: { trackId: id },
      order: { recordedAt: 'ASC' },
    });
  }

  async replacePoints(
    id: string,
    me: AuthUser,
    points: TrackPointDto[],
    recalc = true,
  ): Promise<{ replaced: number; track: Track }> {
    const track = await this.ensureEditable(id, me);
    // Удаляем старые точки, создаём новые
    await this.pointsRepository.delete({ trackId: id });
    const entities = points.map((p) =>
      this.pointsRepository.create({
        trackId: id,
        lat: p.lat,
        lng: p.lng,
        altitude: p.altitude ?? null,
        speedKph: p.speedKph ?? null,
        recordedAt: new Date(p.recordedAt),
      }),
    );
    await this.pointsRepository.save(entities);

    if (recalc) {
      const stats = this.computeStats(entities, track.endedAt ?? new Date());
      track.distanceMeters = stats.distanceMeters;
      track.durationSeconds = stats.durationSeconds;
      track.avgSpeedKph = stats.avgSpeedKph;
      track.maxSpeedKph = stats.maxSpeedKph;
      track.elevationGainMeters = stats.elevationGainMeters;
      track.elevationLossMeters = stats.elevationLossMeters;
      track.calories = stats.calories;
    }
    await this.tracksRepository.save(track);

    // route_line пересобираем ПОСЛЕ save: сущность track загружалась до замены
    // точек и содержала старый route_line, которым save() иначе затёр бы новый.
    await this.buildRouteLine(id);
    return { replaced: entities.length, track: await this.findById(id, me) };
  }

  async complete(
    id: string,
    me: AuthUser,
    dto: CompleteTrackDto,
  ): Promise<{ track: Track; award: AwardResult }> {
    const track = await this.ensureEditable(id, me);
    const userId = track.userId;
    if (track.endedAt) {
      throw new NotFoundException(`Track ${id} is already completed`);
    }
    const points = await this.pointsRepository.find({
      where: { trackId: id },
      order: { recordedAt: 'ASC' },
    });
    const stats = this.computeStats(points, new Date(dto.endedAt));

    track.distanceMeters = stats.distanceMeters;
    track.durationSeconds = stats.durationSeconds;
    track.avgSpeedKph = stats.avgSpeedKph;
    track.maxSpeedKph = stats.maxSpeedKph;
    track.elevationGainMeters = stats.elevationGainMeters;
    track.elevationLossMeters = stats.elevationLossMeters;
    track.calories = stats.calories;
    track.endedAt = new Date(dto.endedAt);
    if (dto.name !== undefined) track.name = dto.name;
    if (dto.difficulty !== undefined) track.difficulty = dto.difficulty;
    await this.tracksRepository.save(track);

    await this.buildRouteLine(id);

    if (track.eventId) {
      await this.completeLinkedEvent(track.eventId, track.userId);
    }

    const distanceKm = stats.distanceMeters / 1000;
    const startHour = track.startedAt.getUTCHours() + track.startedAt.getUTCMinutes() / 60;
    const isNight = startHour < 5 || startHour >= 22;

    const award = await this.gamificationService.award(userId, 'track_completed', {
      distanceKm,
      isNight,
      eventId: track.eventId ?? undefined,
      refType: 'track',
      refId: id,
    });

    let distanceAward: AwardResult | null = null;
    if (distanceKm >= 5) {
      distanceAward = await this.gamificationService.award(userId, 'distance_bonus', {
        distanceKm,
        refType: 'track',
        refId: id,
      });
    }

    let groupAward: AwardResult | null = null;
    if (track.eventId) {
      const going = await this.dataSource.query(
        `SELECT COUNT(*)::int AS cnt FROM event_participants
         WHERE event_id = $1 AND status = 'going'`,
        [track.eventId],
      );
      if (Number(going[0]?.cnt ?? 0) >= 2) {
        groupAward = await this.gamificationService.award(userId, 'group_swim', {
          refType: 'track',
          refId: id,
        });
      }
    }

    const merged: AwardResult = {
      points:
        award.points +
        (distanceAward?.points ?? 0) +
        (groupAward?.points ?? 0),
      userXp: await this.currentXp(userId),
      unlocked: [...award.unlocked],
    };
    this.eventEmitter.emit('tracks.completed', {
      userId,
      trackId: id,
      name: track.name ?? 'Заплыв',
      distanceMeters: track.distanceMeters,
    });
    return { track: await this.findById(id, me), award: merged };
  }

  /**
   * Треки участников заплыва: кто сколько прошёл и сколько точек сдал.
   * Используется на странице заплыва (список + карта).
   */
  async listByEvent(eventId: string): Promise<EventTrackSummary[]> {
    const rows: Array<{
      id: string;
      userId: string;
      name: string | null;
      status: TrackStatus;
      startedAt: Date;
      endedAt: Date | null;
      distanceMeters: number;
      durationSeconds: number;
      avgSpeedKph: number;
      authorName: string;
      authorAvatar: string | null;
      pointsCount: number;
    }> = await this.dataSource.query(
      `SELECT t.id,
              t.user_id                       AS "userId",
              t.name,
              t.status,
              t.started_at                    AS "startedAt",
              t.ended_at                      AS "endedAt",
              t.distance_meters               AS "distanceMeters",
              t.duration_seconds              AS "durationSeconds",
              t.avg_speed_kph                 AS "avgSpeedKph",
              u.name                          AS "authorName",
              u.avatar_url                    AS "authorAvatar",
              (SELECT count(*) FROM track_points p WHERE p.track_id = t.id)::int AS "pointsCount"
         FROM tracks t
         JOIN users u ON u.id = t.user_id
        WHERE t.event_id = $1
        ORDER BY t.started_at ASC`,
      [eventId],
    );

    return rows.map((r) => ({
      id: r.id,
      userId: r.userId,
      name: r.name,
      status: r.status,
      startedAt: r.startedAt,
      endedAt: r.endedAt,
      distanceMeters: Number(r.distanceMeters ?? 0),
      durationSeconds: Number(r.durationSeconds ?? 0),
      avgSpeedKph: Number(r.avgSpeedKph ?? 0),
      pointsCount: Number(r.pointsCount ?? 0),
      author: { id: r.userId, name: r.authorName, avatarUrl: r.authorAvatar },
    }));
  }

  /**
   * Старт (или продолжение) записи трека участником заплыва.
   * Повторный вызов до финиша возвращает тот же трек — клиент может
   * безопаснее ретраить запрос после обрыва связи.
   */
  async startForEvent(
    eventId: string,
    me: AuthUser,
    dto: StartEventTrackDto,
  ): Promise<Track> {
    const participation = await this.assertEventParticipant(eventId, me.id);
    const existing = await this.tracksRepository.findOne({
      where: { eventId, userId: me.id },
      order: { startedAt: 'DESC' },
    });
    if (existing && !existing.endedAt) {
      return existing;
    }
    return this.tracksRepository.save(
      this.tracksRepository.create({
        userId: me.id,
        eventId,
        // Водоём наследуем с маршрута заплыва, если он задан
        waterBodyId: participation.waterBodyId,
        name: dto.name ?? null,
        status: TrackStatus.DRAFT,
        startedAt: dto.startedAt ? new Date(dto.startedAt) : new Date(),
      }),
    );
  }

  /**
   * Догрузка точек трека пачкой (мобильное приложение, work offline).
   * Повторно присланные seq игнорируются — запрос можно слать заново без дублей.
   */
  async appendGpsPoints(
    trackId: string,
    me: AuthUser,
    points: GpsPointDto[],
  ): Promise<{ added: number; skipped: number; total: number }> {
    const track = await this.tracksRepository.findOne({ where: { id: trackId } });
    if (!track) {
      throw new NotFoundException(`Track ${trackId} not found`);
    }
    const staff = me.role === UserRole.ADMIN || me.role === UserRole.MODERATOR;
    if (track.userId !== me.id && !staff) {
      throw new ForbiddenException('Not your track');
    }
    if (track.endedAt) {
      throw new ForbiddenException('Трек уже завершён — точки добавить нельзя');
    }

    const known = new Set<number>(
      (await this.pointsRepository.find({ select: ['seq'], where: { trackId } }))
        .map((p) => p.seq)
        .filter((s): s is number => s !== null),
    );
    const fresh = points.filter((p) => p.seq === undefined || !known.has(p.seq));

    if (fresh.length > 0) {
      await this.pointsRepository
        .createQueryBuilder()
        .insert()
        .into(TrackPoint)
        .values(
          fresh.map((p) => ({
            trackId,
            seq: p.seq ?? null,
            lat: p.lat,
            lng: p.lng,
            altitude: p.altitude ?? null,
            speedKph: p.speedKph ?? null,
            recordedAt: new Date(p.recordedAt),
          })),
        )
        // гонка двух пакетов с одинаковым seq не должна ронять запрос
        .orIgnore()
        .execute();
    }

    const total = await this.pointsRepository.count({ where: { trackId } });
    return { added: fresh.length, skipped: points.length - fresh.length, total };
  }

  /** Финиш записи трека в рамках заплыва: статистика, XP, закрытие события. */
  async finishForEvent(
    eventId: string,
    trackId: string,
    me: AuthUser,
    dto: CompleteTrackDto,
  ): Promise<{ track: Track; award: AwardResult }> {
    const track = await this.tracksRepository.findOne({ where: { id: trackId } });
    if (!track || track.eventId !== eventId) {
      throw new NotFoundException(`Track ${trackId} does not belong to event ${eventId}`);
    }
    return this.complete(trackId, me, dto);
  }

  /** Участник заплыва (или организатор/стафф) плюс водоём с маршрута заплыва. */
  async assertEventParticipant(
    eventId: string,
    userId: string,
  ): Promise<{ waterBodyId: string | null }> {
    const rows: Array<{ organizerId: string; waterBodyId: string | null; joined: string }> =
      await this.dataSource.query(
        `SELECT e.organizer_id AS "organizerId",
                t.waterbody_id AS "waterBodyId",
                EXISTS (
                  SELECT 1 FROM event_participants ep
                   WHERE ep.event_id = e.id AND ep.user_id = $2
                )::int AS joined
           FROM events e
           LEFT JOIN tracks t ON t.id = e.track_id
          WHERE e.id = $1`,
        [eventId, userId],
      );
    if (rows.length === 0) {
      throw new NotFoundException(`Event ${eventId} not found`);
    }
    const isOrganizer = rows[0].organizerId === userId;
    const joined = Number(rows[0].joined ?? 0) > 0;
    if (!isOrganizer && !joined) {
      throw new ForbiddenException('Вы не участник этого заплыва');
    }
    return { waterBodyId: rows[0].waterBodyId ?? null };
  }

  private async currentXp(userId: string): Promise<number> {
    const row = await this.dataSource.query(
      `SELECT xp FROM users WHERE id = $1`,
      [userId],
    );
    return Number(row[0]?.xp ?? 0);
  }

  async publish(id: string, me: AuthUser): Promise<Track> {
    const track = await this.ensureEditable(id, me);
    track.status = TrackStatus.PUBLISHED;
    await this.tracksRepository.save(track);
    if (track.distanceMeters > 0) {
      // Баллы всегда достаются автору трека, даже если публикует стафф
      await this.gamificationService.award(track.userId, 'route_published', {
        refType: 'track',
        refId: id,
      });
    }
    return this.findById(id, me);
  }

  async remove(id: string, me: AuthUser): Promise<{ ok: boolean }> {
    const track = await this.tracksRepository.findOne({ where: { id } });
    if (!track) {
      throw new NotFoundException(`Track ${id} not found`);
    }
    // Удаление чужого трека — только администратор (как удаление событий)
    if (track.userId !== me.id && me.role !== UserRole.ADMIN) {
      throw new ForbiddenException('Only the author or an admin can delete this track');
    }
    await this.tracksRepository.remove(track);
    return { ok: true };
  }

  /** Владелец трека или стафф (admin/moderator) — право на правку чужих треков. */
  private async ensureEditable(id: string, me: AuthUser): Promise<Track> {
    const track = await this.tracksRepository.findOne({ where: { id } });
    if (!track) {
      throw new NotFoundException(`Track ${id} not found`);
    }
    if (track.userId !== me.id && !this.isStaff(me)) {
      throw new ForbiddenException('Not your track');
    }
    return track;
  }

  private isStaff(me?: AuthUser): boolean {
    return me?.role === UserRole.ADMIN || me?.role === UserRole.MODERATOR;
  }

  private async buildRouteLine(id: string): Promise<void> {
    await this.dataSource.query(
      `UPDATE tracks
       SET route_line = (
         SELECT ST_MakeLine(p.geom ORDER BY p.recorded_at)
         FROM (
           SELECT ST_SetSRID(ST_MakePoint(lng, lat), 4326) AS geom, recorded_at
           FROM track_points WHERE track_id = $1
         ) p
       )
       WHERE id = $1`,
      [id],
    );
  }

  private async completeLinkedEvent(eventId: string, userId: string): Promise<void> {
    await this.dataSource.query(
      `UPDATE events
       SET status = 'completed'
       WHERE id = $1 AND organizer_id = $2`,
      [eventId, userId],
    );
  }

  private computeStats(
    points: TrackPoint[],
    endedAt: Date,
  ): {
    distanceMeters: number;
    durationSeconds: number;
    avgSpeedKph: number;
    maxSpeedKph: number;
    elevationGainMeters: number;
    elevationLossMeters: number;
    calories: number;
  } {
    let distanceMeters = 0;
    let elevationGain = 0;
    let elevationLoss = 0;
    let maxSpeed = 0;

    for (let i = 1; i < points.length; i++) {
      distanceMeters += this.haversine(points[i - 1], points[i]);
      const segmentAlt = (points[i].altitude ?? 0) - (points[i - 1].altitude ?? 0);
      if (segmentAlt > 0) elevationGain += segmentAlt;
      else elevationLoss += Math.abs(segmentAlt);
      const pSpeed = points[i].speedKph ?? 0;
      if (pSpeed > maxSpeed) maxSpeed = pSpeed;
    }

    const firstTs = points.length > 0 ? points[0].recordedAt.getTime() : 0;
    const lastTs = points.length > 0 ? points[points.length - 1].recordedAt.getTime() : endedAt.getTime();
    const durationSeconds = points.length > 0 ? Math.max(1, Math.round((lastTs - firstTs) / 1000)) : 0;
    const avgSpeedKph = durationSeconds > 0 ? (distanceMeters / durationSeconds) * 3.6 : 0;
    const calories = Math.round((distanceMeters / 1000) * 30);

    return {
      distanceMeters: Math.round(distanceMeters * 10) / 10,
      durationSeconds,
      avgSpeedKph: Math.round(avgSpeedKph * 100) / 100,
      maxSpeedKph: Math.round(maxSpeed * 100) / 100,
      elevationGainMeters: Math.round(elevationGain),
      elevationLossMeters: Math.round(elevationLoss),
      calories,
    };
  }

  private haversine(a: TrackPoint, b: TrackPoint): number {
    const R = 6371000;
    const dLat = this.toRad(b.lat - a.lat);
    const dLng = this.toRad(b.lng - a.lng);
    const sinLat = Math.sin(dLat / 2);
    const sinLng = Math.sin(dLng / 2);
    const h =
      sinLat * sinLat +
      Math.cos(this.toRad(a.lat)) * Math.cos(this.toRad(b.lat)) * sinLng * sinLng;
    return 2 * R * Math.asin(Math.sqrt(h));
  }

  private toRad(deg: number): number {
    return (deg * Math.PI) / 180;
  }
}