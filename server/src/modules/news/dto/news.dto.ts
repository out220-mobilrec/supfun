import {
  IsBoolean,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';

export class CreateNewsDto {
  @IsString()
  @MinLength(2)
  @MaxLength(200)
  title: string;

  @IsString()
  @MinLength(1)
  @MaxLength(10000)
  body: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  coverUrl?: string;

  @IsOptional()
  @IsBoolean()
  isPublished?: boolean;
}

export class UpdateNewsDto {
  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(200)
  title?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(10000)
  body?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  coverUrl?: string | null;

  @IsOptional()
  @IsBoolean()
  isPublished?: boolean;
}
