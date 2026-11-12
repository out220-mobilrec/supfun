import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import {
  CurrentUser,
  type AuthUser,
} from '../../common/decorators/current-user.decorator';
import { ChannelsService } from './channels.service';
import { CreateChannelDto } from './dto/create-channel.dto';
import { UpdateChannelDto } from './dto/update-channel.dto';
import { CreateChannelPostDto } from './dto/create-channel-post.dto';
import { CreateChannelCommentDto } from './dto/create-channel-comment.dto';
import { ChannelRoleDto } from './dto/channel-role.dto';

@Controller('channels')
@UseGuards(JwtAuthGuard)
export class ChannelsController {
  constructor(private readonly channelsService: ChannelsService) {}

  @Get()
  list(
    @CurrentUser() me: AuthUser,
    @Query('q') q?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.channelsService.list(me, {
      q,
      limit: limit ? Number(limit) : undefined,
      offset: offset ? Number(offset) : undefined,
    });
  }

  @Post()
  create(@CurrentUser() me: AuthUser, @Body() dto: CreateChannelDto) {
    return this.channelsService.create(me, dto);
  }

  @Get(':id')
  get(@CurrentUser() me: AuthUser, @Param('id') id: string) {
    return this.channelsService.get(id, me);
  }

  @Patch(':id')
  update(
    @CurrentUser() me: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdateChannelDto,
  ) {
    return this.channelsService.update(id, me, dto);
  }

  @Delete(':id')
  remove(@CurrentUser() me: AuthUser, @Param('id') id: string) {
    return this.channelsService.remove(id, me);
  }

  @Post(':id/join')
  join(@CurrentUser() me: AuthUser, @Param('id') id: string) {
    return this.channelsService.join(id, me);
  }

  @Post(':id/leave')
  leave(@CurrentUser() me: AuthUser, @Param('id') id: string) {
    return this.channelsService.leave(id, me);
  }

  @Get(':id/members')
  members(@CurrentUser() me: AuthUser, @Param('id') id: string) {
    return this.channelsService.listMembers(id, me);
  }

  @Patch(':id/members/:userId')
  setRole(
    @CurrentUser() me: AuthUser,
    @Param('id') id: string,
    @Param('userId') userId: string,
    @Body() dto: ChannelRoleDto,
  ) {
    return this.channelsService.setMemberRole(id, me, userId, dto.role);
  }

  @Get(':id/posts')
  posts(
    @CurrentUser() me: AuthUser,
    @Param('id') id: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.channelsService.listPosts(id, me, {
      limit: limit ? Number(limit) : undefined,
      offset: offset ? Number(offset) : undefined,
    });
  }

  @Post(':id/posts')
  createPost(
    @CurrentUser() me: AuthUser,
    @Param('id') id: string,
    @Body() dto: CreateChannelPostDto,
  ) {
    return this.channelsService.createPost(id, me, dto);
  }

  @Delete(':id/posts/:postId')
  deletePost(
    @CurrentUser() me: AuthUser,
    @Param('id') id: string,
    @Param('postId') postId: string,
  ) {
    return this.channelsService.deletePost(id, postId, me);
  }

  @Patch(':id/posts/:postId/pin')
  togglePin(
    @CurrentUser() me: AuthUser,
    @Param('id') id: string,
    @Param('postId') postId: string,
  ) {
    return this.channelsService.togglePin(id, postId, me);
  }

  @Patch(':id/posts/:postId/like')
  toggleLike(
    @CurrentUser() me: AuthUser,
    @Param('id') id: string,
    @Param('postId') postId: string,
  ) {
    return this.channelsService.toggleLike(id, postId, me);
  }

  @Get(':id/posts/:postId/comments')
  comments(
    @CurrentUser() me: AuthUser,
    @Param('id') id: string,
    @Param('postId') postId: string,
  ) {
    return this.channelsService.listComments(id, postId, me);
  }

  @Post(':id/posts/:postId/comments')
  addComment(
    @CurrentUser() me: AuthUser,
    @Param('id') id: string,
    @Param('postId') postId: string,
    @Body() dto: CreateChannelCommentDto,
  ) {
    return this.channelsService.addComment(id, postId, me, dto.body);
  }

  @Delete(':id/posts/:postId/comments/:commentId')
  removeComment(
    @CurrentUser() me: AuthUser,
    @Param('id') id: string,
    @Param('postId') postId: string,
    @Param('commentId') commentId: string,
  ) {
    return this.channelsService.removeComment(id, postId, commentId, me);
  }
}
