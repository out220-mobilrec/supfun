import {
  Controller,
  Get,
  Query,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import {
  CurrentUser,
  type AuthUser,
} from '../../common/decorators/current-user.decorator';
import { RatingsService, RatingScope } from './ratings.service';

@Controller('ratings')
@UseGuards(JwtAuthGuard)
export class RatingsController {
  constructor(private readonly ratingsService: RatingsService) {}

  @Get('leaderboard')
  leaderboard(
    @CurrentUser() me: AuthUser,
    @Query('scope') scope?: RatingScope,
    @Query('limit') limit?: string,
  ) {
    return this.ratingsService.leaderboard(
      me.id,
      scope ?? 'all',
      limit ? Number(limit) : undefined,
    );
  }
}