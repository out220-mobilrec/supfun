import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository, QueryFailedError } from 'typeorm';
import { User, UserRole, VisibilityScope } from './user.entity';
import { BlocksService } from '../blocks/blocks.service';
import { ReferenceService } from '../reference/reference.service';
import type { AuthUser } from '../../common/decorators/current-user.decorator';
import type { WaterBody } from '../waterbodies/waterbody.entity';

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
  user: Partial<User>;
  stats: ProfileStats | null;
  canView: boolean;
  blocked: boolean;
  isFriend: boolean;
  isSelf: boolean;
}

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private readonly usersRepository: Repository<User>,
    private readonly dataSource: DataSource,
    private readonly blocks: BlocksService,
    private readonly reference: ReferenceService,
  ) {}

  async list(): Promise<User[]> {
    return this.usersRepository.find();
  }

  async findById(id: string): Promise<User> {
    const user = await this.usersRepository.findOne({ where: { id } });
    if (!user) {
      throw new NotFoundException(`User ${id} not found`);
    }
    return user;
  }

  async findByEmail(email: string): Promise<User | null> {
    return this.usersRepository.findOne({ where: { email } });
  }

  async findByEmailWithPassword(email: string): Promise<User | null> {
    return this.usersRepository
      .createQueryBuilder('user')
      .addSelect('user.passwordHash')
      .where('user.email = :email', { email })
      .getOne();
  }

  async create(data: Partial<User>): Promise<User> {
    const user = this.usersRepository.create(data);
    try {
      return await this.usersRepository.save(user);
    } catch (error) {
      if (error instanceof QueryFailedError && (error as any).code === '23505') {
        throw new ConflictException('User with this email already exists');
      }
      throw error;
    }
  }

  async update(id: string, data: Partial<User>): Promise<User> {
    const user = await this.findById(id);
    if (data.country !== undefined) {
      user.country = await this.normalizeCountry(data.country);
      delete data.country;
    }
    if (data.locale !== undefined) {
      data.locale = data.locale === 'en' ? 'en' : 'ru';
    }
    Object.assign(user, data);
    return this.usersRepository.save(user);
  }

  /**
   * Страна хранится кодом из справочника. Пустое значение сбрасывает поле,
   * неизвестный код — ошибка, а не «мусор в базе».
   */
  private async normalizeCountry(value: string | null): Promise<string | null> {
    if (value === null || value === '') return null;
    const code = String(value).trim().toUpperCase();
    if (!(await this.reference.isValidCountryCode(code))) {
      throw new BadRequestException(`Неизвестный код страны: ${value}`);
    }
    return code;
  }

  async remove(id: string): Promise<void> {
    const user = await this.findById(id);
    await this.usersRepository.remove(user);
  }

  async areFriends(a: string, b: string): Promise<boolean> {
    const rows = await this.dataSource.query(
      `SELECT 1 FROM friend_requests
       WHERE status = 'accepted'
         AND ((requester_id = $1 AND addressee_id = $2)
           OR (requester_id = $2 AND addressee_id = $1))
       LIMIT 1`,
      [a, b],
    );
    return rows.length > 0;
  }

  async profileStats(id: string): Promise<ProfileStats> {
    const rows = await this.dataSource.query(
      `SELECT
         (SELECT count(*) FROM friend_requests fr
            WHERE fr.status = 'accepted'
              AND (fr.requester_id = $1 OR fr.addressee_id = $1))::int AS friends,
         (SELECT count(*) FROM events e WHERE e.organizer_id = $1)::int AS "eventsOrganized",
         (SELECT count(*) FROM event_participants ep
            WHERE ep.user_id = $1 AND ep.status = 'going')::int AS "eventsAttended",
         (SELECT count(*) FROM tracks t
            WHERE t.user_id = $1 AND t.status = 'published')::int AS "tracksPublished",
         (SELECT count(*) FROM listings l
            WHERE l.seller_id = $1 AND l.status = 'active')::int AS "listingsActive",
         (SELECT COALESCE(ROUND(AVG(rr.rating)::numeric, 1), 0)
            FROM listing_reviews rr WHERE rr.target_id = $1)::float8 AS "ratingAverage",
         (SELECT count(*) FROM listing_reviews rr
            WHERE rr.target_id = $1)::int AS "reviewsCount"`,
      [id],
    );
    return rows[0] as ProfileStats;
  }

  async getProfile(viewer: AuthUser, targetId: string): Promise<UserProfileView> {
    const target = await this.findById(targetId);
    const isSelf = viewer.id === target.id;
    const isStaff =
      viewer.role === UserRole.ADMIN || viewer.role === UserRole.MODERATOR;
    const blocked =
      !isSelf && (await this.blocks.blockedEither(viewer.id, target.id));
    const isFriend = isSelf ? false : await this.areFriends(viewer.id, target.id);

    if (blocked) {
      return {
        user: { id: target.id, name: target.name, avatarUrl: target.avatarUrl },
        stats: null,
        canView: false,
        blocked: true,
        isFriend: false,
        isSelf,
      };
    }

    let canView = isSelf || isStaff;
    if (!canView) {
      if (target.profileVisibility === VisibilityScope.PUBLIC) {
        canView = true;
      } else if (target.profileVisibility === VisibilityScope.FRIENDS) {
        canView = isFriend;
      }
    }

    if (!canView) {
      return {
        user: {
          id: target.id,
          name: target.name,
          avatarUrl: target.avatarUrl,
          city: target.city,
        },
        stats: null,
        canView: false,
        blocked: false,
        isFriend,
        isSelf,
      };
    }

    const stats = await this.profileStats(target.id);
    const user: Partial<User> = {
      id: target.id,
      name: target.name,
      avatarUrl: target.avatarUrl,
      city: target.city,
      region: target.region,
      country: target.country,
      bio: target.bio,
      role: target.role,
      xp: target.xp,
      homeWaterBodyId: target.homeWaterBodyId,
      locale: target.locale ?? 'ru',
      createdAt: target.createdAt,
      profileVisibility: target.profileVisibility,
      activityVisibility: target.activityVisibility,
      geoVisibility: target.geoVisibility,
      showOnline: target.showOnline,
    };
    if (target.homeWaterBodyId) {
      const wb = await this.dataSource.query(
        `SELECT id, name, region FROM waterbodies WHERE id = $1`,
        [target.homeWaterBodyId],
      );
      if (wb[0]) {
        user.homeWaterBody = {
          id: wb[0].id,
          name: wb[0].name,
          region: wb[0].region,
        } as unknown as WaterBody;
      }
    }
    if (isSelf || isStaff) {
      user.email = target.email;
      user.phone = target.phone;
    }
    if (isSelf) {
      user.isEmailVerified = target.isEmailVerified;
      user.isBanned = target.isBanned;
    }
    return { user, stats, canView: true, blocked: false, isFriend, isSelf };
  }
}