import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { WaterBody } from './waterbody.entity';
import { WaterbodiesService } from './waterbodies.service';
import { WaterbodiesController } from './waterbodies.controller';

@Module({
  imports: [TypeOrmModule.forFeature([WaterBody])],
  controllers: [WaterbodiesController],
  providers: [WaterbodiesService],
  exports: [WaterbodiesService],
})
export class WaterbodiesModule {}
