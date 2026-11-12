import {
  IsArray,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { ReviewTargetType } from '../review.entity';

export class CreateReviewDto {
  @IsEnum(ReviewTargetType)
  targetType: ReviewTargetType;

  @IsUUID()
  targetId: string;

  @IsInt()
  @Min(1)
  @Max(5)
  rating: number;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  comment?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @MaxLength(500, { each: true })
  photos?: string[];
}

export class UpdateReviewDto {
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(5)
  rating?: number;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  comment?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @MaxLength(500, { each: true })
  photos?: string[];
}
