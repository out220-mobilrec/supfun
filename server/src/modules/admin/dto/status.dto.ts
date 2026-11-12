import { IsBoolean, IsIn, IsNotEmpty } from 'class-validator';

export class SetRoleDto {
  @IsNotEmpty()
  @IsIn(['user', 'guide', 'moderator', 'admin'])
  role: string;
}

export class ListingStatusDto {
  @IsNotEmpty()
  @IsIn(['active', 'completed', 'removed'])
  status: string;
}

export class EventStatusDto {
  @IsNotEmpty()
  @IsIn(['scheduled', 'on_water', 'completed', 'cancelled'])
  status: string;
}

export class TrackStatusDto {
  @IsNotEmpty()
  @IsIn(['private', 'moderation', 'published', 'hidden'])
  status: string;
}

export class SetActiveDto {
  @IsBoolean()
  active: boolean;
}