import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../../common/decorators/current-user.decorator';
import { TracksService, EventTrackSummary } from './tracks.service';
import { AwardResult } from '../gamification/gamification.service';
import { Track } from './track.entity';
import { TrackPoint } from './track-point.entity';
import {
  AppendGpsPointsDto,
  CompleteTrackDto,
  StartEventTrackDto,
} from './dto/track.dto';

/**
 * Треки участников заплыва — подчинённый справочник заплыва.
 *
 * Контракт для мобильного приложения:
 *   1. POST /events/:id/tracks                       — старт записи (идемпотентно)
 *   2. POST /events/:id/tracks/:trackId/points       — пачка точек {points:[{seq,lat,lng,recordedAt}]}
 *      повторная отправка того же seq безопасна — дубли отбрасываются;
 *   3. POST /events/:id/tracks/:trackId/finish       — финиш, пересчёт статистики и XP.
 */
@UseGuards(JwtAuthGuard)
@Controller('events/:eventId/tracks')
export class EventTracksController {
  constructor(private readonly service: TracksService) {}

  /** Список треков участников заплыва. */
  @Get()
  async list(
    @CurrentUser() current: AuthUser,
    @Param('eventId') eventId: string,
  ): Promise<EventTrackSummary[]> {
    await this.service.assertEventParticipant(eventId, current.id);
    return this.service.listByEvent(eventId);
  }

  /** Старт или продолжение записи своего трека. */
  @Post()
  start(
    @CurrentUser() current: AuthUser,
    @Param('eventId') eventId: string,
    @Body() dto: StartEventTrackDto,
  ): Promise<Track> {
    return this.service.startForEvent(eventId, current, dto);
  }

  /** Точки конкретного трека (для отрисовки на карте). */
  @Get(':trackId/points')
  async points(
    @CurrentUser() current: AuthUser,
    @Param('eventId') eventId: string,
    @Param('trackId') trackId: string,
  ): Promise<TrackPoint[]> {
    await this.service.assertEventParticipant(eventId, current.id);
    return this.service.getPoints(trackId, current);
  }

  /** Догрузка пачки точек; повторные seq игнорируются. */
  @Post(':trackId/points')
  appendPoints(
    @CurrentUser() current: AuthUser,
    @Param('trackId') trackId: string,
    @Body() dto: AppendGpsPointsDto,
  ): Promise<{ added: number; skipped: number; total: number }> {
    return this.service.appendGpsPoints(trackId, current, dto.points);
  }

  /** Финиш: статистика, XP, закрытие связанного заплыва. */
  @Post(':trackId/finish')
  finish(
    @CurrentUser() current: AuthUser,
    @Param('eventId') eventId: string,
    @Param('trackId') trackId: string,
    @Body() dto: CompleteTrackDto,
  ): Promise<{ track: Track; award: AwardResult }> {
    return this.service.finishForEvent(eventId, trackId, current, dto);
  }
}
