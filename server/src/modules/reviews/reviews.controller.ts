import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../../common/decorators/current-user.decorator';
import { Review, ReviewTargetType } from './review.entity';
import { ReviewsService, ReviewSummary } from './reviews.service';
import { CreateReviewDto, UpdateReviewDto } from './dto/review.dto';

/** Отзывы на маршруты и заплывы. */
@UseGuards(JwtAuthGuard)
@Controller('reviews')
export class ReviewsController {
  constructor(private readonly service: ReviewsService) {}

  @Get()
  list(
    @Query('targetType') targetType: ReviewTargetType,
    @Query('targetId') targetId: string,
  ): Promise<Review[]> {
    return this.service.list(targetType, targetId);
  }

  @Get('summary')
  summary(
    @Query('targetType') targetType: ReviewTargetType,
    @Query('targetId') targetId: string,
  ): Promise<ReviewSummary> {
    return this.service.summary(targetType, targetId);
  }

  /** Создать или обновить свой отзыв о маршруте/заплыве. */
  @Post()
  create(@CurrentUser() current: AuthUser, @Body() dto: CreateReviewDto): Promise<Review> {
    return this.service.upsert(current.id, dto);
  }

  @Patch(':id')
  update(
    @CurrentUser() current: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdateReviewDto,
  ): Promise<Review> {
    return this.service.update(id, current, dto);
  }

  @Delete(':id')
  remove(
    @CurrentUser() current: AuthUser,
    @Param('id') id: string,
  ): Promise<{ ok: boolean }> {
    return this.service.remove(id, current);
  }
}
