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
import { EventsService } from './events.service';
import { Event } from './event.entity';
import { EventParticipant, ParticipantStatus } from './event-participant.entity';
import { EventInvite } from './event-invite.entity';
import { CreateEventDto } from './dto/create-event.dto';
import { UpdateEventDto } from './dto/update-event.dto';
import { JoinEventDto } from './dto/join-event.dto';
import { InviteParticipantsDto } from './dto/invite-participants.dto';
import { UpdateParticipantDto } from './dto/update-participant.dto';

@UseGuards(JwtAuthGuard)
@Controller('events')
export class EventsController {
  constructor(private readonly service: EventsService) {}

  @Post()
  create(@CurrentUser() current: AuthUser, @Body() dto: CreateEventDto): Promise<Event> {
    return this.service.create(current.id, dto);
  }

  @Get()
  list(
    @CurrentUser() current: AuthUser,
    @Query('status') status?: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
    @Query('date') date?: string,
    @Query('waterBodyId') waterBodyId?: string,
    @Query('trackId') trackId?: string,
    @Query('level') level?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ): Promise<Event[]> {
    return this.service.findAll(
      {
        status,
        from,
        to,
        date,
        waterBodyId,
        trackId,
        level,
        limit: limit ? Number(limit) : undefined,
        offset: offset ? Number(offset) : undefined,
      } as any,
      current.id,
    );
  }

  @Get('nearby')
  nearby(
    @Query('lat') lat: string,
    @Query('lng') lng: string,
    @Query('radius') radius?: string,
  ) {
    return this.service.nearby(Number(lat), Number(lng), radius ? Number(radius) : undefined);
  }

  @Get('mine/:status')
  mine(
    @CurrentUser() current: AuthUser,
    @Param('status') status: ParticipantStatus,
  ): Promise<Event[]> {
    return this.service.myEvents(current.id, status);
  }

  @Get(':id')
  get(@CurrentUser() current: AuthUser, @Param('id') id: string): Promise<Event> {
    return this.service.findById(id, current.id);
  }

  @Patch(':id')
  update(
    @CurrentUser() current: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdateEventDto,
  ): Promise<Event> {
    return this.service.update(id, current.id, dto);
  }

  @Delete(':id')
  cancel(@CurrentUser() current: AuthUser, @Param('id') id: string): Promise<{ ok: boolean }> {
    return this.service.cancel(id, current.id);
  }

  @Post(':id/join')
  join(
    @CurrentUser() current: AuthUser,
    @Param('id') id: string,
    @Body() dto: JoinEventDto,
  ): Promise<EventParticipant> {
    return this.service.setParticipant(id, current.id, dto.status ?? ParticipantStatus.GOING);
  }

  @Get(':id/participants')
  participants(
    @CurrentUser() current: AuthUser,
    @Param('id') id: string,
    @Query('status') status?: ParticipantStatus,
  ): Promise<EventParticipant[]> {
    return this.service.participants(id, current.id, status);
  }

  @Patch(':id/participants/:userId')
  manageParticipant(
    @CurrentUser() current: AuthUser,
    @Param('id') id: string,
    @Param('userId') userId: string,
    @Body() dto: UpdateParticipantDto,
  ): Promise<EventParticipant> {
    return this.service.organizerSetParticipant(id, current.id, userId, dto.status);
  }

  @Delete(':id/participants/:userId')
  removeParticipant(
    @CurrentUser() current: AuthUser,
    @Param('id') id: string,
    @Param('userId') userId: string,
  ): Promise<{ ok: boolean }> {
    return this.service.removeParticipant(id, current.id, userId);
  }

  @Post(':id/invites')
  invite(
    @CurrentUser() current: AuthUser,
    @Param('id') id: string,
    @Body() dto: InviteParticipantsDto,
  ): Promise<EventInvite[]> {
    return this.service.invite(id, current.id, dto.userIds);
  }

  @Get(':id/invites')
  listInvites(
    @CurrentUser() current: AuthUser,
    @Param('id') id: string,
  ): Promise<EventInvite[]> {
    return this.service.listInvites(id, current.id);
  }

  @Delete(':id/invites/:userId')
  revokeInvite(
    @CurrentUser() current: AuthUser,
    @Param('id') id: string,
    @Param('userId') userId: string,
  ): Promise<{ ok: boolean }> {
    return this.service.revokeInvite(id, current.id, userId);
  }
}