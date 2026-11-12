import {
  IsArray,
  IsEnum,
  IsLatitude,
  IsLongitude,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
} from 'class-validator';
import { MessageType } from '../message.entity';
import { ConversationType } from '../conversation.entity';

export class CreateConversationDto {
  @IsEnum(ConversationType)
  type: ConversationType;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  title?: string;

  @IsOptional()
  @IsUUID()
  eventId?: string;

  @IsOptional()
  @IsArray()
  @IsUUID('4', { each: true })
  memberIds?: string[];
}

export class DirectConversationDto {
  @IsUUID()
  userId: string;
}

export class SendMessageDto {
  @IsOptional()
  @IsEnum(MessageType)
  type?: MessageType;

  @IsOptional()
  @IsString()
  @MaxLength(10000)
  content?: string;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  nonce?: string;

  @IsOptional()
  @IsLatitude()
  latitude?: number;

  @IsOptional()
  @IsLongitude()
  longitude?: number;

  @IsOptional()
  @IsUUID()
  replyToId?: string;
}