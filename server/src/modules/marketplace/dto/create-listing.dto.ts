import {
  ArrayMaxSize,
  IsArray,
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  Length,
  MaxLength,
  Min,
} from 'class-validator';
import { LISTING_CATEGORIES } from '../categories';

export class CreateListingDto {
  @IsIn(LISTING_CATEGORIES)
  category: string;

  @IsString()
  @Length(3, 200)
  title: string;

  @IsOptional()
  @IsString()
  @MaxLength(5000)
  description?: string;

  @IsOptional()
  @IsNumber()
  @Min(0)
  price?: number;

  @IsOptional()
  @IsString()
  @MaxLength(8)
  currency?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @ArrayMaxSize(10)
  photos?: string[];

  @IsOptional()
  @IsNumber()
  latitude?: number;

  @IsOptional()
  @IsNumber()
  longitude?: number;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  city?: string;
}