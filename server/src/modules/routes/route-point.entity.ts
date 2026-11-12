import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { Route } from './route.entity';

/**
 * Точка геометрии маршрута. Хранятся по порядку в seq:
 * seq=1 — старт, seq=N — финиш.
 */
@Entity('route_points')
@Index('route_points_route_idx', ['routeId'])
export class RoutePoint {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'route_id', type: 'uuid' })
  routeId: string;

  @ManyToOne(() => Route, (route) => route.points, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'route_id' })
  route: Route;

  @Column({ type: 'double precision' })
  lat: number;

  @Column({ type: 'double precision' })
  lng: number;

  /** Порядок точки на линии (1 = старт, N = финиш). */
  @Column({ type: 'int' })
  seq: number;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
