import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { WaterBody } from './waterbody.entity';

export interface NearbyWaterBody {
  id: string;
  name: string;
  region: string | null;
  distance_meters: number;
}

@Injectable()
export class WaterbodiesService {
  constructor(
    @InjectRepository(WaterBody)
    private readonly repository: Repository<WaterBody>,
  ) {}

  async findAll(
    query?: string,
    limit = 50,
    offset = 0,
    region?: string,
    farEast?: boolean,
  ): Promise<WaterBody[]> {
    const take = Math.min(Math.max(limit, 1), 100);
    const skip = Math.max(offset, 0);
    const qb = this.repository
      .createQueryBuilder('wb')
      .addSelect('ST_Y(wb.location)', 'latitude')
      .addSelect('ST_X(wb.location)', 'longitude')
      .where('1=1')
      .orderBy('wb.name', 'ASC')
      .take(take)
      .skip(skip);
    if (query) {
      qb.andWhere(`(wb.name ILIKE :q OR wb.region ILIKE :q)`, { q: `%${query}%` });
    }
    if (region) {
      qb.andWhere(`wb.region ILIKE :region`, { region: `%${region}%` });
    }
    if (farEast) {
      qb.andWhere(
        `(wb.region ILIKE '%Примор%' OR wb.region ILIKE '%Камчат%' OR wb.region ILIKE '%Сахалин%' OR wb.region ILIKE '%Хабаров%' OR wb.region ILIKE '%Амур%' OR wb.region ILIKE '%Магадан%' OR wb.region ILIKE '%Чукот%' OR wb.region ILIKE '%Якут%')`,
      );
    }
    const { entities, raw } = await qb.getRawAndEntities();
    return entities.map((entity, i) => ({
      ...entity,
      latitude: Number(raw[i].latitude) || null,
      longitude: Number(raw[i].longitude) || null,
    })) as WaterBody[];
  }

  async findById(id: string): Promise<WaterBody> {
    const { entities, raw } = await this.repository
      .createQueryBuilder('wb')
      .addSelect('ST_Y(wb.location)', 'latitude')
      .addSelect('ST_X(wb.location)', 'longitude')
      .where('wb.id = :id', { id })
      .getRawAndEntities();
    const waterBody = entities[0];
    if (!waterBody) {
      throw new NotFoundException(`WaterBody ${id} not found`);
    }
    return {
      ...waterBody,
      latitude: Number(raw[0].latitude) || null,
      longitude: Number(raw[0].longitude) || null,
    };
  }

  /**
   * Water bodies within `radiusMeters` of the given point (PostGIS ST_DWithin).
   */
  async findNearby(
    lat: number,
    lng: number,
    radiusMeters = 20000,
  ): Promise<NearbyWaterBody[]> {
    return this.repository.query(
      `SELECT id, name, region,
              ST_Distance(location, ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography) AS distance_meters
       FROM waterbodies
       WHERE active = true
         AND location IS NOT NULL
         AND ST_DWithin(location, ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography, $3)
       ORDER BY distance_meters ASC
       LIMIT 50`,
      [lat, lng, radiusMeters],
    );
  }
}
