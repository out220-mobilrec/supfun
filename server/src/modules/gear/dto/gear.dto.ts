import {
  IsEnum,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import { GearCategory } from '../gear-item.entity';

export class CreateGearDto {
  @IsEnum(GearCategory)
  category: GearCategory;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  brand?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  model?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  lengthCm?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  widthCm?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  volumeL?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  weightKg?: number;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  material?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  notes?: string;
}

export class UpdateGearDto {
  @IsOptional()
  @IsEnum(GearCategory)
  category?: GearCategory;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  brand?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  model?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  lengthCm?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  widthCm?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  volumeL?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  weightKg?: number;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  material?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  notes?: string;
}