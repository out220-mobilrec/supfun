import { Controller, Get, Query } from '@nestjs/common';
import { IsLatitude, IsLongitude } from 'class-validator';
import { Type } from 'class-transformer';
import { ApiTags } from '@nestjs/swagger';
import { Public } from '../../common/decorators/public.decorator';
import { WeatherService } from './weather.service';
import { WeatherForecast } from './weather.types';

class WeatherQueryDto {
  @Type(() => Number)
  @IsLatitude()
  lat: number;

  @Type(() => Number)
  @IsLongitude()
  lon: number;
}

@ApiTags('weather')
@Controller('weather')
export class WeatherController {
  constructor(private readonly weatherService: WeatherService) {}

  @Public()
  @Get()
  async get(@Query() query: WeatherQueryDto): Promise<WeatherForecast> {
    return this.weatherService.getForecast(query.lat, query.lon);
  }
}
