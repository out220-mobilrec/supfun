import { Injectable, Logger, OnApplicationBootstrap } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Country } from './country.entity';
import { COUNTRIES } from './data/countries.data';

/** Страна по умолчанию для профилей без указанной страны. */
export const DEFAULT_COUNTRY_CODE = 'RU';

@Injectable()
export class ReferenceService implements OnApplicationBootstrap {
  private readonly logger = new Logger(ReferenceService.name);

  constructor(
    @InjectRepository(Country)
    private readonly countriesRepository: Repository<Country>,
  ) {}

  /**
   * Страны — неизменяемые reference-данные: досеиваем их при старте,
   * если таблицы не было или в датасете появились/изменились коды.
   */
  async onApplicationBootstrap(): Promise<void> {
    try {
      const changed = await this.seedCountries();
      if (changed > 0) {
        this.logger.log(`Countries reference updated: ${changed} row(s)`);
      }
    } catch (err) {
      this.logger.error(`Countries seed failed: ${(err as Error).message}`);
    }
  }

  /**
   * Идемпотентный upsert справочника: пишем только реально новые/изменённые строки,
   * чтобы не гонять 250 записей на каждом старте.
   * Возвращает число записей, которые пришлось изменить.
   */
  async seedCountries(): Promise<number> {
    const existing = await this.countriesRepository.find();
    const byCode = new Map(existing.map((c) => [c.code, c]));

    const pending = COUNTRIES.filter((row) => {
      const current = byCode.get(row.code);
      return (
        !current || current.name !== row.name || current.nameEn !== row.nameEn
      );
    });

    for (const row of pending) {
      await this.countriesRepository
        .createQueryBuilder()
        .insert()
        .into(Country)
        .values(row)
        .orUpdate(['name', 'name_en'], ['code'])
        .execute();
    }
    return pending.length;
  }

  async listCountries(): Promise<Country[]> {
    return this.countriesRepository.find({ order: { name: 'ASC' } });
  }

  async findCountry(code: string): Promise<Country | null> {
    if (!code) return null;
    return this.countriesRepository.findOne({ where: { code: code.toUpperCase() } });
  }

  /** Валидация значения страны: принимаем только ISO 3166-1 alpha-2 из справочника. */
  async isValidCountryCode(code: string): Promise<boolean> {
    return (await this.findCountry(code)) !== null;
  }
}
