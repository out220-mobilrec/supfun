import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Route } from './route.entity';
import { RoutePoint } from './route-point.entity';
import { User } from '../users/user.entity';
import { WaterBody } from '../waterbodies/waterbody.entity';
import { RoutesService } from './routes.service';
import { RoutesController } from './routes.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([Route, RoutePoint, User, WaterBody]),
  ],
  controllers: [RoutesController],
  providers: [RoutesService],
  exports: [RoutesService],
})
export class RoutesModule {}
