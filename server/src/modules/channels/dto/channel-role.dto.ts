import { IsEnum } from 'class-validator';
import { ChannelRole } from '../channel-member.entity';

export class ChannelRoleDto {
  @IsEnum(ChannelRole)
  role: ChannelRole;
}
