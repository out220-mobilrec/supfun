import { IsEnum, IsNotEmpty, IsString, MaxLength } from 'class-validator';
import { DevicePlatform } from '../device-token.entity';

export class RegisterDeviceDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(1024)
  token: string;

  @IsEnum(DevicePlatform)
  platform?: DevicePlatform;
}