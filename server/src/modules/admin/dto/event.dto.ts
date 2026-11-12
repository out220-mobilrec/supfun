import { IsEnum, IsOptional } from 'class-validator';
import { UpdateEventDto } from '../../events/dto/update-event.dto';
import { EventStatus } from '../../events/event.entity';

export class AdminUpdateEventDto extends UpdateEventDto {
  @IsOptional()
  @IsEnum(EventStatus)
  status?: EventStatus;
}
