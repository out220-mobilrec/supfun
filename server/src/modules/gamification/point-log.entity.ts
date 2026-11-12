import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  Unique,
} from 'typeorm';

@Entity('point_logs')
@Index('point_logs_user_idx', ['userId'])
export class PointLog {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id', type: 'uuid' })
  userId: string;

  @Column({ type: 'varchar', length: 50 })
  action: string;

  @Column({ type: 'int' })
  points: number;

  @Column({ name: 'ref_type', type: 'varchar', length: 30, nullable: true })
  refType: string | null;

  @Column({ name: 'ref_id', type: 'varchar', length: 64, nullable: true })
  refId: string | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}