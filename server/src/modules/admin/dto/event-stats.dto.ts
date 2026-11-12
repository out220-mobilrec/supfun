import { Type } from 'class-transformer';
import {
  IsDateString,
  IsOptional,
} from 'class-validator';

/** Параметры фильтрации статистики заплывов по периоду. */
export class EventStatsQueryDto {
  @IsOptional()
  @IsDateString()
  from?: string;

  @IsOptional()
  @IsDateString()
  to?: string;
}
