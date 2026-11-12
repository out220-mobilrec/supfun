import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../../common/decorators/current-user.decorator';
import { MessagesService, ConversationSummary } from './messages.service';
import { Conversation } from './conversation.entity';
import { ConversationParticipant } from './conversation-participant.entity';
import { Message } from './message.entity';
import {
  CreateConversationDto,
  DirectConversationDto,
  SendMessageDto,
} from './dto/messages.dto';

@UseGuards(JwtAuthGuard)
@Controller('conversations')
export class MessagesController {
  constructor(private readonly service: MessagesService) {}

  @Get()
  list(@CurrentUser() current: AuthUser): Promise<ConversationSummary[]> {
    return this.service.listMine(current.id);
  }

  @Post('direct')
  direct(
    @CurrentUser() current: AuthUser,
    @Body() dto: DirectConversationDto,
  ): Promise<Conversation> {
    return this.service.findOrCreateDirect(current.id, dto);
  }

  @Post()
  create(
    @CurrentUser() current: AuthUser,
    @Body() dto: CreateConversationDto,
  ): Promise<Conversation> {
    return this.service.create(dto, current.id);
  }

  @Get(':id')
  get(
    @CurrentUser() current: AuthUser,
    @Param('id') id: string,
  ): Promise<Conversation> {
    return this.service.findOne(id, current.id);
  }

  @Get(':id/messages')
  messages(
    @CurrentUser() current: AuthUser,
    @Param('id') id: string,
    @Query('before') before?: string,
    @Query('limit') limit?: string,
  ): Promise<Message[]> {
    return this.service.messages(id, current.id, before, limit ? Number(limit) : undefined);
  }

  @Post(':id/messages')
  send(
    @CurrentUser() current: AuthUser,
    @Param('id') id: string,
    @Body() dto: SendMessageDto,
  ): Promise<Message> {
    return this.service.send(id, current.id, dto);
  }

  @Post(':id/read')
  markRead(@CurrentUser() current: AuthUser, @Param('id') id: string): Promise<{ ok: boolean }> {
    return this.service.markRead(id, current.id);
  }

  @Get(':id/participants')
  participants(
    @CurrentUser() current: AuthUser,
    @Param('id') id: string,
  ): Promise<ConversationParticipant[]> {
    return this.service.participants(id, current.id);
  }
}