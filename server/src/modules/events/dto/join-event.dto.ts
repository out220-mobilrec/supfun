import { IsEnum, IsOptional } from 'class-validator';
import { ParticipantStatus } from '../event-participant.entity';

export class JoinEventDto {
  @IsOptional()
  @IsEnum(ParticipantStatus)
  status?: ParticipantStatus;
}