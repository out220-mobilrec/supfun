import {
  IsArray,
  IsDateString,
  IsEnum,
  IsIn,
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
import { TrackDifficulty } from '../track.entity';

export class CreateTrackDto {
  @IsOptional()
  @IsString()
  @MaxLength(200)
  name?: string;

  @IsOptional()
  @IsUUID()
  waterBodyId?: string;

  @IsOptional()
  @IsUUID()
  eventId?: string;

  @IsOptional()
  @IsUUID()
  routeId?: string;

  @IsOptional()
  @IsEnum(TrackDifficulty)
  difficulty?: TrackDifficulty;

  @IsDateString()
  startedAt: string;
}

export class TrackPointDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  seq?: number;

  @IsNumber()
  @Min(-90)
  @Max(90)
  lat: number;

  @IsNumber()
  @Min(-180)
  @Max(180)
  lng: number;

  @IsOptional()
  @IsNumber()
  altitude?: number;

  @IsOptional()
  @IsNumber()
  speedKph?: number;

  @IsDateString()
  recordedAt: string;
}

export class AddPointsDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => TrackPointDto)
  points: TrackPointDto[];
}

export class CompleteTrackDto {
  @IsDateString()
  endedAt: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  name?: string;

  @IsOptional()
  @IsEnum(TrackDifficulty)
  difficulty?: TrackDifficulty;
}

export class UpdateTrackDto {
  @IsOptional()
  @IsString()
  @MaxLength(200)
  name?: string;

  @IsOptional()
  @IsUUID()
  waterBodyId?: string;

  @IsOptional()
  @IsUUID()
  routeId?: string;

  @IsOptional()
  @IsEnum(TrackDifficulty)
  difficulty?: TrackDifficulty;

  @IsOptional()
  @IsNumber()
  @Min(0)
  distanceMeters?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  durationSeconds?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  avgSpeedKph?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  maxSpeedKph?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  elevationGainMeters?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  elevationLossMeters?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  calories?: number;
}

export class ReplacePointsDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => TrackPointDto)
  points: TrackPointDto[];
}

export class TrackQueryDto {
  @IsOptional()
  @IsIn(['all', 'mine', 'public'])
  scope?: 'all' | 'mine' | 'public';

  @IsOptional()
  @IsUUID()
  waterBodyId?: string;

  @IsOptional()
  @IsUUID()
  routeId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  region?: string;

  @IsOptional()
  @IsString()
  farEast?: string;

  @IsOptional()
  @IsEnum(TrackDifficulty)
  difficulty?: TrackDifficulty;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  minDurationSec?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  maxDurationSec?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  offset?: number;
}

/** Точка трека от мобильного клиента: seq нужен для дедупликации повторных пакетов. */
export class GpsPointDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  seq?: number;

  @IsNumber()
  @Min(-90)
  @Max(90)
  lat: number;

  @IsNumber()
  @Min(-180)
  @Max(180)
  lng: number;

  @IsOptional()
  @IsNumber()
  altitude?: number;

  @IsOptional()
  @IsNumber()
  speedKph?: number;

  @IsDateString()
  recordedAt: string;
}

/** Пакет точек: мобильное приложение догружает трек частями (work offline). */
export class AppendGpsPointsDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => GpsPointDto)
  points: GpsPointDto[];
}

/** Старт записи трека участником заплыва. */
export class StartEventTrackDto {
  @IsOptional()
  @IsString()
  @MaxLength(200)
  name?: string;

  @IsOptional()
  @IsDateString()
  startedAt?: string;
}