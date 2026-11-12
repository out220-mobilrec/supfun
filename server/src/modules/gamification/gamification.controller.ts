import { Controller, Get, UseGuards } from '@nestjs/common';
import { Public } from '../../common/decorators/public.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../../common/decorators/current-user.decorator';
import {
  GamificationService,
  GamificationRules,
  LevelInfo,
  AchievementDef,
} from './gamification.service';
import { PointLog } from './point-log.entity';
import { UserAchievement } from './user-achievement.entity';

@UseGuards(JwtAuthGuard)
@Controller('gamification')
export class GamificationController {
  constructor(private readonly service: GamificationService) {}

  /** Правила начисления XP и порогов уровней — доступны без авторизации. */
  @Public()
  @Get('rules')
  rules(): GamificationRules {
    return this.service.rules();
  }

  @Get('me')
  me(@CurrentUser() current: AuthUser): Promise<LevelInfo> {
    return this.service.levelInfo(current.id);
  }

  @Get('points')
  points(@CurrentUser() current: AuthUser): Promise<PointLog[]> {
    return this.service.journal(current.id);
  }

  @Get('achievements')
  achievements(@CurrentUser() current: AuthUser) {
    return this.service.listAchievements(current.id);
  }
}