import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  OneToMany,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { User } from '../users/user.entity';
import { WaterBody } from '../waterbodies/waterbody.entity';
import { RoutePoint } from './route-point.entity';

export enum RouteDifficulty {
  EASY = 'easy',
  MEDIUM = 'medium',
  HARD = 'hard',
}

/**
 * Запись справочника маршрутов — публичный, курируемый маршрут по воде.
 * Не путать с Track (персональная GPS-запись заплыва).
 *
 * Геометрия хранится в points[] (по порядку): первый элемент — точка старта,
 * последний — точка финиша.
 */
@Entity('routes')
@Index('routes_waterbody_idx', ['waterbodyId'])
@Index('routes_author_idx', ['authorId'])
export class Route {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 200 })
  name: string;

  @Column({ type: 'text', nullable: true })
  description: string | null;

  @Column({ name: 'waterbody_id', type: 'uuid' })
  waterbodyId: string;

  @ManyToOne(() => WaterBody, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'waterbody_id' })
  waterbody: WaterBody;

  @Column({ name: 'author_id', type: 'uuid' })
  authorId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'author_id' })
  author: User;

  @Column({
    name: 'distance_meters',
    type: 'int',
    default: 0,
  })
  distanceMeters: number;

  @Column({
    name: 'difficulty',
    type: 'enum',
    enum: RouteDifficulty,
    default: RouteDifficulty.EASY,
  })
  difficulty: RouteDifficulty;

  /** Максимальная (рабочая) скорость прохождения, км/ч. */
  @Column({ name: 'max_speed_kph', type: 'double precision', default: 0 })
  maxSpeedKph: number;

  /** Ожидаемое время прохождения маршрута, минут. */
  @Column({ name: 'expected_duration_minutes', type: 'int', nullable: true })
  expectedDurationMinutes: number | null;

  /** Показывать в публичном списке справочника. */
  @Column({ type: 'boolean', default: true })
  published: boolean;

  @OneToMany(() => RoutePoint, (point) => point.route, {
    cascade: true,
  })
  points: RoutePoint[];

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}
