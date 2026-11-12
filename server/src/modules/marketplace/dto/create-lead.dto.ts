import { IsOptional, IsString, MaxLength } from 'class-validator';

export class CreateLeadDto {
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  message?: string;
}