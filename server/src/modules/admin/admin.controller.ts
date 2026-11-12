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
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { AdminService } from './admin.service';
import { AdminListQueryDto } from './dto/admin-query.dto';
import {
  EventStatusDto,
  ListingStatusDto,
  SetActiveDto,
  SetRoleDto,
  TrackStatusDto,
} from './dto/status.dto';
import {
  CreateWaterbodyDto,
  UpdateWaterbodyDto,
} from './dto/waterbody.dto';
import { AdminUpdateEventDto } from './dto/event.dto';
import { EventStatsQueryDto } from './dto/event-stats.dto';

@Controller('admin')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('admin', 'moderator')
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  @Get('stats')
  stats() {
    return this.adminService.stats();
  }

  @Get('events/stats')
  eventStats(@Query() query: EventStatsQueryDto) {
    return this.adminService.eventStats(query.from, query.to);
  }

  // ---------- users ----------

  @Get('users')
  listUsers(@Query() query: AdminListQueryDto) {
    return this.adminService.listUsers(
      query.q,
      query.role,
      query.limit,
      query.offset,
    );
  }

  @Patch('users/:id/role')
  @Roles('admin')
  setRole(@Param('id') id: string, @Body() dto: SetRoleDto) {
    return this.adminService.setRole(id, dto.role as never);
  }

  @Post('users/:id/ban')
  @Roles('admin')
  ban(@Param('id') id: string) {
    return this.adminService.ban(id);
  }

  @Post('users/:id/unban')
  @Roles('admin')
  unban(@Param('id') id: string) {
    return this.adminService.unban(id);
  }

  // ---------- listings ----------

  @Get('listings')
  listListings(@Query() query: AdminListQueryDto) {
    return this.adminService.listListings(
      query.status,
      query.q,
      query.limit,
      query.offset,
    );
  }

  @Patch('listings/:id/status')
  setListingStatus(@Param('id') id: string, @Body() dto: ListingStatusDto) {
    return this.adminService.setListingStatus(id, dto.status as never);
  }

  // ---------- events ----------

  @Get('events')
  listEvents(@Query() query: AdminListQueryDto) {
    return this.adminService.listEvents(
      query.status,
      query.q,
      query.limit,
      query.offset,
    );
  }

  @Patch('events/:id/status')
  setEventStatus(@Param('id') id: string, @Body() dto: EventStatusDto) {
    return this.adminService.setEventStatus(id, dto.status as never);
  }

  @Patch('events/:id')
  @Roles('admin')
  updateEvent(@Param('id') id: string, @Body() dto: AdminUpdateEventDto) {
    return this.adminService.updateEvent(id, dto);
  }

  @Delete('events/:id')
  @Roles('admin')
  deleteEvent(@Param('id') id: string) {
    return this.adminService.deleteEvent(id);
  }

  // ---------- tracks ----------

  @Get('tracks')
  listTracks(@Query() query: AdminListQueryDto) {
    return this.adminService.listTracks(
      query.status,
      query.q,
      query.limit,
      query.offset,
    );
  }

  @Patch('tracks/:id/status')
  setTrackStatus(@Param('id') id: string, @Body() dto: TrackStatusDto) {
    return this.adminService.setTrackStatus(id, dto.status as never);
  }

  // ---------- waterbodies ----------

  @Get('waterbodies')
  listWaterbodies(
    @Query('q') q?: string,
    @Query('active') active?: string,
  ) {
    const activeFilter = active === undefined ? undefined : active === 'true';
    return this.adminService.listWaterbodies(q, activeFilter);
  }

  @Post('waterbodies')
  createWaterbody(@Body() dto: CreateWaterbodyDto) {
    return this.adminService.createWaterbody(dto);
  }

  @Patch('waterbodies/:id')
  updateWaterbody(
    @Param('id') id: string,
    @Body() dto: UpdateWaterbodyDto,
  ) {
    return this.adminService.updateWaterbody(id, dto);
  }

  @Patch('waterbodies/:id/active')
  setWaterbodyActive(@Param('id') id: string, @Body() dto: SetActiveDto) {
    return this.adminService.setWaterbodyActive(id, dto.active);
  }

  @Delete('waterbodies/:id')
  @Roles('admin')
  deleteWaterbody(@Param('id') id: string) {
    return this.adminService.deleteWaterbody(id);
  }
}