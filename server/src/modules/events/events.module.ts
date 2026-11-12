import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Event } from './event.entity';
import { EventParticipant } from './event-participant.entity';
import { EventInvite } from './event-invite.entity';
import { Track } from '../tracks/track.entity';
import { EventsService } from './events.service';
import { EventsController } from './events.controller';
import { GamificationModule } from '../gamification/gamification.module';
import { FriendsModule } from '../friends/friends.module';
import { MessagesModule } from '../messages/messages.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Event, EventParticipant, EventInvite, Track]),
    GamificationModule,
    FriendsModule,
    MessagesModule,
  ],
  controllers: [EventsController],
  providers: [EventsService],
  exports: [EventsService],
})
export class EventsModule {}
