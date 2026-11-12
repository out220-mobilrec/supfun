import { Controller, Get } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { Public } from '../../common/guards/jwt-auth.guard';

@Controller('health')
export class HealthController {
  constructor(
    @InjectDataSource()
    private readonly dataSource: DataSource,
  ) {}

  @Public()
  @Get()
  async check(): Promise<{ status: string; database: string; postgis: string }> {
    const postgisResult = await this.dataSource.query(
      'SELECT postgis_version() AS version',
    );
    return {
      status: 'ok',
      database: this.dataSource.options.database as string,
      postgis: postgisResult[0]?.version ?? 'unknown',
    };
  }
}
