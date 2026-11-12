import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { User } from '../users/user.entity';

export enum GearCategory {
  BOARD = 'board',
  PADDLE = 'paddle',
  WETSUIT = 'wetsuit',
  VEST = 'vest',
  LEASH = 'leash',
  PUMP = 'pump',
  DRYBAG = 'drybag',
  OTHER = 'other',
}

@Entity('gear_items')
@Index('gear_items_user_idx', ['userId'])
export class GearItem {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id', type: 'uuid' })
  userId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ type: 'enum', enum: GearCategory })
  category: GearCategory;

  @Column({ type: 'varchar', length: 100, nullable: true })
  brand: string | null;

  @Column({ type: 'varchar', length: 100, nullable: true })
  model: string | null;

  @Column({ name: 'length_cm', type: 'int', nullable: true })
  lengthCm: number | null;

  @Column({ name: 'width_cm', type: 'int', nullable: true })
  widthCm: number | null;

  @Column({ name: 'volume_l', type: 'int', nullable: true })
  volumeL: number | null;

  @Column({ name: 'weight_kg', type: 'numeric', precision: 5, scale: 1, nullable: true })
  weightKg: number | null;

  @Column({ type: 'varchar', length: 100, nullable: true })
  material: string | null;

  @Column({ type: 'text', nullable: true })
  notes: string | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}