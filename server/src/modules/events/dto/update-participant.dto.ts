import { IsEnum } from 'class-validator';
import { ParticipantStatus } from '../event-participant.entity';

export class UpdateParticipantDto {
  @IsEnum(ParticipantStatus)
  status: ParticipantStatus;
}
