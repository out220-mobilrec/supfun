import {
  IsBoolean,
  IsEmail,
  IsEnum,
  IsIn,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  MaxLength,
  MinLength,
} from 'class-validator';
import { VisibilityScope } from '../user.entity';

export class UpdateUserDto {
  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(100)
  name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(30)
  phone?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  city?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  region?: string;

  /** Код страны из справочника countries (ISO 3166-1 alpha-2). */
  @IsOptional()
  @IsString()
  @Length(2, 2)
  country?: string;

  @IsOptional()
  @IsEmail()
  email?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  avatarUrl?: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  bio?: string;

  @IsOptional()
  @IsUUID()
  homeWaterBodyId?: string;

  @IsOptional()
  @IsEnum(VisibilityScope)
  profileVisibility?: VisibilityScope;

  @IsOptional()
  @IsEnum(VisibilityScope)
  activityVisibility?: VisibilityScope;

  @IsOptional()
  @IsEnum(VisibilityScope)
  geoVisibility?: VisibilityScope;

  @IsOptional()
  @IsBoolean()
  showOnline?: boolean;

  /** Язык интерфейса профиля: ru (по умолчанию) или en. */
  @IsOptional()
  @IsIn(['ru', 'en'])
  locale?: string;
}