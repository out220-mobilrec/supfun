import {
  IsArray,
  IsDateString,
  IsEnum,
  IsInt,
  IsNumber,
  IsObject,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';
import { EventAccess, EventLevel, EventVisibility } from '../event.entity';

export class StartPointDto {
  @IsNumber()
  @Min(-90)
  @Max(90)
  lat: number;

  @IsNumber()
  @Min(-180)
  @Max(180)
  lng: number;
}

export class CreateEventDto {
  @IsString()
  @MaxLength(200)
  title: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @MaxLength(500, { each: true })
  photos?: string[];

  @IsOptional()
  @IsUUID()
  waterBodyId?: string;

  /** Маршрут: водоём, длительность и дистанция возьмутся из него. */
  @IsOptional()
  @IsUUID()
  trackId?: string;

  @IsOptional()
  @IsObject()
  @ValidateNested()
  @Type(() => StartPointDto)
  startPoint?: StartPointDto;

  @IsDateString()
  eventDate: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  expectedDurationMinutes?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  expectedDistanceMeters?: number;

  @IsOptional()
  @IsEnum(EventLevel)
  level?: EventLevel;

  @IsOptional()
  @IsEnum(EventVisibility)
  visibility?: EventVisibility;

  @IsOptional()
  @IsEnum(EventAccess)
  access?: EventAccess;

  @IsOptional()
  @IsInt()
  @Min(1)
  maxParticipants?: number;
}