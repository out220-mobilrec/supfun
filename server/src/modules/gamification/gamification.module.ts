import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UsersModule } from '../users/users.module';
import { PointLog } from './point-log.entity';
import { UserAchievement } from './user-achievement.entity';
import { GamificationService } from './gamification.service';
import { GamificationController } from './gamification.controller';

@Module({
  imports: [TypeOrmModule.forFeature([PointLog, UserAchievement]), UsersModule],
  controllers: [GamificationController],
  providers: [GamificationService],
  exports: [GamificationService],
})
export class GamificationModule {}