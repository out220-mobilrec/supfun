import {
  Controller,
  Get,
  Param,
  Query,
  UseGuards,
} from '@nestjs/common';
import { WaterbodiesService } from './waterbodies.service';
import { WaterBody } from './waterbody.entity';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@Controller('waterbodies')
@UseGuards(JwtAuthGuard)
export class WaterbodiesController {
  constructor(private readonly service: WaterbodiesService) {}

  @Get()
  list(
    @Query('q') query?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
    @Query('region') region?: string,
    @Query('farEast') farEast?: string,
  ): Promise<WaterBody[]> {
    return this.service.findAll(
      query,
      limit ? Number(limit) : undefined,
      offset ? Number(offset) : undefined,
      region,
      farEast === 'true' || farEast === '1',
    );
  }

  @Get('nearby')
  nearby(
    @Query('lat') lat: string,
    @Query('lng') lng: string,
    @Query('radius') radius?: string,
  ) {
    return this.service.findNearby(
      Number(lat),
      Number(lng),
      radius ? Number(radius) : undefined,
    );
  }

  @Get(':id')
  get(@Param('id') id: string): Promise<WaterBody> {
    return this.service.findById(id);
  }
}
