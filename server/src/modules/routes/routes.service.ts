import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Route, RouteDifficulty } from './route.entity';
import { RoutePoint } from './route-point.entity';
import { User } from '../users/user.entity';
import { WaterBody } from '../waterbodies/waterbody.entity';
import { CreateRouteDto } from './dto/create-route.dto';
import { UpdateRouteDto } from './dto/update-route.dto';

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
  createdAt: Date;
  updatedAt: Date;
}

const EARTH_RADIUS_M = 6371000;

/** Расстояние между двумя точками (Haversine), метры. */
function haversineMeters(a: RouteGeoPoint, b: RouteGeoPoint): number {
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const lat1 = toRad(a.lat);
  const lat2 = toRad(b.lat);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.sin(dLng / 2) ** 2 * Math.cos(lat1) * Math.cos(lat2);
  return 2 * EARTH_RADIUS_M * Math.asin(Math.min(1, Math.sqrt(h)));
}

function distanceAlongLine(points: RouteGeoPoint[]): number {
  let total = 0;
  for (let i = 1; i < points.length; i += 1) {
    total += haversineMeters(points[i - 1], points[i]);
  }
  return Math.round(total);
}

@Injectable()
export class RoutesService {
  constructor(
    @InjectRepository(Route)
    private readonly routeRepository: Repository<Route>,
    @InjectRepository(RoutePoint)
    private readonly pointRepository: Repository<RoutePoint>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    @InjectRepository(WaterBody)
    private readonly waterbodyRepository: Repository<WaterBody>,
  ) {}

  /**
   * Список маршрутов справочника.
   * - аноним: только опубликованные;
   * - авторизованный: опубликованные + собственные (в т.ч. черновики);
   * - админ/модератор с includeAll: вообще все.
   */
  async findAll(
    waterbodyId?: string,
    user?: { id: string; role: string },
    includeAll = false,
    region?: string,
    farEast = false,
  ): Promise<RouteView[]> {
    const isStaff = !!user && (user.role === 'admin' || user.role === 'moderator');
    const conditions: Array<string> = [];
    const params: Record<string, string> = {};
    if (waterbodyId) {
      conditions.push('r.waterbodyId = :waterbodyId');
      params.waterbodyId = waterbodyId;
    }
    if (region) {
      conditions.push('w.region ILIKE :region');
      params.region = `%${region}%`;
    }
    if (farEast) {
      conditions.push(
        `(w.region ILIKE '%Примор%' OR w.region ILIKE '%Камчат%' OR w.region ILIKE '%Сахалин%' OR w.region ILIKE '%Хабаров%' OR w.region ILIKE '%Амур%' OR w.region ILIKE '%Магадан%' OR w.region ILIKE '%Чукот%' OR w.region ILIKE '%Якут%')`,
      );
    }
    if (!includeAll || !isStaff) {
      if (!user) {
        conditions.push('r.published = true');
      } else if (!isStaff) {
        conditions.push('(r.published = true OR r.authorId = :authorId)');
        params.authorId = user.id;
      }
    }
    const where = conditions.length ? conditions.join(' AND ') : undefined;
    const qb = this.routeRepository
      .createQueryBuilder('r')
      .leftJoinAndSelect('r.points', 'p')
      .leftJoinAndSelect('r.waterbody', 'w')
      .leftJoinAndSelect('r.author', 'a');
    if (where) {
      qb.where(where, params);
    }
    const routes = await qb
      .orderBy('r.createdAt', 'DESC')
      .getMany();
    return routes.map((r) => this.toView(r));
  }

  async findById(id: string): Promise<RouteView> {
    const route = await this.routeRepository.findOne({
      where: { id },
      relations: { points: true, waterbody: true, author: true },
    });
    if (!route) {
      throw new NotFoundException(`Route ${id} not found`);
    }
    return this.toView(route);
  }

  async create(authorId: string, dto: CreateRouteDto): Promise<RouteView> {
    const route = this.routeRepository.create({
      name: dto.name,
      description: dto.description ?? null,
      waterbodyId: dto.waterbodyId,
      authorId,
      difficulty: dto.difficulty ?? RouteDifficulty.EASY,
      maxSpeedKph: dto.maxSpeedKph ?? 0,
      expectedDurationMinutes: dto.expectedDurationMinutes ?? null,
      published: dto.published ?? true,
    });
    const saved = await this.routeRepository.save(route);
    await this.replacePoints(saved.id, dto.points);
    await this.persistDistance(saved.id);
    return this.findById(saved.id);
  }

  /** Пересчитывает и сохраняет distance_meters по точкам маршрута. */
  private async persistDistance(id: string): Promise<void> {
    const withPoints = await this.routeRepository.findOne({
      where: { id },
      relations: { points: true },
    });
    if (!withPoints) return;
    const distance = distanceAlongLine(withPoints.points ?? []);
    if (distance !== withPoints.distanceMeters) {
      withPoints.distanceMeters = distance;
      await this.routeRepository.save(withPoints);
    }
  }

  /** Редактирует только автор или администратор. */
  async update(
    id: string,
    current: { id: string; role: string },
    dto: UpdateRouteDto,
  ): Promise<RouteView> {
    const route = await this.routeRepository.findOne({ where: { id } });
    if (!route) {
      throw new NotFoundException(`Route ${id} not found`);
    }
    this.assertCanEdit(route, current);

    if (dto.name !== undefined) route.name = dto.name;
    if (dto.description !== undefined) route.description = dto.description;
    if (dto.waterbodyId !== undefined) route.waterbodyId = dto.waterbodyId;
    if (dto.difficulty !== undefined) route.difficulty = dto.difficulty;
    if (dto.maxSpeedKph !== undefined) route.maxSpeedKph = dto.maxSpeedKph;
    if (dto.expectedDurationMinutes !== undefined)
      route.expectedDurationMinutes = dto.expectedDurationMinutes;
    if (dto.published !== undefined) route.published = dto.published;
    await this.routeRepository.save(route);

    if (dto.points) {
      await this.replacePoints(id, dto.points);
      await this.persistDistance(id);
    }
    return this.findById(id);
  }

  /** Удаляет только автор или администратор. */
  async remove(
    id: string,
    current: { id: string; role: string },
  ): Promise<{ ok: boolean }> {
    const route = await this.routeRepository.findOne({ where: { id } });
    if (!route) {
      throw new NotFoundException(`Route ${id} not found`);
    }
    this.assertCanEdit(route, current);
    await this.routeRepository.remove(route);
    return { ok: true };
  }

  private assertCanEdit(
    route: Route,
    current: { id: string; role: string },
  ): void {
    if (route.authorId === current.id || current.role === 'admin') {
      return;
    }
    throw new ForbiddenException(
      'Only the route author or an admin can edit this route',
    );
  }

  private async replacePoints(
    routeId: string,
    points: RouteGeoPoint[],
  ): Promise<void> {
    await this.pointRepository.delete({ routeId });
    const rows = points.map((p, i) =>
      this.pointRepository.create({
        routeId,
        lat: p.lat,
        lng: p.lng,
        seq: i + 1,
      }),
    );
    if (rows.length) {
      await this.pointRepository.save(rows);
    }
  }

  private toView(route: Route): RouteView {
    const points: RouteGeoPoint[] = (route.points ?? [])
      .slice()
      .sort((a, b) => a.seq - b.seq)
      .map((p) => ({ lat: p.lat, lng: p.lng }));
    return {
      id: route.id,
      name: route.name,
      description: route.description,
      waterbodyId: route.waterbodyId,
      waterbody: route.waterbody
        ? {
            id: route.waterbody.id,
            name: route.waterbody.name,
            region: route.waterbody.region,
          }
        : null,
      authorId: route.authorId,
      author: route.author
        ? {
            id: route.author.id,
            name: route.author.name,
            avatarUrl: route.author.avatarUrl,
          }
        : null,
      distanceMeters: distanceAlongLine(points),
      difficulty: route.difficulty,
      maxSpeedKph: route.maxSpeedKph ?? 0,
      expectedDurationMinutes: route.expectedDurationMinutes ?? null,
      published: route.published,
      points,
      startPoint: points[0] ?? null,
      finishPoint: points.length ? points[points.length - 1] : null,
      createdAt: route.createdAt,
      updatedAt: route.updatedAt,
    };
  }
}
