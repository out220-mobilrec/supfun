import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Conversation } from './conversation.entity';
import { ConversationParticipant } from './conversation-participant.entity';
import { Message } from './message.entity';
import { MessagesService } from './messages.service';
import { MessagesController } from './messages.controller';
import { ChatGateway } from './chat.gateway';

@Module({
  imports: [TypeOrmModule.forFeature([Conversation, ConversationParticipant, Message])],
  controllers: [MessagesController],
  providers: [MessagesService, ChatGateway],
  exports: [MessagesService, ChatGateway],
})
export class MessagesModule {}