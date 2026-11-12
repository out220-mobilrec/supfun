import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  Unique,
} from 'typeorm';

@Entity('user_achievements')
@Unique(['userId', 'achievementCode'])
@Index('user_achievements_user_idx', ['userId'])
export class UserAchievement {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id', type: 'uuid' })
  userId: string;

  @Column({ name: 'achievement_code', type: 'varchar', length: 64 })
  achievementCode: string;

  @CreateDateColumn({ name: 'unlocked_at', type: 'timestamptz' })
  unlockedAt: Date;
}