import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);
  private readonly transporter: any = null;
  private readonly from: string;
  readonly enabled: boolean;

  constructor(private readonly config: ConfigService) {
    this.from = this.config.get<string>('mail.from') ?? 'no-reply@supfun.app';
    const host = this.config.get<string>('mail.host');
    if (host) {
      try {
        const nodemailer = require('nodemailer');
        this.transporter = nodemailer.createTransport({
          host,
          port: this.config.get<number>('mail.port') ?? 587,
          secure: this.config.get<boolean>('mail.secure') ?? false,
          auth: this.config.get<string>('mail.user')
            ? {
                user: this.config.get<string>('mail.user'),
                pass: this.config.get<string>('mail.pass'),
              }
            : undefined,
        });
        this.enabled = true;
      } catch {
        this.logger.warn(
          'nodemailer is not installed; outgoing emails will be logged only',
        );
        this.enabled = false;
      }
    } else {
      this.enabled = false;
    }
  }

  async send(to: string, subject: string, text: string): Promise<void> {
    if (!this.enabled || !this.transporter) {
      this.logger.log(`[mail:dev] to=${to} subject="${subject}"\n${text}`);
      return;
    }
    try {
      await this.transporter.sendMail({ from: this.from, to, subject, text });
      this.logger.log(`[mail:sent] to=${to}`);
    } catch (err) {
      // Fallback: log instead of crashing the server
      this.logger.warn(
        `[mail:failed] to=${to}, using dev mode: ${err.message}`,
      );
      this.logger.log(`[mail:dev fallback] to=${to} subject="${subject}"\n${text}`);
      // Don't throw - let the request succeed with devCode in response
    }
  }
}
