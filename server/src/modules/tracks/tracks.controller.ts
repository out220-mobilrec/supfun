import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../../common/decorators/current-user.decorator';
import { TracksService } from './tracks.service';
import { Track } from './track.entity';
import { TrackPoint } from './track-point.entity';
import {
  AddPointsDto,
  CompleteTrackDto,
  CreateTrackDto,
  ReplacePointsDto,
  TrackQueryDto,
  UpdateTrackDto,
} from './dto/track.dto';

@UseGuards(JwtAuthGuard)
@Controller('tracks')
export class TracksController {
  constructor(private readonly service: TracksService) {}

  @Post()
  create(@CurrentUser() current: AuthUser, @Body() dto: CreateTrackDto): Promise<Track> {
    return this.service.create(current.id, dto);
  }

  @Get('mine')
  mine(@CurrentUser() current: AuthUser): Promise<Track[]> {
    return this.service.listMine(current.id);
  }

  @Get()
  list(@CurrentUser() current: AuthUser, @Query() query: TrackQueryDto): Promise<Track[]> {
    return this.service.list(query, current);
  }

  @Get(':id')
  get(@CurrentUser() current: AuthUser, @Param('id') id: string): Promise<Track> {
    return this.service.findById(id, current);
  }

  @Patch(':id')
  update(
    @CurrentUser() current: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdateTrackDto,
  ): Promise<Track> {
    return this.service.update(id, current, dto);
  }

  @Post(':id/points')
  addPoints(
    @CurrentUser() current: AuthUser,
    @Param('id') id: string,
    @Body() dto: AddPointsDto,
  ): Promise<{ added: number }> {
    return this.service.addPoints(id, current, dto.points);
  }

  @Get(':id/points')
  getPoints(
    @CurrentUser() current: AuthUser,
    @Param('id') id: string,
  ): Promise<TrackPoint[]> {
    return this.service.getPoints(id, current);
  }

  @Put(':id/points')
  replacePoints(
    @CurrentUser() current: AuthUser,
    @Param('id') id: string,
    @Body() dto: ReplacePointsDto,
    @Query('recalc') recalc?: string,
  ): Promise<{ replaced: number; track: Track }> {
    // recalc=false — сохранить точки, не трогая статистику (ручные правки в редакторе)
    return this.service.replacePoints(id, current, dto.points, recalc !== 'false');
  }

  @Post(':id/complete')
  complete(
    @CurrentUser() current: AuthUser,
    @Param('id') id: string,
    @Body() dto: CompleteTrackDto,
  ) {
    return this.service.complete(id, current, dto);
  }

  @Post(':id/publish')
  publish(@CurrentUser() current: AuthUser, @Param('id') id: string): Promise<Track> {
    return this.service.publish(id, current);
  }

  @Delete(':id')
  remove(@CurrentUser() current: AuthUser, @Param('id') id: string): Promise<{ ok: boolean }> {
    return this.service.remove(id, current);
  }
}