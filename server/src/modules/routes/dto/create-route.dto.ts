import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsEnum,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';
import { RouteDifficulty } from '../route.entity';

export class RoutePointDto {
  @IsNumber()
  @Min(-90)
  @Max(90)
  @Type(() => Number)
  lat: number;

  @IsNumber()
  @Min(-180)
  @Max(180)
  @Type(() => Number)
  lng: number;
}

export class CreateRouteDto {
  @IsString()
  @MinLength(2)
  @MaxLength(200)
  name: string;

  @IsOptional()
  @IsString()
  @MaxLength(5000)
  description?: string;

  /** Маршрут привязан к водоему — обязательная ссылка. */
  @IsUUID()
  waterbodyId: string;

  @IsOptional()
  @IsEnum(RouteDifficulty)
  difficulty?: RouteDifficulty;

  @IsOptional()
  @IsBoolean()
  published?: boolean;

  /** Максимальная (рабочая) скорость прохождения, км/ч. */
  @IsOptional()
  @IsNumber()
  @Min(0)
  @Type(() => Number)
  maxSpeedKph?: number;

  /** Ожидаемое время прохождения, минут. */
  @IsOptional()
  @IsInt()
  @Min(1)
  @Type(() => Number)
  expectedDurationMinutes?: number;

  /**
   * Последовательность точек линии: первая — старт, последняя — финиш.
   */
  @IsArray()
  @ArrayMinSize(2)
  @ArrayMaxSize(5000)
  @ValidateNested({ each: true })
  @Type(() => RoutePointDto)
  points: RoutePointDto[];
}
