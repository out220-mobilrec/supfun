import { IsBoolean, IsOptional } from 'class-validator';

export class UpdateNotificationSettingDto {
  @IsOptional()
  @IsBoolean()
  inApp?: boolean;

  @IsOptional()
  @IsBoolean()
  push?: boolean;
}
