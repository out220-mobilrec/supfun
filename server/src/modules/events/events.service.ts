import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { Brackets, In, Repository } from 'typeorm';
import {
  Event,
  EventAccess,
  EventLevel,
  EventStatus,
  EventVisibility,
} from './event.entity';
import {
  EventParticipant,
  ParticipantStatus,
} from './event-participant.entity';
import {
  EventInvite,
  EventInviteStatus,
} from './event-invite.entity';
import { CreateEventDto } from './dto/create-event.dto';
import { UpdateEventDto } from './dto/update-event.dto';
import { Track } from '../tracks/track.entity';
import { GamificationService } from '../gamification/gamification.service';
import { FriendsService } from '../friends/friends.service';
import { MessagesService } from '../messages/messages.service';
import { ConversationType } from '../messages/conversation.entity';

export interface NearbyEvent {
  id: string;
  title: string;
  event_date: string;
  status: string;
  distance_meters: number;
}

export interface EventFilters {
  status?: EventStatus;
  from?: string;
  to?: string;
  /** Конкретный день заплыва (YYYY-MM-DD, локальная дата). */
  date?: string;
  waterBodyId?: string;
  trackId?: string;
  organizerId?: string;
  level?: EventLevel;
  limit?: number;
  offset?: number;
}

@Injectable()
export class EventsService {
  constructor(
    @InjectRepository(Event)
    private readonly eventsRepository: Repository<Event>,
    @InjectRepository(EventParticipant)
    private readonly participantsRepository: Repository<EventParticipant>,
    @InjectRepository(EventInvite)
    private readonly invitesRepository: Repository<EventInvite>,
    @InjectRepository(Track)
    private readonly tracksRepository: Repository<Track>,
    private readonly gamificationService: GamificationService,
    private readonly friendsService: FriendsService,
    private readonly messagesService: MessagesService,
    private readonly eventEmitter: EventEmitter2,
  ) {}

  async create(organizerId: string, dto: CreateEventDto): Promise<Event> {
    const event = this.eventsRepository.create({
      organizerId,
      title: dto.title,
      description: dto.description ?? null,
      photos: dto.photos ?? [],
      waterBodyId: dto.waterBodyId ?? null,
      eventDate: new Date(dto.eventDate),
      expectedDurationMinutes: dto.expectedDurationMinutes ?? null,
      expectedDistanceMeters: dto.expectedDistanceMeters ?? null,
      level: dto.level ?? undefined,
      visibility: dto.visibility ?? undefined,
      access: dto.access ?? undefined,
      maxParticipants: dto.maxParticipants ?? null,
      startLat: dto.startPoint?.lat ?? null,
      startLng: dto.startPoint?.lng ?? null,
    });
    const saved = await this.eventsRepository.save(event);
    if (dto.trackId) {
      await this.applyTrack(saved.id, dto.trackId);
    }
    if (dto.startPoint) {
      await this.setStartPoint(saved.id, dto.startPoint.lat, dto.startPoint.lng);
    }
    await this.setParticipant(saved.id, organizerId, ParticipantStatus.GOING);
    await this.gamificationService.award(organizerId, 'event_created', {
      refType: 'event',
      refId: saved.id,
    });
    try {
      await this.messagesService.create(
        {
          type: ConversationType.EVENT,
          eventId: saved.id,
          title: saved.title,
          memberIds: [organizerId],
        },
        organizerId,
      );
    } catch {
      // chat is auxiliary; event creation should not fail because of it
    }
    this.eventEmitter.emit('events.created', {
      organizerId,
      eventId: saved.id,
      title: saved.title,
    });
    return this.findById(saved.id);
  }

  async findAll(
    filters: EventFilters = {},
    viewerId?: string,
  ): Promise<Event[]> {
    const qb = this.eventsRepository
      .createQueryBuilder('event')
      .leftJoinAndSelect('event.organizer', 'organizer')
      .leftJoinAndSelect('event.waterBody', 'waterBody')
      .leftJoinAndSelect('event.track', 'track');

    if (viewerId) {
      const friendIds = await this.friendsService.friendIds(viewerId);
      qb.andWhere(
        new Brackets((where) => {
          where
            .where('event.visibility = :public', {
              public: EventVisibility.PUBLIC,
            })
            .orWhere('event.organizerId = :viewerId', { viewerId })
            .orWhere(
              `EXISTS (SELECT 1 FROM event_participants ep WHERE ep.event_id = event.id AND ep.user_id = :viewerId)`,
              { viewerId },
            )
            .orWhere(
              `EXISTS (SELECT 1 FROM event_invites ei WHERE ei.event_id = event.id AND ei.invitee_id = :viewerId)`,
              { viewerId },
            );
          if (friendIds.length > 0) {
            where.orWhere(
              'event.visibility = :friends AND event.organizerId IN (:...friendIds)',
              { friends: EventVisibility.FRIENDS, friendIds },
            );
          }
        }),
      );
    } else {
      qb.andWhere('event.visibility = :public', {
        public: EventVisibility.PUBLIC,
      });
    }

    if (filters.status) {
      qb.andWhere('event.status = :status', { status: filters.status });
    }
    if (filters.from) {
      qb.andWhere('event.eventDate >= :from', { from: new Date(filters.from) });
    }
    if (filters.to) {
      qb.andWhere('event.eventDate <= :to', { to: new Date(filters.to) });
    }
    if (filters.date) {
      // Фильтр «заплывы в этот день»: берём сутки целиком в локальной дате.
      const day = new Date(`${filters.date}T00:00:00`);
      if (Number.isNaN(day.getTime())) {
        throw new BadRequestException(`Некорректная дата: ${filters.date}`);
      }
      const next = new Date(day.getTime() + 24 * 60 * 60 * 1000);
      qb.andWhere('event.eventDate >= :dayFrom AND event.eventDate < :dayTo', {
        dayFrom: day,
        dayTo: next,
      });
    }
    if (filters.waterBodyId) {
      qb.andWhere('event.waterBodyId = :waterBodyId', {
        waterBodyId: filters.waterBodyId,
      });
    }
    if (filters.trackId) {
      qb.andWhere('event.trackId = :trackId', { trackId: filters.trackId });
    }
    if (filters.organizerId) {
      qb.andWhere('event.organizerId = :organizerId', {
        organizerId: filters.organizerId,
      });
    }
    if (filters.level) {
      qb.andWhere('event.level = :level', { level: filters.level });
    }

    const take = Math.min(Math.max(filters.limit ?? 50, 1), 100);
    const skip = Math.max(filters.offset ?? 0, 0);
    qb.orderBy('event.eventDate', 'ASC').take(take).skip(skip);

    const events = await qb.getMany();
    return this.attachParticipantCounts(events);
  }

  async findById(id: string, viewerId?: string): Promise<Event> {
    const event = await this.eventsRepository.findOne({
      where: { id },
      relations: { organizer: true, waterBody: true, track: true },
    });
    if (!event) {
      throw new NotFoundException(`Event ${id} not found`);
    }
    if (viewerId) {
      await this.assertVisible(event, viewerId);
    }
    const [withCounts] = await this.attachParticipantCounts([event]);
    return withCounts;
  }

  async update(id: string, userId: string, dto: UpdateEventDto): Promise<Event> {
    const event = await this.eventsRepository.findOne({ where: { id } });
    if (!event) {
      throw new NotFoundException(`Event ${id} not found`);
    }
    if (event.organizerId !== userId) {
      throw new ForbiddenException('Only the organizer can edit this event');
    }
    if (dto.title !== undefined) event.title = dto.title;
    if (dto.description !== undefined) event.description = dto.description;
    if (dto.photos !== undefined) event.photos = dto.photos;
    if (dto.waterBodyId !== undefined) event.waterBodyId = dto.waterBodyId;
    if (dto.eventDate !== undefined) event.eventDate = new Date(dto.eventDate);
    if (dto.expectedDurationMinutes !== undefined) {
      event.expectedDurationMinutes = dto.expectedDurationMinutes;
    }
    if (dto.expectedDistanceMeters !== undefined) {
      event.expectedDistanceMeters = dto.expectedDistanceMeters;
    }
    if (dto.level !== undefined) event.level = dto.level;
    if (dto.visibility !== undefined) event.visibility = dto.visibility;
    if (dto.access !== undefined) event.access = dto.access;
    if (dto.maxParticipants !== undefined) {
      event.maxParticipants = dto.maxParticipants;
    }
    if (dto.startPoint !== undefined) {
      event.startLat = dto.startPoint ? dto.startPoint.lat : null;
      event.startLng = dto.startPoint ? dto.startPoint.lng : null;
    }
    await this.eventsRepository.save(event);
    if (dto.trackId !== undefined) {
      await this.applyTrack(id, dto.trackId);
    }
    if (dto.startPoint !== undefined) {
      if (dto.startPoint) {
        await this.setStartPoint(id, dto.startPoint.lat, dto.startPoint.lng);
      } else {
        await this.eventsRepository
          .createQueryBuilder()
          .update(Event)
          .set({ startPoint: () => 'NULL' })
          .where('id = :id', { id })
          .execute();
      }
    }
    return this.findById(id);
  }

  /**
   * Привязка заплыва к маршруту: водоём, ожидаемая длительность и дистанция
   * берутся из маршрута, чтобы не заводить их вручную и не разъезжались.
   */
  private async applyTrack(eventId: string, trackId: string | null): Promise<void> {
    if (!trackId) {
      await this.eventsRepository
        .createQueryBuilder()
        .update(Event)
        .set({ trackId: null })
        .where('id = :id', { id: eventId })
        .execute();
      return;
    }
    const track = await this.tracksRepository.findOne({ where: { id: trackId } });
    if (!track) {
      throw new NotFoundException(`Track ${trackId} not found`);
    }
    await this.eventsRepository
      .createQueryBuilder()
      .update(Event)
      .set({
        trackId: track.id,
        waterBodyId: track.waterBodyId,
        expectedDurationMinutes:
          track.durationSeconds > 0
            ? Math.round(track.durationSeconds / 60)
            : null,
        expectedDistanceMeters:
          track.distanceMeters > 0 ? Math.round(track.distanceMeters) : null,
      })
      .where('id = :id', { id: eventId })
      .execute();
  }

  async cancel(id: string, userId: string): Promise<{ ok: boolean }> {
    const event = await this.eventsRepository.findOne({ where: { id } });
    if (!event) {
      throw new NotFoundException(`Event ${id} not found`);
    }
    if (event.organizerId !== userId) {
      throw new ForbiddenException('Only the organizer can cancel this event');
    }
    event.status = EventStatus.CANCELLED;
    await this.eventsRepository.save(event);
    return { ok: true };
  }

  async setParticipant(
    eventId: string,
    userId: string,
    status: ParticipantStatus,
  ): Promise<EventParticipant> {
    const event = await this.ensureEvent(eventId);
    return this.applyParticipant(event, userId, status);
  }

  async organizerSetParticipant(
    eventId: string,
    organizerId: string,
    userId: string,
    status: ParticipantStatus,
  ): Promise<EventParticipant> {
    const event = await this.ensureEvent(eventId);
    if (event.organizerId !== organizerId) {
      throw new ForbiddenException('Only the organizer can manage participants');
    }
    return this.applyParticipant(event, userId, status);
  }

  async removeParticipant(
    eventId: string,
    actorId: string,
    userId: string,
  ): Promise<{ ok: boolean }> {
    const event = await this.ensureEvent(eventId);
    if (actorId !== event.organizerId && actorId !== userId) {
      throw new ForbiddenException(
        'Only the organizer or the participant can remove participation',
      );
    }
    if (userId === event.organizerId) {
      throw new BadRequestException('The organizer cannot leave or be removed');
    }
    const participant = await this.participantsRepository.findOne({
      where: { eventId, userId },
    });
    if (!participant) {
      throw new NotFoundException('Participant not found');
    }
    await this.participantsRepository.remove(participant);
    return { ok: true };
  }

  private async applyParticipant(
    event: Event,
    userId: string,
    status: ParticipantStatus,
  ): Promise<EventParticipant> {
    const eventId = event.id;
    if (event.access === EventAccess.INVITE && userId !== event.organizerId) {
      const invite = await this.invitesRepository.findOne({
        where: { eventId, inviteeId: userId },
      });
      if (!invite) {
        throw new ForbiddenException('This event is invitation-only');
      }
      if (status === ParticipantStatus.GOING && invite.status !== EventInviteStatus.ACCEPTED) {
        invite.status = EventInviteStatus.ACCEPTED;
        await this.invitesRepository.save(invite);
      }
      if (status === ParticipantStatus.NOT_GOING && invite.status === EventInviteStatus.PENDING) {
        invite.status = EventInviteStatus.DECLINED;
        await this.invitesRepository.save(invite);
      }
    }
    if (status === ParticipantStatus.GOING) {
      if (
        event.maxParticipants &&
        event.status === EventStatus.SCHEDULED
      ) {
        const going = await this.participantsRepository.count({
          where: { eventId, status: ParticipantStatus.GOING },
        });
        if (going >= event.maxParticipants) {
          throw new BadRequestException('The event is full');
        }
      }
    }
    const existing = await this.participantsRepository.findOne({
      where: { eventId, userId },
    });
    if (existing) {
      existing.status = status;
      await this.participantsRepository.save(existing);
      return existing;
    }
    const participant = this.participantsRepository.create({
      eventId,
      userId,
      status,
    });
    const saved = await this.participantsRepository.save(participant);
    if (status === ParticipantStatus.GOING && userId !== event.organizerId) {
      this.eventEmitter.emit('events.joined', {
        organizerId: event.organizerId,
        joinerId: userId,
        eventId,
        eventTitle: event.title,
      });
    }
    return saved;
  }

  async participants(
    eventId: string,
    viewerId?: string,
    status?: ParticipantStatus,
  ): Promise<EventParticipant[]> {
    const event = await this.ensureEvent(eventId);
    if (viewerId) {
      await this.assertVisible(event, viewerId);
    }
    return this.participantsRepository.find({
      where: status ? { eventId, status } : { eventId },
      relations: { user: true },
      order: { joinedAt: 'ASC' },
    });
  }

  async invite(
    eventId: string,
    inviterId: string,
    userIds: string[],
  ): Promise<EventInvite[]> {
    const event = await this.eventsRepository.findOne({ where: { id: eventId } });
    if (!event) {
      throw new NotFoundException(`Event ${eventId} not found`);
    }
    if (event.organizerId !== inviterId) {
      throw new ForbiddenException('Only the organizer can invite participants');
    }
    const unique = [...new Set(userIds)].filter((id) => id !== inviterId);
    const created: EventInvite[] = [];
    const fresh: string[] = [];
    for (const inviteeId of unique) {
      const existing = await this.invitesRepository.findOne({
        where: { eventId, inviteeId },
      });
      if (existing) {
        created.push(existing);
        continue;
      }
      const invite = await this.invitesRepository.save(
        this.invitesRepository.create({ eventId, inviterId, inviteeId }),
      );
      created.push(invite);
      fresh.push(inviteeId);
    }
    if (fresh.length > 0) {
      this.eventEmitter.emit('events.invited', {
        inviterId,
        inviteeIds: fresh,
        eventId,
        eventTitle: event.title,
      });
    }
    return created;
  }

  async listInvites(eventId: string, userId: string): Promise<EventInvite[]> {
    const event = await this.ensureEvent(eventId);
    if (event.organizerId !== userId) {
      return this.invitesRepository.find({
        where: { eventId, inviteeId: userId },
        relations: { invitee: true },
      });
    }
    return this.invitesRepository.find({
      where: { eventId },
      relations: { invitee: true },
      order: { createdAt: 'DESC' },
    });
  }

  async revokeInvite(
    eventId: string,
    inviterId: string,
    inviteeId: string,
  ): Promise<{ ok: boolean }> {
    const event = await this.ensureEvent(eventId);
    if (event.organizerId !== inviterId) {
      throw new ForbiddenException('Only the organizer can revoke invites');
    }
    const invite = await this.invitesRepository.findOne({
      where: { eventId, inviteeId },
    });
    if (!invite) {
      throw new NotFoundException('Invite not found');
    }
    await this.invitesRepository.remove(invite);
    return { ok: true };
  }

  async myEvents(userId: string, status: ParticipantStatus): Promise<Event[]> {
    const participants = await this.participantsRepository.find({
      where: { userId, status },
    });
    const eventIds = participants.map((p) => p.eventId);
    if (eventIds.length === 0) {
      return [];
    }
    const events = await this.eventsRepository.find({
      where: { id: In(eventIds) },
      relations: { organizer: true, waterBody: true, track: true },
      order: { eventDate: 'ASC' },
    });
    return this.attachParticipantCounts(events);
  }

  async nearby(
    lat: number,
    lng: number,
    radiusMeters = 20000,
  ): Promise<NearbyEvent[]> {
    return this.eventsRepository.query(
      `SELECT e.id, e.title,
              e.event_date::text AS event_date,
              e.status,
              ST_Distance(
                COALESCE(e.start_point, wb.location),
                ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography
              ) AS distance_meters
       FROM events e
       LEFT JOIN waterbodies wb ON wb.id = e.waterbody_id
       WHERE e.status IN ('scheduled', 'on_water')
         AND e.visibility = 'public'
         AND COALESCE(e.start_point, wb.location) IS NOT NULL
         AND ST_DWithin(
           COALESCE(e.start_point, wb.location),
           ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography,
           $3
         )
       ORDER BY distance_meters ASC
       LIMIT 50`,
      [lat, lng, radiusMeters],
    );
  }

  private async assertVisible(event: Event, viewerId: string): Promise<void> {
    if (event.organizerId === viewerId) return;
    if (event.visibility === EventVisibility.PUBLIC) return;
    const participating = await this.participantsRepository.count({
      where: { eventId: event.id, userId: viewerId },
    });
    if (participating > 0) return;
    const invited = await this.invitesRepository.count({
      where: { eventId: event.id, inviteeId: viewerId },
    });
    if (invited > 0) return;
    if (
      event.visibility === EventVisibility.FRIENDS &&
      (await this.friendsService.areFriends(event.organizerId, viewerId))
    ) {
      return;
    }
    throw new ForbiddenException('Event is not visible to you');
  }

  private async ensureEvent(id: string): Promise<Event> {
    const event = await this.eventsRepository.findOne({ where: { id } });
    if (!event) {
      throw new NotFoundException(`Event ${id} not found`);
    }
    return event;
  }

  private setStartPoint(id: string, lat: number, lng: number): Promise<void> {
    return this.eventsRepository
      .createQueryBuilder()
      .update(Event)
      .set({
        startPoint: () => `ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)`,
      })
      .where('id = :id', { id })
      .execute()
      .then(() => undefined);
  }

  private async attachParticipantCounts(events: Event[]): Promise<Event[]> {
    if (events.length === 0) return events;
    const ids = events.map((e) => e.id);
    const rows: { event_id: string; cnt: string }[] =
      await this.participantsRepository.query(
        `SELECT event_id, COUNT(*)::int AS cnt
         FROM event_participants
         WHERE event_id = ANY($1) AND status = 'going'
         GROUP BY event_id`,
        [ids],
      );
    const counts = new Map(rows.map((r) => [r.event_id, Number(r.cnt)]));
    return events.map((e) => {
      (e as Event & { participantCount: number }).participantCount =
        counts.get(e.id) ?? 0;
      return e;
    });
  }
}
