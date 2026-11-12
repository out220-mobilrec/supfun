import 'reflect-metadata';

//_DOTENV_MARKER_ (kept simple: @nestjs/config loads .env itself)

import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { AppModule } from './app.module';
import { config as dotenvConfig } from 'dotenv';
import { Logger, ValidationPipe } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import helmet from 'helmet';
import { ensureUploadDir, UPLOAD_DIR } from './modules/uploads/upload.config';

dotenvConfig();

async function bootstrap(): Promise<void> {
  const logger = new Logger('bootstrap');
  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    logger: ['error', 'warn', 'log', 'debug', 'verbose'],
  });
  app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));
  app.enableCors();
  app.useStaticAssets(ensureUploadDir(), { prefix: '/uploads/' });
  logger.log(`Serving uploaded files from ${UPLOAD_DIR}`);
  app.setGlobalPrefix('api');
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: false,
    }),
  );

  const swaggerConfig = new DocumentBuilder()
    .setTitle('SUP FUN API')
    .setDescription('Backend for the SUP FUN paddleboarding app')
    .setVersion('0.1.0')
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, swaggerConfig);
  SwaggerModule.setup('api/docs', app, document);

  const port = Number(process.env.PORT ?? 3000);
  await app.listen(port);
  logger.log(`SUP FUN server is running on http://localhost:${port}`);
  logger.log(`Swagger UI available at http://localhost:${port}/api/docs`);
}

void bootstrap();
