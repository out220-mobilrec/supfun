import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Track } from './track.entity';
import { TrackPoint } from './track-point.entity';
import { TracksService } from './tracks.service';
import { TracksController } from './tracks.controller';
import { EventTracksController } from './event-tracks.controller';
import { GamificationModule } from '../gamification/gamification.module';

@Module({
  imports: [TypeOrmModule.forFeature([Track, TrackPoint]), GamificationModule],
  controllers: [TracksController, EventTracksController],
  providers: [TracksService],
  exports: [TracksService],
})
export class TracksModule {}