import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { Track } from './track.entity';

@Entity('track_points')
@Index('track_points_track_idx', ['trackId'])
// Идемпотентность загрузки с мобильного: повтор той же точки с тем же seq не дублируется
@Index('track_points_track_seq_idx', ['trackId', 'seq'], {
  unique: true,
  where: '"seq" IS NOT NULL',
})
export class TrackPoint {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'track_id', type: 'uuid' })
  trackId: string;

  @ManyToOne(() => Track, (track) => track.points, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'track_id' })
  track: Track;

  /**
   * Порядковый номер точки в записью клиента (0,1,2…). Нужен, чтобы
   * повторная отправка пакета после обрыва сети не создавала дублей.
   */
  @Column({ type: 'int', nullable: true })
  seq: number | null;

  @Column({ type: 'double precision' })
  lat: number;

  @Column({ type: 'double precision' })
  lng: number;

  @Column({ type: 'double precision', nullable: true })
  altitude: number | null;

  @Column({ name: 'speed_kph', type: 'double precision', nullable: true })
  speedKph: number | null;

  @Column({ name: 'recorded_at', type: 'timestamptz' })
  recordedAt: Date;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}