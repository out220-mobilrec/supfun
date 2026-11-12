import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post as HttpPost,
  Query,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import {
  CurrentUser,
  AuthUser,
} from '../../common/decorators/current-user.decorator';
import { PostsService, PostView, PostListResult } from './posts.service';
import { PostComment } from './post-comment.entity';
import { CreatePostDto } from './dto/create-post.dto';
import { CreateCommentDto } from './dto/create-comment.dto';
import { PostType } from './post.entity';

@Controller('posts')
@UseGuards(JwtAuthGuard)
export class PostsController {
  constructor(private readonly postsService: PostsService) {}

  @HttpPost()
  create(
    @CurrentUser() current: AuthUser,
    @Body() dto: CreatePostDto,
  ): Promise<PostView> {
    return this.postsService.create(current.id, dto);
  }

  @Get()
  list(
    @CurrentUser() current: AuthUser,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
    @Query('authorId') authorId?: string,
    @Query('type') type?: PostType,
  ): Promise<PostListResult> {
    return this.postsService.list(current, {
      limit: limit ? Number(limit) : undefined,
      offset: offset ? Number(offset) : undefined,
      authorId,
      type,
    });
  }

  @Get(':id')
  get(
    @CurrentUser() current: AuthUser,
    @Param('id') id: string,
  ): Promise<PostView> {
    return this.postsService.get(id, current);
  }

  @Delete(':id')
  remove(
    @CurrentUser() current: AuthUser,
    @Param('id') id: string,
  ): Promise<{ ok: boolean }> {
    return this.postsService.remove(id, current);
  }

  @Patch(':id/like')
  toggleLike(
    @CurrentUser() current: AuthUser,
    @Param('id') id: string,
  ): Promise<{ liked: boolean; likeCount: number }> {
    return this.postsService.toggleLike(id, current);
  }

  @HttpPost(':id/share')
  share(
    @CurrentUser() current: AuthUser,
    @Param('id') id: string,
  ): Promise<{ shareCount: number }> {
    return this.postsService.share(id, current);
  }

  @Get(':id/comments')
  comments(
    @CurrentUser() current: AuthUser,
    @Param('id') id: string,
  ): Promise<PostComment[]> {
    return this.postsService.listComments(id, current);
  }

  @HttpPost(':id/comments')
  addComment(
    @CurrentUser() current: AuthUser,
    @Param('id') id: string,
    @Body() dto: CreateCommentDto,
  ): Promise<PostComment> {
    return this.postsService.addComment(id, current, dto.body);
  }

  @Delete(':id/comments/:commentId')
  removeComment(
    @CurrentUser() current: AuthUser,
    @Param('id') id: string,
    @Param('commentId') commentId: string,
  ): Promise<{ ok: boolean }> {
    return this.postsService.removeComment(id, commentId, current);
  }
}
