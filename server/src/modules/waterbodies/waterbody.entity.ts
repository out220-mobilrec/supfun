import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

@Entity('waterbodies')
@Index('waterbodies_location_idx', { synchronize: false })
export class WaterBody {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 200 })
  name: string;

  @Column({ type: 'text', nullable: true })
  description: string | null;

  @Column({ type: 'varchar', length: 100, nullable: true })
  region: string | null;

  /**
   * PostGIS geography Point (WGS84, SRID 4326).
   * Stored as raw geometry; queried via ST_ helpers.
   */
  @Column({
    type: 'geometry',
    spatialFeatureType: 'Point',
    srid: 4326,
    nullable: true,
  })
  location: unknown;

  @Column({ type: 'boolean', default: true })
  active: boolean;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;

  /** Не колонка — подставляется из location (ST_Y) в сервисе. */
  latitude?: number | null;

  /** Не колонка — подставляется из location (ST_X) в сервисе. */
  longitude?: number | null;
}
