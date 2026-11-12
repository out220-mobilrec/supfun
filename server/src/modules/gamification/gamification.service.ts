import { Injectable } from '@nestjs/common';
import { InjectDataSource, InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { UsersService } from '../users/users.service';
import { PointLog } from './point-log.entity';
import { UserAchievement } from './user-achievement.entity';

export interface AchievementDef {
  code: string;
  title: string;
  description: string;
  icon: string | null;
  xp: number;
}

export const ACHIEVEMENTS: AchievementDef[] = [
  { code: 'first_swim', title: 'Первый заплыв', description: 'Завершите свой первый заплыв', icon: '🏄', xp: 25 },
  { code: 'distance_10', title: '10 км на воде', description: 'Наберите 10 км суммарной дистанции', icon: '📏', xp: 50 },
  { code: 'distance_100', title: '100 км на воде', description: 'Наберите 100 км суммарной дистанции', icon: '🏅', xp: 150 },
  { code: 'night_swim', title: 'Ночной заплыв', description: 'Завершите заплыв в тёмное время суток', icon: '🌙', xp: 30 },
  { code: 'first_organizer', title: 'Организатор', description: 'Создайте свой первый заплыв', icon: '📣', xp: 20 },
  { code: 'social', title: 'Социальный', description: 'Завершите заплыв в составе события с 3+ участниками', icon: '🤝', xp: 50 },
  { code: 'streak_3', title: 'Серия заплывов', description: 'Завершите заплывы 3 дня подряд', icon: '🔥', xp: 25 },
];

export const ACTION_POINTS: Record<string, number> = {
  track_completed: 10,
  route_published: 15,
  event_created: 20,
  group_swim: 10,
};

/** XP, необходимый для перехода с 1-го уровня на 2-й. */
export const LEVEL_BASE_XP = 200;
/** Каждый следующий уровень дороже предыдущего в это число раз. */
export const LEVEL_GROWTH = 1.4;

export interface LevelThreshold {
  /** Уровень, на который открывается порог. */
  level: number;
  /** Суммарный XP, нужный для этого уровня. */
  totalXp: number;
  /** XP «на этом уровне» от предыдущего порога. */
  xpForNext: number;
}

/** Пороги уровней: need(1) = 200, need(n) = round(need(n-1) * 1.4). */
export function levelThresholds(count: number): LevelThreshold[] {
  const out: LevelThreshold[] = [];
  let need = LEVEL_BASE_XP;
  let total = 0;
  for (let i = 1; i <= count; i++) {
    total += need;
    out.push({ level: i + 1, totalXp: total, xpForNext: need });
    need = Math.round(need * LEVEL_GROWTH);
  }
  return out;
}

export interface GamificationRules {
  level: {
    baseXp: number;
    growth: number;
    formula: string;
    thresholds: LevelThreshold[];
  };
  actions: { action: string; label: string; xp: string }[];
  achievements: AchievementDef[];
}

export interface AwardContext {
  distanceKm?: number;
  isNight?: boolean;
  eventId?: string;
  refType?: string;
  refId?: string;
}

export interface AwardResult {
  points: number;
  userXp: number;
  unlocked: AchievementDef[];
}

export interface LevelInfo {
  level: number;
  xp: number;
  currentLevelXp: number;
  nextLevelXp: number;
  progress: number;
}

@Injectable()
export class GamificationService {
  constructor(
    @InjectRepository(PointLog)
    private readonly pointLogsRepository: Repository<PointLog>,
    @InjectRepository(UserAchievement)
    private readonly achievementsRepository: Repository<UserAchievement>,
    private readonly usersService: UsersService,
    @InjectDataSource()
    private readonly dataSource: DataSource,
    private readonly eventEmitter: EventEmitter2,
  ) {}

  async award(userId: string, action: string, ctx: AwardContext = {}): Promise<AwardResult> {
    const base = ACTION_POINTS[action] ?? 0;
    let points = base;
    if (action === 'distance_bonus' && ctx.distanceKm) {
      points = Math.floor(ctx.distanceKm / 5) * 5;
    }

    if (points > 0) {
      await this.pointLogsRepository.save(
        this.pointLogsRepository.create({
          userId,
          action,
          points,
          refType: ctx.refType ?? null,
          refId: ctx.refId ?? null,
        }),
      );
    }
    const user = await this.usersService.findById(userId);
    user.xp += points;
    await this.usersService.update(userId, { xp: user.xp });

    const unlocked: AchievementDef[] = [];
    if (action === 'track_completed') {
      const codes = await this.checkTrackAchievements(userId, ctx);
      unlocked.push(...this.resolveDefs(codes));
    }
    if (action === 'event_created') {
      const codes = await this.checkOrganizerAchievement(userId);
      unlocked.push(...this.resolveDefs(codes));
    }

    if (unlocked.length > 0) {
      this.eventEmitter.emit('achievements.unlocked', { userId, achievements: unlocked });
    }

    return { points, userXp: user.xp, unlocked };
  }

  async levelInfo(userId: string): Promise<LevelInfo> {
    const user = await this.usersService.findById(userId);
    return this.computeLevel(user.xp);
  }

  computeLevel(xp: number): LevelInfo {
    let level = 1;
    let remaining = xp;
    let need = LEVEL_BASE_XP;
    while (remaining >= need) {
      remaining -= need;
      level += 1;
      need = Math.round(need * LEVEL_GROWTH);
    }
    return {
      level,
      xp,
      currentLevelXp: remaining,
      nextLevelXp: need,
      progress: remaining / need,
    };
  }

  /** Публичное описание правил: нужно и веб-справке, и мобильному клиенту. */
  rules(): GamificationRules {
    return {
      level: {
        baseXp: LEVEL_BASE_XP,
        growth: LEVEL_GROWTH,
        formula: 'XP до следующего уровня: need(1) = 200, need(n) = round(need(n-1) × 1.4)',
        thresholds: levelThresholds(12),
      },
      actions: [
        { action: 'track_completed', label: 'Завершён заплыв (трек)', xp: '10' },
        { action: 'route_published', label: 'Опубликован маршрут', xp: '15' },
        { action: 'event_created', label: 'Создан заплыв-событие', xp: '20' },
        { action: 'group_swim', label: 'Заплыв в составе события', xp: '10' },
        {
          action: 'distance_bonus',
          label: 'Бонус за дистанцию',
          xp: '5 XP за каждые полные 5 км',
        },
        { action: 'achievement', label: 'Открытое достижение', xp: 'по таблице достижений' },
      ],
      achievements: ACHIEVEMENTS,
    };
  }

  async journal(userId: string): Promise<PointLog[]> {
    return this.pointLogsRepository.find({
      where: { userId },
      order: { createdAt: 'DESC' },
    });
  }

  async listAchievements(userId: string): Promise<(AchievementDef & { unlocked: boolean; unlockedAt: Date | null })[]> {
    const unlocked = await this.achievementsRepository.find({ where: { userId } });
    const byCode = new Map(unlocked.map((u) => [u.achievementCode, u]));
    return ACHIEVEMENTS.map((a) => ({
      ...a,
      unlocked: byCode.has(a.code),
      unlockedAt: byCode.get(a.code)?.unlockedAt ?? null,
    }));
  }

  private async checkTrackAchievements(userId: string, ctx: AwardContext): Promise<string[]> {
    const row: { completed: string; total_km: string } | undefined =
      await this.dataSource.query(
        `SELECT COUNT(*)::int AS completed,
                COALESCE(SUM(distance_meters), 0) / 1000.0 AS total_km
         FROM tracks
         WHERE user_id = $1 AND ended_at IS NOT NULL AND distance_meters > 0`,
        [userId],
      ).then((r) => r[0]);

    const totalKm = Number(row?.total_km ?? 0);
    const completed = Number(row?.completed ?? 0);

    const [isSocial, isStreak] = await Promise.all([
      this.isSocialSwim(ctx.eventId),
      this.isStreakReached(userId, 3),
    ]);

    const conditions: Array<[string, boolean]> = [
      ['first_swim', completed >= 1],
      ['distance_10', totalKm >= 10],
      ['distance_100', totalKm >= 100],
      ['night_swim', Boolean(ctx.isNight)],
      ['social', isSocial],
      ['streak_3', isStreak],
    ];

    const unlocked: string[] = [];
    for (const [code, ok] of conditions) {
      if (ok && (await this.unlock(userId, code))) {
        unlocked.push(code);
      }
    }
    return unlocked;
  }

  private async isSocialSwim(eventId?: string): Promise<boolean> {
    if (!eventId) return false;
    const row: { cnt: string } | undefined = await this.dataSource.query(
      `SELECT COUNT(*)::int AS cnt FROM event_participants
       WHERE event_id = $1 AND status = 'going'`,
      [eventId],
    ).then((r) => r[0]);
    return Number(row?.cnt ?? 0) >= 3;
  }

  private async isStreakReached(userId: string, minDays: number): Promise<boolean> {
    const rows: { d: string }[] = await this.dataSource.query(
      `SELECT DISTINCT (ended_at::date)::text AS d
       FROM tracks
       WHERE user_id = $1 AND ended_at IS NOT NULL AND distance_meters > 0
       ORDER BY d DESC`,
      [userId],
    ).then((r) => r as { d: string }[]);
    if (rows.length < minDays) return false;
    const days = rows.map((r) => new Date(`${r.d}T00:00:00Z`).getTime());
    let best = 1;
    let run = 1;
    for (let i = 1; i < days.length; i++) {
      const diff = Math.round((days[i - 1] - days[i]) / 86_400_000);
      if (diff === 1) {
        run += 1;
        if (run > best) best = run;
      } else {
        run = 1;
      }
    }
    return best >= minDays;
  }

  private async checkOrganizerAchievement(userId: string): Promise<string[]> {
    const row: { cnt: string } | undefined = await this.dataSource.query(
      `SELECT COUNT(*)::int AS cnt FROM events WHERE organizer_id = $1`,
      [userId],
    ).then((r) => r[0]);
    if (Number(row?.cnt ?? 0) >= 1 && (await this.unlock(userId, 'first_organizer'))) {
      return ['first_organizer'];
    }
    return [];
  }

  private async unlock(userId: string, code: string): Promise<boolean> {
    const existing = await this.achievementsRepository.findOne({
      where: { userId, achievementCode: code },
    });
    if (existing) return false;
    const def = ACHIEVEMENTS.find((a) => a.code === code);
    if (!def) return false;
    await this.achievementsRepository.save(
      this.achievementsRepository.create({ userId, achievementCode: code }),
    );
    await this.pointLogsRepository.save(
      this.pointLogsRepository.create({
        userId,
        action: 'achievement',
        points: def.xp,
        refType: 'achievement',
        refId: code,
      }),
    );
    const user = await this.usersService.findById(userId);
    user.xp += def.xp;
    await this.usersService.update(userId, { xp: user.xp });
    return true;
  }

  private resolveDefs(codes: string[]): AchievementDef[] {
    return codes
      .map((code) => ACHIEVEMENTS.find((a) => a.code === code))
      .filter((a): a is AchievementDef => Boolean(a));
  }
}