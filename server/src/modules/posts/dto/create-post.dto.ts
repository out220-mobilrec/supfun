import {
  ArrayMaxSize,
  IsArray,
  IsEnum,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
} from 'class-validator';
import { VisibilityScope } from '../../users/user.entity';
import { PostType } from '../post.entity';

export class CreatePostDto {
  @IsOptional()
  @IsEnum(PostType)
  type?: PostType;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  title?: string;

  @IsOptional()
  @IsString()
  @MaxLength(5000)
  body?: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(10)
  @IsString({ each: true })
  photos?: string[];

  @IsOptional()
  @IsUUID()
  refId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  refType?: string;

  @IsOptional()
  @IsEnum(VisibilityScope)
  visibility?: VisibilityScope;
}
