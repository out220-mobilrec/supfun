import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

export enum DevicePlatform {
  ANDROID = 'android',
  IOS = 'ios',
  WEB = 'web',
}

@Entity('device_tokens')
@Index('device_tokens_user_idx', ['userId'])
export class DeviceToken {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id', type: 'uuid' })
  userId: string;

  @Column({ type: 'varchar', length: 1024, unique: true })
  token: string;

  @Column({ type: 'enum', enum: DevicePlatform, default: DevicePlatform.ANDROID })
  platform: DevicePlatform;

  @UpdateDateColumn({ name: 'last_used_at', type: 'timestamptz' })
  lastUsedAt: Date;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}