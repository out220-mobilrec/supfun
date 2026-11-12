import { Column, Entity, PrimaryColumn } from 'typeorm';

/**
 * Справочник стран (ISO 3166-1 alpha-2).
 * Заполняется сидом из ReferenceService, источник — датасет mledoze/countries.
 */
@Entity('countries')
export class Country {
  @PrimaryColumn({ name: 'code', type: 'varchar', length: 2 })
  code: string;

  @Column({ type: 'varchar', length: 120 })
  name: string;

  @Column({ name: 'name_en', type: 'varchar', length: 120 })
  nameEn: string;
}
